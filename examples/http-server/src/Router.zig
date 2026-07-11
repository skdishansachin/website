const std = @import("std");
const Request = @import("Request.zig");
const Response = @import("Response.zig");
const Router = @This();

pub const HandlerFn = *const fn (*Request, *Response) void;

pub const Route = struct {
    method: []const u8,
    path: []const u8,
    handler: HandlerFn,
};

routes: std.ArrayListUnmanaged(Route),
allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator) Router {
    return .{
        .routes = .empty,
        .allocator = allocator,
    };
}

pub fn deinit(self: *Router) void {
    self.routes.deinit(self.allocator);
}

pub fn addRoute(self: *Router, method: []const u8, path: []const u8, handler: HandlerFn) !void {
    try self.routes.append(self.allocator, .{ .method = method, .path = path, .handler = handler });
}

pub fn get(self: *Router, path: []const u8, handler: HandlerFn) !void {
    try self.addRoute("GET", path, handler);
}

pub fn post(self: *Router, path: []const u8, handler: HandlerFn) !void {
    try self.addRoute("POST", path, handler);
}

pub fn put(self: *Router, path: []const u8, handler: HandlerFn) !void {
    try self.addRoute("PUT", path, handler);
}

pub fn delete(self: *Router, path: []const u8, handler: HandlerFn) !void {
    try self.addRoute("DELETE", path, handler);
}

pub fn dispatch(self: *const Router, req: *Request, res: *Response) bool {
    for (self.routes.items) |route| {
        if (std.ascii.eqlIgnoreCase(@tagName(req.method), route.method) and std.mem.eql(u8, req.path, route.path)) {
            route.handler(req, res);
            return true;
        }
    }
    return false;
}
