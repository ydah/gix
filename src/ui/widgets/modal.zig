const std = @import("std");
const Terminal = @import("../../utils/terminal.zig").Terminal;
const Theme = @import("../theme.zig").Theme;

pub const ModalAction = enum {
    confirm,
    cancel,
    none,
};

pub const Modal = struct {
    title: []const u8,
    message: []const u8,
    width: u16,
    height: u16,
    visible: bool,
    show_cancel: bool,
    confirm_text: []const u8,
    cancel_text: []const u8,
    selected_button: u8,

    pub fn init(title: []const u8, message: []const u8) Modal {
        return Modal{
            .title = title,
            .message = message,
            .width = 50,
            .height = 10,
            .visible = false,
            .show_cancel = true,
            .confirm_text = "OK",
            .cancel_text = "Cancel",
            .selected_button = 0,
        };
    }

    pub fn show(self: *Modal) void {
        self.visible = true;
        self.selected_button = 0;
    }

    pub fn hide(self: *Modal) void {
        self.visible = false;
    }

    pub fn setSize(self: *Modal, width: u16, height: u16) void {
        self.width = width;
        self.height = height;
    }

    pub fn setButtons(self: *Modal, confirm: []const u8, cancel: ?[]const u8) void {
        self.confirm_text = confirm;
        if (cancel) |c| {
            self.cancel_text = c;
            self.show_cancel = true;
        } else {
            self.show_cancel = false;
        }
    }

    pub fn handleInput(self: *Modal, key: u8) ModalAction {
        if (!self.visible) return .none;

        switch (key) {
            '\t', 'h', 'l' => {
                if (self.show_cancel) {
                    self.selected_button = if (self.selected_button == 0) 1 else 0;
                }
            },
            '\r', '\n' => {
                self.visible = false;
                return if (self.selected_button == 0) .confirm else .cancel;
            },
            27 => {
                self.visible = false;
                return .cancel;
            },
            else => {},
        }

        return .none;
    }

    pub fn render(self: *const Modal, terminal: *Terminal, theme: *const Theme, screen_width: u16, screen_height: u16) void {
        if (!self.visible) return;

        const start_col = (screen_width -| self.width) / 2;
        const start_row = (screen_height -| self.height) / 2;

        self.renderBox(terminal, theme, start_row, start_col);
        self.renderTitle(terminal, theme, start_row, start_col);
        self.renderMessage(terminal, theme, start_row + 2, start_col + 2);
        self.renderButtons(terminal, theme, start_row + self.height - 2, start_col);
    }

    fn renderBox(self: *const Modal, terminal: *Terminal, theme: *const Theme, start_row: u16, start_col: u16) void {
        terminal.setBackground256(theme.colors.background);
        terminal.setForeground256(theme.colors.border);

        terminal.moveCursor(start_row, start_col);
        terminal.writeText("┌");
        var i: u16 = 1;
        while (i < self.width - 1) : (i += 1) {
            terminal.writeText("─");
        }
        terminal.writeText("┐");

        var row: u16 = 1;
        while (row < self.height - 1) : (row += 1) {
            terminal.moveCursor(start_row + row, start_col);
            terminal.writeText("│");
            var col: u16 = 1;
            while (col < self.width - 1) : (col += 1) {
                terminal.writeText(" ");
            }
            terminal.writeText("│");
        }

        terminal.moveCursor(start_row + self.height - 1, start_col);
        terminal.writeText("└");
        i = 1;
        while (i < self.width - 1) : (i += 1) {
            terminal.writeText("─");
        }
        terminal.writeText("┘");

        terminal.resetAttributes();
    }

    fn renderTitle(self: *const Modal, terminal: *Terminal, theme: *const Theme, start_row: u16, start_col: u16) void {
        const title_start = start_col + (self.width - @as(u16, @intCast(self.title.len)) - 4) / 2;

        terminal.moveCursor(start_row, title_start);
        terminal.setForeground256(theme.colors.primary);
        terminal.setBold(true);
        terminal.writeText("[ ");
        terminal.writeText(self.title);
        terminal.writeText(" ]");
        terminal.resetAttributes();
    }

    fn renderMessage(self: *const Modal, terminal: *Terminal, theme: *const Theme, start_row: u16, start_col: u16) void {
        terminal.moveCursor(start_row, start_col);
        terminal.setForeground256(theme.colors.foreground);

        const max_width = self.width - 4;
        var lines = std.mem.splitSequence(u8, self.message, "\n");
        var row: u16 = 0;
        while (lines.next()) |line| {
            if (row >= self.height - 5) break;
            terminal.moveCursor(start_row + row, start_col);
            const display_len = @min(line.len, @as(usize, max_width));
            terminal.writeText(line[0..display_len]);
            row += 1;
        }

        terminal.resetAttributes();
    }

    fn renderButtons(self: *const Modal, terminal: *Terminal, theme: *const Theme, row: u16, start_col: u16) void {
        const buttons_width = @as(u16, @intCast(self.confirm_text.len + 4)) +
            if (self.show_cancel) @as(u16, @intCast(self.cancel_text.len + 6)) else 0;
        var col = start_col + (self.width - buttons_width) / 2;

        terminal.moveCursor(row, col);
        if (self.selected_button == 0) {
            terminal.setBackground256(theme.colors.primary);
            terminal.setForeground256(theme.colors.background);
        } else {
            terminal.setForeground256(theme.colors.foreground);
        }
        terminal.writeText("[ ");
        terminal.writeText(self.confirm_text);
        terminal.writeText(" ]");
        terminal.resetAttributes();

        if (self.show_cancel) {
            col += @as(u16, @intCast(self.confirm_text.len + 5));
            terminal.moveCursor(row, col);
            if (self.selected_button == 1) {
                terminal.setBackground256(theme.colors.primary);
                terminal.setForeground256(theme.colors.background);
            } else {
                terminal.setForeground256(theme.colors.foreground);
            }
            terminal.writeText("[ ");
            terminal.writeText(self.cancel_text);
            terminal.writeText(" ]");
            terminal.resetAttributes();
        }
    }
};

test "Modal init" {
    const modal = Modal.init("Test", "Test message");
    try std.testing.expectEqualStrings("Test", modal.title);
    try std.testing.expect(!modal.visible);
}

test "Modal show/hide" {
    var modal = Modal.init("Test", "Test message");
    modal.show();
    try std.testing.expect(modal.visible);
    modal.hide();
    try std.testing.expect(!modal.visible);
}

test "Modal confirm action" {
    var modal = Modal.init("Test", "Test message");
    modal.show();
    const action = modal.handleInput('\r');
    try std.testing.expect(action == .confirm);
    try std.testing.expect(!modal.visible);
}
