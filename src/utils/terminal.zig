const std = @import("std");
const posix = std.posix;

pub const Terminal = struct {
    original_termios: ?posix.termios,
    stdout: std.fs.File,
    stdin: std.fs.File,
    width: u16,
    height: u16,

    pub fn init() !Terminal {
        const stdout = std.fs.File.stdout();
        const stdin = std.fs.File.stdin();

        const size = getTerminalSize();

        return Terminal{
            .original_termios = null,
            .stdout = stdout,
            .stdin = stdin,
            .width = size.width,
            .height = size.height,
        };
    }

    pub fn deinit(self: *Terminal) void {
        self.disableRawMode();
        self.showCursor();
        self.leaveAlternateScreen();
    }

    pub fn enableRawMode(self: *Terminal) !void {
        const termios = try posix.tcgetattr(self.stdin.handle);
        self.original_termios = termios;

        var raw = termios;
        raw.lflag.ECHO = false;
        raw.lflag.ICANON = false;
        raw.lflag.ISIG = false;
        raw.lflag.IEXTEN = false;
        raw.iflag.IXON = false;
        raw.iflag.ICRNL = false;
        raw.iflag.BRKINT = false;
        raw.iflag.INPCK = false;
        raw.iflag.ISTRIP = false;
        raw.oflag.OPOST = false;
        raw.cc[@intFromEnum(posix.V.MIN)] = 0;
        raw.cc[@intFromEnum(posix.V.TIME)] = 1;

        try posix.tcsetattr(self.stdin.handle, .FLUSH, raw);
    }

    pub fn disableRawMode(self: *Terminal) void {
        if (self.original_termios) |termios| {
            posix.tcsetattr(self.stdin.handle, .FLUSH, termios) catch {};
            self.original_termios = null;
        }
    }

    pub fn enterAlternateScreen(self: *Terminal) void {
        self.writeEscape("\x1b[?1049h");
    }

    pub fn leaveAlternateScreen(self: *Terminal) void {
        self.writeEscape("\x1b[?1049l");
    }

    pub fn hideCursor(self: *Terminal) void {
        self.writeEscape("\x1b[?25l");
    }

    pub fn showCursor(self: *Terminal) void {
        self.writeEscape("\x1b[?25h");
    }

    pub fn clear(self: *Terminal) void {
        self.writeEscape("\x1b[2J");
    }

    pub fn moveCursor(self: *Terminal, row: u16, col: u16) void {
        var buffer: [32]u8 = undefined;
        const seq = std.fmt.bufPrint(&buffer, "\x1b[{d};{d}H", .{ row + 1, col + 1 }) catch return;
        self.stdout.writeAll(seq) catch {};
    }

    pub fn clearLine(self: *Terminal) void {
        self.writeEscape("\x1b[2K");
    }

    pub fn resetAttributes(self: *Terminal) void {
        self.writeEscape("\x1b[0m");
    }

    pub fn setBold(self: *Terminal) void {
        self.writeEscape("\x1b[1m");
    }

    pub fn setDim(self: *Terminal) void {
        self.writeEscape("\x1b[2m");
    }

    pub fn setUnderline(self: *Terminal) void {
        self.writeEscape("\x1b[4m");
    }

    pub fn setForegroundColor(self: *Terminal, color: Color) void {
        var buffer: [16]u8 = undefined;
        const seq = std.fmt.bufPrint(&buffer, "\x1b[{d}m", .{@intFromEnum(color)}) catch return;
        self.stdout.writeAll(seq) catch {};
    }

    pub fn setBackgroundColor(self: *Terminal, color: Color) void {
        var buffer: [16]u8 = undefined;
        const seq = std.fmt.bufPrint(&buffer, "\x1b[{d}m", .{@intFromEnum(color) + 10}) catch return;
        self.stdout.writeAll(seq) catch {};
    }

    pub fn setForeground256(self: *Terminal, color: u8) void {
        var buffer: [16]u8 = undefined;
        const seq = std.fmt.bufPrint(&buffer, "\x1b[38;5;{d}m", .{color}) catch return;
        self.stdout.writeAll(seq) catch {};
    }

    pub fn setBackground256(self: *Terminal, color: u8) void {
        var buffer: [16]u8 = undefined;
        const seq = std.fmt.bufPrint(&buffer, "\x1b[48;5;{d}m", .{color}) catch return;
        self.stdout.writeAll(seq) catch {};
    }

    pub fn writeText(self: *Terminal, text: []const u8) void {
        self.stdout.writeAll(text) catch {};
    }

    pub fn readKey(self: *Terminal) !?Key {
        var buffer: [8]u8 = undefined;
        const bytes_read = self.stdin.read(&buffer) catch |err| {
            if (err == error.WouldBlock) return null;
            return err;
        };

        if (bytes_read == 0) return null;

        if (buffer[0] == '\x1b') {
            if (bytes_read == 1) return Key{ .escape = {} };
            if (bytes_read >= 3 and buffer[1] == '[') {
                return switch (buffer[2]) {
                    'A' => Key{ .arrow_up = {} },
                    'B' => Key{ .arrow_down = {} },
                    'C' => Key{ .arrow_right = {} },
                    'D' => Key{ .arrow_left = {} },
                    'H' => Key{ .home = {} },
                    'F' => Key{ .end = {} },
                    '3' => if (bytes_read >= 4 and buffer[3] == '~') Key{ .delete = {} } else null,
                    '5' => if (bytes_read >= 4 and buffer[3] == '~') Key{ .page_up = {} } else null,
                    '6' => if (bytes_read >= 4 and buffer[3] == '~') Key{ .page_down = {} } else null,
                    else => null,
                };
            }
            return null;
        }

        return switch (buffer[0]) {
            '\r', '\n' => Key{ .enter = {} },
            '\t' => Key{ .tab = {} },
            127 => Key{ .backspace = {} },
            else => Key{ .char = buffer[0] },
        };
    }

    pub fn updateSize(self: *Terminal) void {
        const size = getTerminalSize();
        self.width = size.width;
        self.height = size.height;
    }

    fn writeEscape(self: *Terminal, seq: []const u8) void {
        self.stdout.writeAll(seq) catch {};
    }

    fn getTerminalSize() struct { width: u16, height: u16 } {
        var winsize: posix.winsize = undefined;
        const result = posix.system.ioctl(posix.STDOUT_FILENO, posix.T.IOCGWINSZ, @intFromPtr(&winsize));
        if (result == 0) {
            return .{
                .width = winsize.col,
                .height = winsize.row,
            };
        }
        return .{ .width = 80, .height = 24 };
    }

    pub const Color = enum(u8) {
        black = 30,
        red = 31,
        green = 32,
        yellow = 33,
        blue = 34,
        magenta = 35,
        cyan = 36,
        white = 37,
        default = 39,
        bright_black = 90,
        bright_red = 91,
        bright_green = 92,
        bright_yellow = 93,
        bright_blue = 94,
        bright_magenta = 95,
        bright_cyan = 96,
        bright_white = 97,
    };

    pub const Key = union(enum) {
        char: u8,
        enter: void,
        tab: void,
        backspace: void,
        escape: void,
        arrow_up: void,
        arrow_down: void,
        arrow_left: void,
        arrow_right: void,
        home: void,
        end: void,
        page_up: void,
        page_down: void,
        delete: void,
    };
};

test "Terminal initialization" {
    var term = try Terminal.init();
    defer term.deinit();
    try std.testing.expect(term.width > 0);
    try std.testing.expect(term.height > 0);
}
