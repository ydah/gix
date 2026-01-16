const std = @import("std");
const Terminal = @import("../../utils/terminal.zig").Terminal;
const Theme = @import("../theme.zig").Theme;

pub fn List(comptime T: type) type {
    return struct {
        const Self = @This();

        items: []const T,
        selected_index: usize,
        scroll_offset: usize,
        visible_height: u16,
        render_item: *const fn (item: T, buffer: []u8) []const u8,

        pub fn init(
            items: []const T,
            visible_height: u16,
            render_item: *const fn (item: T, buffer: []u8) []const u8,
        ) Self {
            return Self{
                .items = items,
                .selected_index = 0,
                .scroll_offset = 0,
                .visible_height = visible_height,
                .render_item = render_item,
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

        pub fn pageUp(self: *Self) void {
            const page = @as(usize, self.visible_height);
            if (self.selected_index > page) {
                self.selected_index -= page;
            } else {
                self.selected_index = 0;
            }
            self.adjustScroll();
        }

        pub fn pageDown(self: *Self) void {
            const page = @as(usize, self.visible_height);
            if (self.selected_index + page < self.items.len) {
                self.selected_index += page;
            } else if (self.items.len > 0) {
                self.selected_index = self.items.len - 1;
            }
            self.adjustScroll();
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

        pub fn render(self: *const Self, terminal: *Terminal, theme: *const Theme, start_row: u16, start_col: u16, width: u16) void {
            var row: u16 = 0;
            const max_rows = @min(self.visible_height, @as(u16, @intCast(self.items.len -| self.scroll_offset)));

            while (row < max_rows) : (row += 1) {
                const item_index = self.scroll_offset + row;
                if (item_index >= self.items.len) break;

                const item = self.items[item_index];
                const is_selected = item_index == self.selected_index;

                terminal.moveCursor(start_row + row, start_col);

                if (is_selected) {
                    terminal.setBackground256(theme.colors.selection);
                    terminal.setForeground256(theme.colors.primary);
                    terminal.writeText("▶ ");
                } else {
                    terminal.setForeground256(theme.colors.foreground);
                    terminal.writeText("  ");
                }

                var buffer: [512]u8 = undefined;
                const text = self.render_item(item, &buffer);

                const max_text_len = @as(usize, width -| 4);
                const display_text = if (text.len > max_text_len) text[0..max_text_len] else text;
                terminal.writeText(display_text);

                var padding = width -| @as(u16, @intCast(display_text.len + 2));
                while (padding > 0) : (padding -= 1) {
                    terminal.writeText(" ");
                }

                terminal.resetAttributes();
            }
        }
    };
}

test "List navigation" {
    const items = [_]u32{ 1, 2, 3, 4, 5 };
    const render_fn = struct {
        fn render(item: u32, buffer: []u8) []const u8 {
            return std.fmt.bufPrint(buffer, "{d}", .{item}) catch "?";
        }
    }.render;

    var list = List(u32).init(&items, 3, render_fn);

    try std.testing.expect(list.selected_index == 0);

    list.moveDown();
    try std.testing.expect(list.selected_index == 1);

    list.moveUp();
    try std.testing.expect(list.selected_index == 0);
}
