const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Logger = struct {
    level: LogLevel,
    output_file: ?std.fs.File,
    allocator: Allocator,

    pub const LogLevel = enum(u8) {
        debug = 0,
        info = 1,
        warning = 2,
        err = 3,

        pub fn toString(self: LogLevel) []const u8 {
            return switch (self) {
                .debug => "DEBUG",
                .info => "INFO",
                .warning => "WARN",
                .err => "ERROR",
            };
        }
    };

    pub fn init(allocator: Allocator, level: LogLevel) Logger {
        return Logger{
            .level = level,
            .output_file = null,
            .allocator = allocator,
        };
    }

    pub fn initWithFile(allocator: Allocator, level: LogLevel, file_path: []const u8) !Logger {
        const file = try std.fs.cwd().createFile(file_path, .{ .truncate = false });
        try file.seekFromEnd(0);
        return Logger{
            .level = level,
            .output_file = file,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Logger) void {
        if (self.output_file) |file| {
            file.close();
        }
    }

    pub fn debug(self: *Logger, comptime fmt: []const u8, args: anytype) void {
        self.log(.debug, fmt, args);
    }

    pub fn info(self: *Logger, comptime fmt: []const u8, args: anytype) void {
        self.log(.info, fmt, args);
    }

    pub fn warn(self: *Logger, comptime fmt: []const u8, args: anytype) void {
        self.log(.warning, fmt, args);
    }

    pub fn err(self: *Logger, comptime fmt: []const u8, args: anytype) void {
        self.log(.err, fmt, args);
    }

    fn log(self: *Logger, level: LogLevel, comptime fmt: []const u8, args: anytype) void {
        if (@intFromEnum(level) < @intFromEnum(self.level)) {
            return;
        }

        var buffer: [4096]u8 = undefined;
        const timestamp = getTimestamp();
        const level_str = level.toString();

        const prefix = std.fmt.bufPrint(buffer[0..128], "[{d}] [{s}] ", .{ timestamp, level_str }) catch return;
        const message = std.fmt.bufPrint(buffer[prefix.len..], fmt ++ "\n", args) catch return;

        const full_message = buffer[0 .. prefix.len + message.len];

        if (self.output_file) |file| {
            file.writeAll(full_message) catch {};
        } else {
            std.fs.File.stderr().writeAll(full_message) catch {};
        }
    }

    fn getTimestamp() i64 {
        return std.time.timestamp();
    }
};

test "Logger basic functionality" {
    var logger = Logger.init(std.testing.allocator, .info);
    defer logger.deinit();

    logger.info("Test message: {s}", .{"hello"});
    logger.debug("This should not appear", .{});
    logger.err("Error message", .{});
}

test "Logger level filtering" {
    var logger = Logger.init(std.testing.allocator, .warning);
    defer logger.deinit();

    logger.debug("debug", .{});
    logger.info("info", .{});
    logger.warn("warn", .{});
    logger.err("error", .{});
}
