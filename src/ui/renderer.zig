const std = @import("std");
const Terminal = @import("../utils/terminal.zig").Terminal;
const Theme = @import("theme.zig").Theme;

pub const Renderer = struct {
    terminal: *Terminal,
    theme: Theme,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, terminal: *Terminal, theme: Theme) Renderer {
        return Renderer{
            .terminal = terminal,
            .theme = theme,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Renderer) void {
        _ = self;
    }

    pub fn clear(self: *Renderer) void {
        self.terminal.clear();
    }

    pub fn flush(self: *Renderer) void {
        _ = self;
    }

    pub fn moveTo(self: *Renderer, row: u16, col: u16) void {
        self.terminal.moveCursor(row, col);
    }

    pub fn drawText(self: *Renderer, text: []const u8) void {
        self.terminal.writeText(text);
    }

    pub fn drawTextStyled(self: *Renderer, text: []const u8, style: Theme.ColorStyle) void {
        self.theme.applyForeground(self.terminal, style);
        self.terminal.writeText(text);
        self.terminal.resetAttributes();
    }

    pub fn drawBox(self: *Renderer, row: u16, col: u16, width: u16, height: u16, title: ?[]const u8) void {
        self.terminal.setForeground256(self.theme.colors.border);

        self.terminal.moveCursor(row, col);
        self.terminal.writeText("┌");
        self.drawHorizontalLine(width - 2);
        self.terminal.writeText("┐");

        var i: u16 = 1;
        while (i < height - 1) : (i += 1) {
            self.terminal.moveCursor(row + i, col);
            self.terminal.writeText("│");
            self.terminal.moveCursor(row + i, col + width - 1);
            self.terminal.writeText("│");
        }

        self.terminal.moveCursor(row + height - 1, col);
        self.terminal.writeText("└");
        self.drawHorizontalLine(width - 2);
        self.terminal.writeText("┘");

        if (title) |t| {
            self.terminal.moveCursor(row, col + 2);
            self.terminal.setForeground256(self.theme.colors.primary);
            self.terminal.writeText(" ");
            self.terminal.writeText(t);
            self.terminal.writeText(" ");
        }

        self.terminal.resetAttributes();
    }

    fn drawHorizontalLine(self: *Renderer, width: u16) void {
        var i: u16 = 0;
        while (i < width) : (i += 1) {
            self.terminal.writeText("─");
        }
    }

    pub fn drawProgressBar(self: *Renderer, row: u16, col: u16, width: u16, progress: f32) void {
        self.terminal.moveCursor(row, col);
        self.terminal.writeText("[");

        const bar_width = width - 2;
        const filled = @as(u16, @intFromFloat(@as(f32, @floatFromInt(bar_width)) * std.math.clamp(progress, 0.0, 1.0)));

        self.terminal.setForeground256(self.theme.colors.success);
        var i: u16 = 0;
        while (i < filled) : (i += 1) {
            self.terminal.writeText("█");
        }

        self.terminal.setForeground256(self.theme.colors.muted);
        while (i < bar_width) : (i += 1) {
            self.terminal.writeText("░");
        }

        self.terminal.resetAttributes();
        self.terminal.writeText("]");
    }

    pub fn drawStatusLine(self: *Renderer, row: u16, items: []const StatusItem) void {
        self.terminal.moveCursor(row, 0);
        self.terminal.setBackground256(self.theme.colors.selection);
        self.terminal.setForeground256(self.theme.colors.foreground);

        var col: u16 = 0;
        for (items) |item| {
            self.terminal.writeText(item.text);
            col += @intCast(item.text.len);
            if (col < self.terminal.width) {
                self.terminal.writeText(" │ ");
                col += 3;
            }
        }

        while (col < self.terminal.width) : (col += 1) {
            self.terminal.writeText(" ");
        }

        self.terminal.resetAttributes();
    }

    pub const StatusItem = struct {
        text: []const u8,
        style: Theme.ColorStyle = .normal,
    };
};

test "Renderer initialization" {
    var term = try Terminal.init();
    defer term.deinit();

    var renderer = Renderer.init(std.testing.allocator, &term, Theme.dark());
    defer renderer.deinit();
}
