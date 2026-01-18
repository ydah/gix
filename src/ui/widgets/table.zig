const std = @import("std");
const Terminal = @import("../../utils/terminal.zig").Terminal;
const Theme = @import("../theme.zig").Theme;

pub const Column = struct {
    header: []const u8,
    width: u16,
    alignment: Alignment = .left,

    pub const Alignment = enum {
        left,
        center,
        right,
    };
};

pub fn Table(comptime T: type, comptime num_columns: usize) type {
    return struct {
        const Self = @This();

        items: []const T,
        columns: [num_columns]Column,
        selected_index: usize,
        scroll_offset: usize,
        visible_height: u16,
        render_cell: *const fn (item: T, col_index: usize, buffer: []u8) []const u8,
        show_header: bool,

        pub fn init(
            items: []const T,
            columns: [num_columns]Column,
            visible_height: u16,
            render_cell: *const fn (item: T, col_index: usize, buffer: []u8) []const u8,
        ) Self {
            return Self{
                .items = items,
                .columns = columns,
                .selected_index = 0,
                .scroll_offset = 0,
                .visible_height = visible_height,
                .render_cell = render_cell,
                .show_header = true,
            };
        }

        pub fn setItems(self: *Self, items: []const T) void {
            self.items = items;
            if (self.selected_index >= items.len and items.len > 0) {
                self.selected_index = items.len - 1;
            }
            self.adjustScroll();
        }

        pub fn moveUp(self: *Self) void {
            if (self.selected_index > 0) {
                self.selected_index -= 1;
                self.adjustScroll();
            }
        }

        pub fn moveDown(self: *Self) void {
            if (self.selected_index < self.items.len -| 1) {
                self.selected_index += 1;
                self.adjustScroll();
            }
        }

        pub fn getSelected(self: *const Self) ?T {
            if (self.items.len == 0) return null;
            return self.items[self.selected_index];
        }

        fn adjustScroll(self: *Self) void {
            if (self.selected_index < self.scroll_offset) {
                self.scroll_offset = self.selected_index;
            }
            const visible = @as(usize, self.visible_height);
            if (self.selected_index >= self.scroll_offset + visible) {
                self.scroll_offset = self.selected_index - visible + 1;
            }
        }

        fn getTotalWidth(self: *const Self) u16 {
            var total: u16 = 0;
            for (self.columns) |col| {
                total += col.width + 1;
            }
            return total;
        }

        pub fn render(self: *const Self, terminal: *Terminal, theme: *const Theme, start_row: u16, start_col: u16) void {
            var current_row = start_row;

            if (self.show_header) {
                self.renderHeader(terminal, theme, current_row, start_col);
                current_row += 1;
                self.renderSeparator(terminal, theme, current_row, start_col);
                current_row += 1;
            }

            self.renderRows(terminal, theme, current_row, start_col);
        }

        fn renderHeader(self: *const Self, terminal: *Terminal, theme: *const Theme, row: u16, start_col: u16) void {
            var col_offset: u16 = start_col;
            terminal.moveCursor(row, start_col);
            terminal.setForeground256(theme.colors.primary);
            terminal.setBold(true);

            for (self.columns) |column| {
                terminal.moveCursor(row, col_offset);
                const text = alignText(column.header, column.width, column.alignment);
                terminal.writeText(text);
                col_offset += column.width + 1;
            }

            terminal.resetAttributes();
        }

        fn renderSeparator(self: *const Self, terminal: *Terminal, theme: *const Theme, row: u16, start_col: u16) void {
            terminal.moveCursor(row, start_col);
            terminal.setForeground256(theme.colors.border);

            const total_width = self.getTotalWidth();
            var i: u16 = 0;
            while (i < total_width) : (i += 1) {
                terminal.writeText("─");
            }

            terminal.resetAttributes();
        }

        fn renderRows(self: *const Self, terminal: *Terminal, theme: *const Theme, start_row: u16, start_col: u16) void {
            var row: u16 = 0;
            const max_rows = @min(self.visible_height, @as(u16, @intCast(self.items.len -| self.scroll_offset)));

            while (row < max_rows) : (row += 1) {
                const item_index = self.scroll_offset + row;
                if (item_index >= self.items.len) break;

                const item = self.items[item_index];
                const is_selected = item_index == self.selected_index;

                if (is_selected) {
                    terminal.setBackground256(theme.colors.selection);
                }

                var col_offset: u16 = start_col;
                for (self.columns, 0..) |column, col_idx| {
                    terminal.moveCursor(start_row + row, col_offset);

                    var buffer: [256]u8 = undefined;
                    const cell_text = self.render_cell(item, col_idx, &buffer);
                    const aligned = alignText(cell_text, column.width, column.alignment);

                    terminal.setForeground256(theme.colors.foreground);
                    terminal.writeText(aligned);

                    col_offset += column.width + 1;
                }

                terminal.resetAttributes();
            }
        }

        fn alignText(text: []const u8, width: u16, alignment: Column.Alignment) []const u8 {
            _ = alignment;
            const max_len = @as(usize, width);
            if (text.len > max_len) {
                return text[0..max_len];
            }
            return text;
        }
    };
}

test "Table init" {
    const Item = struct { name: []const u8, value: u32 };
    const items = [_]Item{
        .{ .name = "test", .value = 42 },
    };

    const columns = [2]Column{
        .{ .header = "Name", .width = 20 },
        .{ .header = "Value", .width = 10, .alignment = .right },
    };

    const render_fn = struct {
        fn render(item: Item, col_idx: usize, buffer: []u8) []const u8 {
            return switch (col_idx) {
                0 => item.name,
                1 => std.fmt.bufPrint(buffer, "{d}", .{item.value}) catch "?",
                else => "",
            };
        }
    }.render;

    const table = Table(Item, 2).init(&items, columns, 10, render_fn);
    try std.testing.expect(table.selected_index == 0);
}
