const std = @import("std");
const Terminal = @import("../utils/terminal.zig").Terminal;

pub const Theme = struct {
    name: []const u8,
    colors: Colors,

    pub const Colors = struct {
        background: u8,
        foreground: u8,
        primary: u8,
        secondary: u8,
        accent: u8,
        success: u8,
        warning: u8,
        error_color: u8,
        muted: u8,
        border: u8,
        selection: u8,
        highlight: u8,
    };

    pub fn dark() Theme {
        return Theme{
            .name = "dark",
            .colors = .{
                .background = 16,
                .foreground = 255,
                .primary = 39,
                .secondary = 245,
                .accent = 141,
                .success = 35,
                .warning = 220,
                .error_color = 196,
                .muted = 242,
                .border = 240,
                .selection = 238,
                .highlight = 25,
            },
        };
    }

    pub fn light() Theme {
        return Theme{
            .name = "light",
            .colors = .{
                .background = 255,
                .foreground = 16,
                .primary = 25,
                .secondary = 240,
                .accent = 91,
                .success = 28,
                .warning = 172,
                .error_color = 160,
                .muted = 245,
                .border = 249,
                .selection = 253,
                .highlight = 153,
            },
        };
    }

    pub fn nord() Theme {
        return Theme{
            .name = "nord",
            .colors = .{
                .background = 234,
                .foreground = 255,
                .primary = 110,
                .secondary = 245,
                .accent = 139,
                .success = 108,
                .warning = 222,
                .error_color = 167,
                .muted = 243,
                .border = 239,
                .selection = 236,
                .highlight = 25,
            },
        };
    }

    pub fn fromName(name: []const u8) Theme {
        if (std.mem.eql(u8, name, "light")) return light();
        if (std.mem.eql(u8, name, "nord")) return nord();
        return dark();
    }

    pub fn applyForeground(self: *const Theme, term: *Terminal, style: ColorStyle) void {
        const color = switch (style) {
            .normal => self.colors.foreground,
            .primary => self.colors.primary,
            .secondary => self.colors.secondary,
            .accent => self.colors.accent,
            .success => self.colors.success,
            .warning => self.colors.warning,
            .err => self.colors.error_color,
            .muted => self.colors.muted,
        };
        term.setForeground256(color);
    }

    pub fn applyBackground(self: *const Theme, term: *Terminal, style: ColorStyle) void {
        const color = switch (style) {
            .normal => self.colors.background,
            .primary => self.colors.highlight,
            .secondary => self.colors.selection,
            else => self.colors.background,
        };
        term.setBackground256(color);
    }

    pub const ColorStyle = enum {
        normal,
        primary,
        secondary,
        accent,
        success,
        warning,
        err,
        muted,
    };
};

test "Theme selection" {
    const dark = Theme.dark();
    try std.testing.expectEqualStrings("dark", dark.name);

    const light = Theme.light();
    try std.testing.expectEqualStrings("light", light.name);

    const from_name = Theme.fromName("nord");
    try std.testing.expectEqualStrings("nord", from_name.name);
}
