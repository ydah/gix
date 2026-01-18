const std = @import("std");
const Terminal = @import("../../utils/terminal.zig").Terminal;
const Theme = @import("../theme.zig").Theme;

pub const StatusBar = struct {
    message: ?[]const u8,
    view_name: []const u8,
    loading: bool,
    loading_frame: u8,
    key_hints: []const KeyHint,

    pub const KeyHint = struct {
        key: []const u8,
        description: []const u8,
    };

    const loading_chars = [_][]const u8{ "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" };

    pub fn init() StatusBar {
        return StatusBar{
            .message = null,
            .view_name = "Dashboard",
            .loading = false,
            .loading_frame = 0,
            .key_hints = &[_]KeyHint{},
        };
    }

    pub fn setMessage(self: *StatusBar, message: ?[]const u8) void {
        self.message = message;
    }

    pub fn setViewName(self: *StatusBar, name: []const u8) void {
        self.view_name = name;
    }

    pub fn setLoading(self: *StatusBar, loading: bool) void {
        self.loading = loading;
        if (!loading) {
            self.loading_frame = 0;
        }
    }

    pub fn setKeyHints(self: *StatusBar, hints: []const KeyHint) void {
        self.key_hints = hints;
    }

    pub fn tick(self: *StatusBar) void {
        if (self.loading) {
            self.loading_frame = (self.loading_frame + 1) % loading_chars.len;
        }
    }

    pub fn render(self: *const StatusBar, terminal: *Terminal, theme: *const Theme, row: u16, width: u16) void {
        terminal.moveCursor(row, 0);
        terminal.setBackground256(theme.colors.selection);
        terminal.setForeground256(theme.colors.foreground);

        var col: u16 = 0;
        while (col < width) : (col += 1) {
            terminal.writeText(" ");
        }

        terminal.moveCursor(row, 1);

        if (self.loading) {
            terminal.setForeground256(theme.colors.primary);
            terminal.writeText(loading_chars[self.loading_frame]);
            terminal.writeText(" ");
        }

        terminal.setForeground256(theme.colors.primary);
        terminal.setBold(true);
        terminal.writeText(self.view_name);
        terminal.resetAttributes();
        terminal.setBackground256(theme.colors.selection);

        if (self.message) |msg| {
            terminal.writeText(" | ");
            terminal.setForeground256(theme.colors.secondary);
            const max_len = @as(usize, width / 2);
            const display_msg = if (msg.len > max_len) msg[0..max_len] else msg;
            terminal.writeText(display_msg);
        }

        self.renderKeyHints(terminal, theme, row, width);

        terminal.resetAttributes();
    }

    fn renderKeyHints(self: *const StatusBar, terminal: *Terminal, theme: *const Theme, row: u16, width: u16) void {
        if (self.key_hints.len == 0) return;

        var total_len: usize = 0;
        for (self.key_hints) |hint| {
            total_len += hint.key.len + hint.description.len + 3;
        }

        const start_col = width -| @as(u16, @intCast(total_len)) -| 2;
        terminal.moveCursor(row, start_col);

        for (self.key_hints) |hint| {
            terminal.setForeground256(theme.colors.primary);
            terminal.setBold(true);
            terminal.writeText(hint.key);
            terminal.resetAttributes();
            terminal.setBackground256(theme.colors.selection);
            terminal.setForeground256(theme.colors.muted);
            terminal.writeText(":");
            terminal.writeText(hint.description);
            terminal.writeText(" ");
        }
    }
};

test "StatusBar init" {
    const statusbar = StatusBar.init();
    try std.testing.expectEqualStrings("Dashboard", statusbar.view_name);
    try std.testing.expect(!statusbar.loading);
}

test "StatusBar loading animation" {
    var statusbar = StatusBar.init();
    statusbar.setLoading(true);
    try std.testing.expect(statusbar.loading);

    const initial_frame = statusbar.loading_frame;
    statusbar.tick();
    try std.testing.expect(statusbar.loading_frame != initial_frame or statusbar.loading_frame == 0);
}

test "StatusBar set message" {
    var statusbar = StatusBar.init();
    statusbar.setMessage("Test message");
    try std.testing.expectEqualStrings("Test message", statusbar.message.?);
}
