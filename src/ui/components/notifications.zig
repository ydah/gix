const std = @import("std");
const Terminal = @import("../../utils/terminal.zig").Terminal;
const Theme = @import("../theme.zig").Theme;
const Notification = @import("../../domain/models/notification.zig").Notification;

pub const NotificationsView = struct {
    notifications: []const Notification,
    selected_index: usize,
    scroll_offset: usize,
    visible_height: u16,
    loading: bool,
    error_message: ?[]const u8,

    pub fn init() NotificationsView {
        return NotificationsView{
            .notifications = &.{},
            .selected_index = 0,
            .scroll_offset = 0,
            .visible_height = 20,
            .loading = false,
            .error_message = null,
        };
    }

    pub fn setNotifications(self: *NotificationsView, notifications: []const Notification) void {
        self.notifications = notifications;
        if (self.selected_index >= notifications.len and notifications.len > 0) {
            self.selected_index = notifications.len - 1;
        }
        self.loading = false;
        self.error_message = null;
    }

    pub fn setLoading(self: *NotificationsView, loading: bool) void {
        self.loading = loading;
    }

    pub fn setError(self: *NotificationsView, message: []const u8) void {
        self.error_message = message;
        self.loading = false;
    }

    pub fn moveUp(self: *NotificationsView) void {
        if (self.selected_index > 0) {
            self.selected_index -= 1;
            self.adjustScroll();
        }
    }

    pub fn moveDown(self: *NotificationsView) void {
        if (self.notifications.len > 0 and self.selected_index < self.notifications.len - 1) {
            self.selected_index += 1;
            self.adjustScroll();
        }
    }

    pub fn getSelected(self: *const NotificationsView) ?Notification {
        if (self.notifications.len == 0) return null;
        return self.notifications[self.selected_index];
    }

    fn adjustScroll(self: *NotificationsView) void {
        if (self.selected_index < self.scroll_offset) {
            self.scroll_offset = self.selected_index;
        }
        const visible = @as(usize, self.visible_height);
        if (self.selected_index >= self.scroll_offset + visible) {
            self.scroll_offset = self.selected_index - visible + 1;
        }
    }

    pub fn render(self: *const NotificationsView, terminal: *Terminal, theme: *const Theme, start_row: u16, width: u16, height: u16) void {
        const visible_height = height -| 4;

        terminal.moveCursor(start_row, 2);
        terminal.setForeground256(theme.colors.primary);
        terminal.setBold();
        terminal.writeText("📬 Notifications");
        terminal.resetAttributes();

        if (self.loading) {
            terminal.moveCursor(start_row + 2, 4);
            terminal.setForeground256(theme.colors.muted);
            terminal.writeText("Loading notifications...");
            terminal.resetAttributes();
            return;
        }

        if (self.error_message) |msg| {
            terminal.moveCursor(start_row + 2, 4);
            terminal.setForeground256(theme.colors.error_color);
            terminal.writeText("Error: ");
            terminal.writeText(msg);
            terminal.resetAttributes();
            return;
        }

        if (self.notifications.len == 0) {
            terminal.moveCursor(start_row + 2, 4);
            terminal.setForeground256(theme.colors.muted);
            terminal.writeText("No notifications");
            terminal.resetAttributes();
            return;
        }

        terminal.moveCursor(start_row + 1, 2);
        terminal.setForeground256(theme.colors.muted);
        var count_buf: [64]u8 = undefined;
        const count_text = std.fmt.bufPrint(&count_buf, "{d} notifications", .{self.notifications.len}) catch "? notifications";
        terminal.writeText(count_text);
        terminal.resetAttributes();

        var row: u16 = 0;
        const max_rows = @min(visible_height, @as(u16, @intCast(self.notifications.len -| self.scroll_offset)));

        while (row < max_rows) : (row += 1) {
            const item_index = self.scroll_offset + row;
            if (item_index >= self.notifications.len) break;

            const notif = self.notifications[item_index];
            const is_selected = item_index == self.selected_index;

            terminal.moveCursor(start_row + 3 + row, 2);

            if (is_selected) {
                terminal.setBackground256(theme.colors.selection);
            }

            if (notif.unread) {
                terminal.setForeground256(theme.colors.accent);
                terminal.writeText("● ");
            } else {
                terminal.setForeground256(theme.colors.muted);
                terminal.writeText("○ ");
            }

            terminal.setForeground256(theme.colors.secondary);
            terminal.writeText("[");
            terminal.writeText(notif.subject.type_.toString());
            terminal.writeText("] ");

            if (is_selected) {
                terminal.setForeground256(theme.colors.primary);
            } else {
                terminal.setForeground256(theme.colors.foreground);
            }

            const max_title_len = @as(usize, width -| 30);
            const title = if (notif.subject.title.len > max_title_len)
                notif.subject.title[0..max_title_len]
            else
                notif.subject.title;
            terminal.writeText(title);

            terminal.setForeground256(theme.colors.muted);
            terminal.writeText(" - ");
            const max_repo_len: usize = 20;
            const repo = if (notif.repository.full_name.len > max_repo_len)
                notif.repository.full_name[0..max_repo_len]
            else
                notif.repository.full_name;
            terminal.writeText(repo);

            terminal.resetAttributes();
        }
    }
};
