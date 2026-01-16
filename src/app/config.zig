const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Config = struct {
    auth: AuthConfig,
    ui: UIConfig,
    cache: CacheConfig,
    allocator: Allocator,

    pub const AuthConfig = struct {
        token: ?[]const u8 = null,
    };

    pub const UIConfig = struct {
        theme: []const u8 = "dark",
        show_icons: bool = true,
        page_size: u32 = 20,
    };

    pub const CacheConfig = struct {
        enabled: bool = true,
        ttl: u32 = 300,
        max_size: usize = 104857600,
    };

    pub fn init(allocator: Allocator) Config {
        return Config{
            .auth = .{},
            .ui = .{},
            .cache = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Config) void {
        if (self.auth.token) |token| {
            self.allocator.free(token);
        }
    }

    pub fn load(allocator: Allocator, path: []const u8) !Config {
        const file = std.fs.cwd().openFile(path, .{}) catch |e| {
            if (e == error.FileNotFound) {
                return Config.init(allocator);
            }
            return e;
        };
        defer file.close();

        const content = try file.readToEndAlloc(allocator, 1024 * 1024);
        defer allocator.free(content);

        return parseToml(allocator, content);
    }

    fn parseToml(allocator: Allocator, content: []const u8) !Config {
        var config = Config.init(allocator);

        var lines = std.mem.splitScalar(u8, content, '\n');
        var current_section: []const u8 = "";

        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t\r");

            if (trimmed.len == 0 or trimmed[0] == '#') {
                continue;
            }

            if (trimmed[0] == '[' and trimmed[trimmed.len - 1] == ']') {
                current_section = trimmed[1 .. trimmed.len - 1];
                continue;
            }

            if (std.mem.indexOfScalar(u8, trimmed, '=')) |eq_pos| {
                const key = std.mem.trim(u8, trimmed[0..eq_pos], " \t");
                var value = std.mem.trim(u8, trimmed[eq_pos + 1 ..], " \t");

                if (value.len >= 2 and value[0] == '"' and value[value.len - 1] == '"') {
                    value = value[1 .. value.len - 1];
                }

                if (std.mem.eql(u8, current_section, "auth")) {
                    if (std.mem.eql(u8, key, "token")) {
                        config.auth.token = try allocator.dupe(u8, value);
                    }
                } else if (std.mem.eql(u8, current_section, "ui")) {
                    if (std.mem.eql(u8, key, "theme")) {
                        config.ui.theme = value;
                    } else if (std.mem.eql(u8, key, "show_icons")) {
                        config.ui.show_icons = std.mem.eql(u8, value, "true");
                    } else if (std.mem.eql(u8, key, "page_size")) {
                        config.ui.page_size = std.fmt.parseInt(u32, value, 10) catch 20;
                    }
                } else if (std.mem.eql(u8, current_section, "cache")) {
                    if (std.mem.eql(u8, key, "enabled")) {
                        config.cache.enabled = std.mem.eql(u8, value, "true");
                    } else if (std.mem.eql(u8, key, "ttl")) {
                        config.cache.ttl = std.fmt.parseInt(u32, value, 10) catch 300;
                    } else if (std.mem.eql(u8, key, "max_size")) {
                        config.cache.max_size = std.fmt.parseInt(usize, value, 10) catch 104857600;
                    }
                }
            }
        }

        return config;
    }

    pub fn save(self: *const Config, path: []const u8) !void {
        const dir_path = std.fs.path.dirname(path) orelse ".";

        std.fs.cwd().makePath(dir_path) catch |e| {
            if (e != error.PathAlreadyExists) {
                return e;
            }
        };

        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        var buffer: [4096]u8 = undefined;

        const auth_section = std.fmt.bufPrint(&buffer, "[auth]\ntoken = \"{s}\"\n\n", .{
            self.auth.token orelse "",
        }) catch return error.BufferTooSmall;
        try file.writeAll(auth_section);

        const ui_section = std.fmt.bufPrint(&buffer, "[ui]\ntheme = \"{s}\"\nshow_icons = {}\npage_size = {d}\n\n", .{
            self.ui.theme,
            self.ui.show_icons,
            self.ui.page_size,
        }) catch return error.BufferTooSmall;
        try file.writeAll(ui_section);

        const cache_section = std.fmt.bufPrint(&buffer, "[cache]\nenabled = {}\nttl = {d}\nmax_size = {d}\n", .{
            self.cache.enabled,
            self.cache.ttl,
            self.cache.max_size,
        }) catch return error.BufferTooSmall;
        try file.writeAll(cache_section);
    }

    pub fn getDefaultPath(allocator: Allocator) ![]const u8 {
        if (std.posix.getenv("HOME")) |home| {
            return try std.fmt.allocPrint(allocator, "{s}/.config/gix/config.toml", .{home});
        }
        return try allocator.dupe(u8, ".config/gix/config.toml");
    }
};

test "Config default values" {
    const config = Config.init(std.testing.allocator);
    try std.testing.expect(config.auth.token == null);
    try std.testing.expectEqualStrings("dark", config.ui.theme);
    try std.testing.expect(config.ui.show_icons);
    try std.testing.expect(config.ui.page_size == 20);
    try std.testing.expect(config.cache.enabled);
    try std.testing.expect(config.cache.ttl == 300);
}

test "Config TOML parsing" {
    const toml =
        \\[auth]
        \\token = "test_token"
        \\
        \\[ui]
        \\theme = "light"
        \\show_icons = false
        \\page_size = 50
        \\
        \\[cache]
        \\enabled = true
        \\ttl = 600
    ;

    var config = try Config.parseToml(std.testing.allocator, toml);
    defer config.deinit();

    try std.testing.expectEqualStrings("test_token", config.auth.token.?);
    try std.testing.expect(!config.ui.show_icons);
    try std.testing.expect(config.ui.page_size == 50);
    try std.testing.expect(config.cache.ttl == 600);
}
