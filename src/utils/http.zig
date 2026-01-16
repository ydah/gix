const std = @import("std");
const Allocator = std.mem.Allocator;

pub const HttpClient = struct {
    allocator: Allocator,

    pub const Method = enum {
        GET,
        POST,
        PUT,
        PATCH,
        DELETE,

        pub fn toString(self: Method) []const u8 {
            return switch (self) {
                .GET => "GET",
                .POST => "POST",
                .PUT => "PUT",
                .PATCH => "PATCH",
                .DELETE => "DELETE",
            };
        }
    };

    pub const Header = struct {
        name: []const u8,
        value: []const u8,
    };

    pub const Request = struct {
        method: Method,
        url: []const u8,
        headers: []const Header,
        body: ?[]const u8,
    };

    pub const Response = struct {
        status: u16,
        body: []const u8,
        allocator: Allocator,

        pub fn deinit(self: *Response) void {
            self.allocator.free(self.body);
        }
    };

    pub fn init(allocator: Allocator) HttpClient {
        return HttpClient{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *HttpClient) void {
        _ = self;
    }

    pub fn send(self: *HttpClient, request: Request) !Response {
        var argv_buf: [64][]const u8 = undefined;
        var header_strs: [16][]const u8 = undefined;
        var argc: usize = 0;
        var header_count: usize = 0;

        argv_buf[argc] = "curl";
        argc += 1;
        argv_buf[argc] = "-s";
        argc += 1;
        argv_buf[argc] = "-w";
        argc += 1;
        argv_buf[argc] = "\n%{http_code}";
        argc += 1;
        argv_buf[argc] = "-X";
        argc += 1;
        argv_buf[argc] = request.method.toString();
        argc += 1;

        for (request.headers) |header| {
            if (header_count >= header_strs.len) break;
            argv_buf[argc] = "-H";
            argc += 1;
            header_strs[header_count] = try std.fmt.allocPrint(self.allocator, "{s}: {s}", .{ header.name, header.value });
            argv_buf[argc] = header_strs[header_count];
            argc += 1;
            header_count += 1;
        }

        if (request.body) |body| {
            argv_buf[argc] = "-d";
            argc += 1;
            argv_buf[argc] = body;
            argc += 1;
        }

        argv_buf[argc] = request.url;
        argc += 1;

        defer {
            for (header_strs[0..header_count]) |s| {
                self.allocator.free(s);
            }
        }

        var result = std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = argv_buf[0..argc],
        }) catch {
            return Response{
                .status = 0,
                .body = try self.allocator.dupe(u8, ""),
                .allocator = self.allocator,
            };
        };
        defer self.allocator.free(result.stderr);

        if (result.stdout.len == 0) {
            return Response{
                .status = 0,
                .body = try self.allocator.dupe(u8, ""),
                .allocator = self.allocator,
            };
        }

        var last_newline: usize = result.stdout.len;
        var i = result.stdout.len;
        while (i > 0) {
            i -= 1;
            if (result.stdout[i] == '\n') {
                last_newline = i;
                break;
            }
        }

        const status_str = std.mem.trim(u8, result.stdout[last_newline..], "\n\r ");
        const status = std.fmt.parseInt(u16, status_str, 10) catch 0;

        const body_slice = if (last_newline > 0)
            result.stdout[0..last_newline]
        else
            "";

        const body = try self.allocator.dupe(u8, body_slice);
        self.allocator.free(result.stdout);

        return Response{
            .status = status,
            .body = body,
            .allocator = self.allocator,
        };
    }
};

test "HttpClient initialization" {
    var client = HttpClient.init(std.testing.allocator);
    defer client.deinit();
}
