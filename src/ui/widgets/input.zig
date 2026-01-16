const std = @import("std");
const Terminal = @import("../../utils/terminal.zig").Terminal;
const Theme = @import("../theme.zig").Theme;

pub const Input = struct {
    buffer: [256]u8,
    length: usize,
    cursor_pos: usize,
    placeholder: []const u8,
    focused: bool,

    pub fn init(placeholder: []const u8) Input {
        return Input{
            .buffer = undefined,
            .length = 0,
            .cursor_pos = 0,
            .placeholder = placeholder,
            .focused = false,
        };
    }

    pub fn clear(self: *Input) void {
        self.length = 0;
        self.cursor_pos = 0;
    }

    pub fn getText(self: *const Input) []const u8 {
        return self.buffer[0..self.length];
    }

    pub fn setText(self: *Input, text: []const u8) void {
        const len = @min(text.len, self.buffer.len);
        @memcpy(self.buffer[0..len], text[0..len]);
        self.length = len;
        self.cursor_pos = len;
    }

    pub fn insertChar(self: *Input, char: u8) void {
        if (self.length >= self.buffer.len) return;

        var i = self.length;
        while (i > self.cursor_pos) : (i -= 1) {
            self.buffer[i] = self.buffer[i - 1];
        }
        self.buffer[self.cursor_pos] = char;
        self.length += 1;
        self.cursor_pos += 1;
    }

    pub fn deleteChar(self: *Input) void {
        if (self.cursor_pos == 0) return;

        var i = self.cursor_pos - 1;
        while (i < self.length - 1) : (i += 1) {
            self.buffer[i] = self.buffer[i + 1];
        }
        self.length -= 1;
        self.cursor_pos -= 1;
    }

    pub fn moveCursorLeft(self: *Input) void {
        if (self.cursor_pos > 0) {
            self.cursor_pos -= 1;
        }
    }

    pub fn moveCursorRight(self: *Input) void {
        if (self.cursor_pos < self.length) {
            self.cursor_pos += 1;
        }
    }

    pub fn moveCursorHome(self: *Input) void {
        self.cursor_pos = 0;
    }

    pub fn moveCursorEnd(self: *Input) void {
        self.cursor_pos = self.length;
    }

    pub fn handleKey(self: *Input, key: Terminal.Key) bool {
        switch (key) {
            .char => |c| {
                if (c >= 32 and c < 127) {
                    self.insertChar(c);
                    return true;
                }
            },
            .backspace => {
                self.deleteChar();
                return true;
            },
            .arrow_left => {
                self.moveCursorLeft();
                return true;
            },
            .arrow_right => {
                self.moveCursorRight();
                return true;
            },
            .home => {
                self.moveCursorHome();
                return true;
            },
            .end => {
                self.moveCursorEnd();
                return true;
            },
            else => {},
        }
        return false;
    }

    pub fn render(self: *const Input, terminal: *Terminal, theme: *const Theme, row: u16, col: u16, width: u16) void {
        terminal.moveCursor(row, col);
        terminal.setBackground256(theme.colors.selection);

        if (self.focused) {
            terminal.setForeground256(theme.colors.foreground);
        } else {
            terminal.setForeground256(theme.colors.muted);
        }

        const text = if (self.length > 0) self.buffer[0..self.length] else self.placeholder;
        const max_len = @as(usize, width);
        const display_text = if (text.len > max_len) text[0..max_len] else text;

        terminal.writeText(display_text);

        var padding = width -| @as(u16, @intCast(display_text.len));
        while (padding > 0) : (padding -= 1) {
            terminal.writeText(" ");
        }

        terminal.resetAttributes();

        if (self.focused) {
            terminal.moveCursor(row, col + @as(u16, @intCast(self.cursor_pos)));
            terminal.showCursor();
        }
    }
};

test "Input basic operations" {
    var input = Input.init("Search...");

    input.insertChar('h');
    input.insertChar('e');
    input.insertChar('l');
    input.insertChar('l');
    input.insertChar('o');

    try std.testing.expectEqualStrings("hello", input.getText());

    input.deleteChar();
    try std.testing.expectEqualStrings("hell", input.getText());
}
