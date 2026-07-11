const std = @import("std");
const Request = @import("Request.zig");
const Response = @import("Response.zig");
const Static = @import("Static.zig");

var static_server: ?*const Static = null;

pub fn init(s: *const Static) void {
    static_server = s;
}

pub fn indexHandler(req: *Request, resp: *Response) void {
    _ = req;
    resp.html(
        \\<!DOCTYPE html>
        \\<html lang="en">
        \\<head>
        \\  <meta charset="UTF-8">
        \\  <title>Zig HTTP Server</title>
        \\  <style>
        \\    body { font-family: system-ui; max-width: 640px; margin: 2rem auto; padding: 0 1rem; }
        \\    h1 { color: #f7a41d; }
        \\    a { color: #1d8ff7; }
        \\    code { background: #f0f0f0; padding: 2px 6px; border-radius: 3px; }
        \\  </style>
        \\</head>
        \\<body>
        \\  <h1>Zig HTTP Server</h1>
        \\  <p>A from-scratch HTTP server built with Zig's standard library and threads.</p>
        \\  <h2>Endpoints</h2>
        \\  <ul>
        \\    <li><a href="/hello">/hello</a> - Plain text greeting</li>
        \\    <li><a href="/json">/json</a> - JSON response with thread info</li>
        \\    <li><a href="/headers">/headers</a> - Echo your request headers</li>
        \\    <li><code>POST /echo</code> - Echoes back the request body</li>
        \\    <li><a href="/static/">/static/</a> - Static file serving</li>
        \\  </ul>
        \\</body>
        \\</html>
    ) catch return;
}

pub fn helloHandler(req: *Request, resp: *Response) void {
    _ = req;
    resp.ok("Hello World!\n") catch return;
}

pub fn jsonHandler(req: *Request, resp: *Response) void {
    _ = req;

    const thread_id = std.Thread.getCurrentId();

    var out: std.Io.Writer.Allocating = .init(std.heap.page_allocator);
    defer out.deinit();

    var jw: std.json.Stringify = .{ .writer = &out.writer };
    const write = struct {
        fn w(j: *std.json.Stringify, v: anytype) void {
            j.write(v) catch return;
        }
    }.w;

    jw.beginObject() catch {
        resp.internalError() catch return;
        return;
    };
    jw.objectField("server") catch {
        resp.internalError() catch return;
        return;
    };
    write(&jw, "zig-http");
    jw.objectField("thread_id") catch {
        resp.internalError() catch return;
        return;
    };
    write(&jw, thread_id);
    jw.objectField("message") catch {
        resp.internalError() catch return;
        return;
    };
    write(&jw, "Hello from server!");
    jw.endObject() catch {
        resp.internalError() catch return;
        return;
    };

    resp.json(out.written()) catch return;
}

pub fn headersHandler(req: *Request, resp: *Response) void {
    var out: std.Io.Writer.Allocating = .init(std.heap.page_allocator);
    defer out.deinit();

    var jw: std.json.Stringify = .{ .writer = &out.writer };
    const write = struct {
        fn w(j: *std.json.Stringify, v: anytype) void {
            j.write(v) catch return;
        }
    }.w;

    jw.beginObject() catch {
        resp.internalError() catch return;
        return;
    };

    jw.objectField("method") catch {
        resp.internalError() catch return;
        return;
    };
    write(&jw, @tagName(req.method));

    jw.objectField("path") catch {
        resp.internalError() catch return;
        return;
    };
    write(&jw, req.path);

    jw.objectField("version") catch {
        resp.internalError() catch return;
        return;
    };
    write(&jw, req.version);

    jw.objectField("headers") catch {
        resp.internalError() catch return;
        return;
    };
    jw.beginObject() catch {
        resp.internalError() catch return;
        return;
    };
    for (req.headers) |h| {
        jw.objectField(h.name) catch {
            resp.internalError() catch return;
            return;
        };
        write(&jw, h.value);
    }
    jw.endObject() catch {
        resp.internalError() catch return;
        return;
    };

    jw.endObject() catch {
        resp.internalError() catch return;
        return;
    };

    resp.json(out.written()) catch return;
}

pub fn echoHandler(req: *Request, resp: *Response) void {
    if (req.body) |body| {
        resp.setStatus(.ok);
        resp.setHeader("content-type", req.contentType() orelse "application/octet-stream") catch return;
        resp.send(body) catch return;
    } else {
        resp.ok("No body provided. Send a POST request with a body.\n") catch return;
    }
}

pub fn staticHandler(req: *Request, resp: *Response) void {
    const s = static_server orelse {
        resp.internalError() catch return;
        return;
    };

    const file_path = if (std.mem.startsWith(u8, req.path, "/static/"))
        req.path[7..]
    else
        req.path;

    s.serveFile(resp, file_path) catch return;
}

pub fn notFoundHandler(req: *Request, resp: *Response) void {
    _ = req;
    resp.notFound() catch return;
}
