const std = @import("std");
const Response = @import("Response.zig");

pub const Static = @This();

io: std.Io,
dir: []const u8,

pub fn init(io_val: std.Io, dir: []const u8) Static {
    return .{
        .io = io_val,
        .dir = dir,
    };
}

const mime_types = std.StaticStringMap([]const u8).initComptime(.{
    .{ ".html", "text/html; charset=utf-8" },
    .{ ".htm", "text/html; charset=utf-8" },
    .{ ".css", "text/css; charset=utf-8" },
    .{ ".js", "application/javascript; charset=utf-8" },
    .{ ".mjs", "application/javascript; charset=utf-8" },
    .{ ".json", "application/json; charset=utf-8" },
    .{ ".xml", "application/xml; charset=utf-8" },
    .{ ".txt", "text/plain; charset=utf-8" },
    .{ ".csv", "text/csv; charset=utf-8" },
    .{ ".png", "image/png" },
    .{ ".jpg", "image/jpeg" },
    .{ ".jpeg", "image/jpeg" },
    .{ ".gif", "image/gif" },
    .{ ".svg", "image/svg+xml" },
    .{ ".ico", "image/x-icon" },
    .{ ".webp", "image/webp" },
    .{ ".mp3", "audio/mpeg" },
    .{ ".mp4", "video/mp4" },
    .{ ".webm", "video/webm" },
    .{ ".woff", "font/woff" },
    .{ ".woff2", "font/woff2" },
    .{ ".ttf", "font/ttf" },
    .{ ".otf", "font/otf" },
    .{ ".pdf", "application/pdf" },
    .{ ".zip", "application/zip" },
    .{ ".gz", "application/gzip" },
    .{ ".wasm", "application/wasm" },
});

pub const PathError = error{ PathTooLong, InvalidPath };

pub fn resolvePath(self: *const Static, buf: []u8, path: []const u8) PathError![]u8 {
    if (std.mem.indexOf(u8, path, "..") != null) return error.InvalidPath;
    return std.fmt.bufPrint(buf, "{s}{s}", .{ self.dir, path }) catch return error.PathTooLong;
}

pub fn mimeType(path: []const u8) []const u8 {
    const ext = std.fs.path.extension(path);
    return mime_types.get(ext) orelse "application/octet-stream";
}

pub fn serveFile(self: *const Static, r: *Response, path: []const u8) !void {
    var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const full_path = self.resolvePath(&path_buffer, path) catch {
        r.setStatus(.forbidden);
        try r.setHeader("content-type", "text/plain");
        try r.send("403 Forbidden\n");
        return;
    };

    const file = std.Io.Dir.cwd().openFile(self.io, full_path, .{}) catch {
        r.notFound() catch return;
        return;
    };
    defer file.close(self.io);

    const stat = file.stat(self.io) catch {
        r.internalError() catch return;
        return;
    };

    r.setStatus(.ok);
    try r.setHeader("content-type", mimeType(full_path));
    try r.setContentLength(stat.size);
    try r.setHeader("cache-control", "public, max-age=3600");
    try r.sendHead();

    var file_buffer: [64 * 1024]u8 = undefined;
    var offset: u64 = 0;
    while (true) {
        const bytes_read = file.readPositional(self.io, &.{&file_buffer}, offset) catch return;
        if (bytes_read == 0) break;
        r.writer.writeAll(file_buffer[0..bytes_read]) catch return;
        offset += bytes_read;
    }

    try r.end();
}

test "mimeType returns correct types" {
    try std.testing.expectEqualStrings("text/html; charset=utf-8", mimeType("index.html"));
    try std.testing.expectEqualStrings("text/css; charset=utf-8", mimeType("style.css"));
    try std.testing.expectEqualStrings("application/javascript; charset=utf-8", mimeType("app.js"));
    try std.testing.expectEqualStrings("application/json; charset=utf-8", mimeType("data.json"));
    try std.testing.expectEqualStrings("image/png", mimeType("logo.png"));
    try std.testing.expectEqualStrings("image/jpeg", mimeType("photo.jpg"));
    try std.testing.expectEqualStrings("image/svg+xml", mimeType("icon.svg"));
    try std.testing.expectEqualStrings("font/woff2", mimeType("font.woff2"));
    try std.testing.expectEqualStrings("application/wasm", mimeType("module.wasm"));
}

test "mimeType returns octet-stream for unknown extension" {
    try std.testing.expectEqualStrings("application/octet-stream", mimeType("file.xyz"));
    try std.testing.expectEqualStrings("application/octet-stream", mimeType("noextension"));
}

test "mimeType handles paths with directories" {
    try std.testing.expectEqualStrings("text/html; charset=utf-8", mimeType("/static/index.html"));
    try std.testing.expectEqualStrings("image/png", mimeType("images/logo.png"));
}
