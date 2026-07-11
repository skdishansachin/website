const std = @import("std");
const Io = std.Io;
const net = std.Io.net;

const Router = @import("Router.zig");
const Request = @import("Request.zig");
const Response = @import("Response.zig");
const Static = @import("Static.zig");
const handler = @import("handler.zig");

var shutdown_flag: std.atomic.Value(u32) = std.atomic.Value(u32).init(0);
var active_connections: std.atomic.Value(u32) = std.atomic.Value(u32).init(0);
var total_connections: std.atomic.Value(u32) = std.atomic.Value(u32).init(0);

const default_port: u16 = 8000;
const max_header_buf = 8192;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.arena.allocator();

    var port: u16 = default_port;
    var static_dir: []const u8 = "public";
    const args = try init.minimal.args.toSlice(gpa);
    var idx: usize = 0;
    while (idx < args.len) : (idx += 1) {
        if (std.mem.eql(u8, args[idx], "--port") and idx + 1 < args.len) {
            port = std.fmt.parseInt(u16, args[idx + 1], 10) catch default_port;
            idx += 1;
        } else if (std.mem.eql(u8, args[idx], "--static-dir") and idx + 1 < args.len) {
            static_dir = args[idx + 1];
            idx += 1;
        } else if (std.mem.eql(u8, args[idx], "--help") or std.mem.eql(u8, args[idx], "-h")) {
            var stdout_buffer: [1024]u8 = undefined;
            var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
            const stdout_writer = &stdout_file_writer.interface;
            try stdout_writer.print(
                \\Usage: server [OPTIONS]
                \\
                \\Options:
                \\  --port, -p <PORT>    Listen to this port (default: 8000)
                \\  --static-dir <DIR>   Root directory for static files (default: public)
                \\  --help, -h
                \\
            , .{});
            try stdout_writer.flush();
            return;
        }
    }

    const static = Static.init(io, static_dir);
    handler.init(&static);

    var r = Router.init(gpa);
    defer r.deinit();

    try r.get("/", handler.indexHandler);
    try r.get("/hello", handler.helloHandler);
    try r.get("/json", handler.jsonHandler);
    try r.get("/headers", handler.headersHandler);
    try r.post("/echo", handler.echoHandler);
    try r.get("/static", handler.staticHandler);
    try r.get("/static/", handler.staticHandler);

    const address = net.Ip4Address.parse("0.0.0.0", port) catch unreachable;
    const addr = net.IpAddress{ .ip4 = address };

    var server = addr.listen(io, .{
        .reuse_address = true,
    }) catch |err| {
        std.log.err("Failed to bind to port {d}: {}", .{ port, err });
        return err;
    };
    defer server.deinit(io);

    // Register SIGINT handler for graceful shutdown (Ctrl+C)
    const sig_action = std.posix.Sigaction{
        .handler = .{ .handler = handleSigint },
        .mask = std.posix.sigemptyset(),
        .flags = 0,
    };
    std.posix.sigaction(std.posix.SIG.INT, &sig_action, null);

    while (shutdown_flag.load(.monotonic) == 0) {
        const stream = server.accept(io) catch |err| {
            if (shutdown_flag.load(.monotonic) != 0) break;
            std.log.err("Accept failed: {}", .{err});
            continue;
        };

        _ = total_connections.fetchAdd(1, .monotonic);
        _ = active_connections.fetchAdd(1, .monotonic);

        var thread = std.Thread.spawn(.{}, handleConnection, .{
            io,
            stream,
            &r,
        }) catch |err| {
            std.log.err("Failed to spawn thread: {}", .{err});
            stream.close(io);
            _ = active_connections.fetchSub(1, .monotonic);
            continue;
        };

        // detach() tells the OS to clean up the thread when it exits.
        // We don't call join() because that would block the accept loop.
        thread.detach();
    }

    // Shutdown message
    const stdout_file2 = Io.File.stdout();
    var stdout_buf2: [1024]u8 = undefined;
    var stdout_fw2 = stdout_file2.writer(io, &stdout_buf2);
    const stdout_w2 = &stdout_fw2.interface;

    try stdout_w2.print("\n  Shutting down... ({d} total connections)\n", .{
        total_connections.load(.monotonic),
    });
    try stdout_w2.flush();
}

fn handleConnection(
    io: Io,
    stream: net.Stream,
    r: *const Router,
) void {
    // `defer` runs when this function returns (even on error).
    // This ensures the TCP connection is always closed and the
    // active connection counter is always decremented.
    defer {
        stream.close(io);
        _ = active_connections.fetchSub(1, .monotonic);
    }

    // Keep-alive: loop to handle multiple requests on the same connection.
    // HTTP/1.1 defaults to persistent connections — the client expects us to
    // keep reading after sending a response unless we say "Connection: close".
    while (true) {
        // ArenaAllocator: allocates memory in large chunks, frees all at once.
        // One arena per request — freed at the end of each loop iteration.
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        const allocator = arena.allocator();

        // Read the HTTP request.
        // Each iteration gets fresh stack buffers for the reader/writer.
        var read_buf: [max_header_buf]u8 = undefined;
        var reader = stream.reader(io, &read_buf);
        var req = Request.parse(allocator, &reader.interface) catch |err| {
            std.log.warn("Failed to parse request: {}", .{err});
            return; // Close connection on parse error
        };
        defer req.deinit(allocator);

        // Build the response writer
        var write_buf: [max_header_buf]u8 = undefined;
        var writer = stream.writer(io, &write_buf);
        var resp = Response.init(&writer.interface, allocator);
        defer resp.deinit();

        // --- Log the request (shows which thread handled it) ---
        std.log.info("[thread {d}] {s} {s}", .{
            std.Thread.getCurrentId(),
            @tagName(req.method),
            req.path,
        });

        // Dispatch to the matching handler
        if (!r.dispatch(&req, &resp)) {
            // No exact route match -- try static file serving for /static/* paths
            if (std.mem.startsWith(u8, req.path, "/static")) {
                handler.staticHandler(&req, &resp);
            } else {
                // Nothing matched at all -- send 404
                handler.notFoundHandler(&req, &resp);
            }
        }

        // Flush the response
        // Ensure all buffered data is actually sent to the client.
        // Without this, data might stay in the write buffer.
        writer.interface.flush() catch {};

        // Check if the client wants to close the connection.
        // HTTP/1.0 defaults to close. HTTP/1.1 defaults to keep-alive.
        const connection = req.getHeader("connection");
        const wants_close = (connection != null and
            std.ascii.eqlIgnoreCase(connection.?, "close")) or
            std.mem.eql(u8, req.version, "HTTP/1.0");

        if (wants_close) return;
    }
}

fn handleSigint(_: std.posix.SIG) callconv(.c) void {
    shutdown_flag.store(1, .monotonic);
}
