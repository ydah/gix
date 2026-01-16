const std = @import("std");
const Allocator = std.mem.Allocator;
const Config = @import("config.zig").Config;
const AppState = @import("state.zig").AppState;
const TUI = @import("../ui/tui.zig").TUI;
const GitHubClient = @import("../infrastructure/github/client.zig").GitHubClient;

pub const App = struct {
    allocator: Allocator,
    config: Config,
    tui: TUI,
    github_client: GitHubClient,
    state: AppState,
    last_refresh_time: i64,
    refresh_interval: i64,

    pub fn init(allocator: Allocator) !App {
        const config_path = try Config.getDefaultPath(allocator);
        defer allocator.free(config_path);

        var config = try Config.load(allocator, config_path);

        var github_client = GitHubClient.init(allocator) catch |err| {
            config.deinit();
            return err;
        };

        var state = AppState.init(allocator, &github_client);

        const tui = TUI.init(allocator, config.ui.theme) catch |err| {
            state.deinit();
            github_client.deinit();
            config.deinit();
            return err;
        };

        return App{
            .allocator = allocator,
            .config = config,
            .tui = tui,
            .github_client = github_client,
            .state = state,
            .last_refresh_time = 0,
            .refresh_interval = 60,
        };
    }

    pub fn deinit(self: *App) void {
        self.state.deinit();
        self.tui.deinit();
        self.github_client.deinit();
        self.config.deinit();
    }

    pub fn run(self: *App) !void {
        try self.tui.start();
        defer self.tui.stop();

        self.initialLoad();

        while (self.tui.isRunning()) {
            self.syncStateToUI();
            self.tui.render();

            const input = try self.tui.handleInput();

            if (input.should_quit) {
                break;
            }

            if (input.should_refresh) {
                self.refresh();
            }

            if (input.selected_repo) |repo| {
                self.state.selectRepository(repo.owner, repo.name);
                self.state.refreshPullRequests();
                self.state.refreshIssues();
            }

            self.checkAutoRefresh();

            std.Thread.sleep(16 * std.time.ns_per_ms);
        }
    }

    fn initialLoad(self: *App) void {
        self.tui.setLoading(true);
        self.tui.setStatusMessage("Loading data...");

        self.state.refreshNotifications();
        self.state.refreshRepositories();

        self.tui.setLoading(false);
        self.tui.setStatusMessage(null);
        self.last_refresh_time = std.time.timestamp();
    }

    fn refresh(self: *App) void {
        self.tui.setLoading(true);
        self.tui.setStatusMessage("Refreshing...");

        switch (self.tui.current_view) {
            .dashboard => self.state.refreshAll(),
            .notifications => self.state.refreshNotifications(),
            .pull_requests => self.state.refreshPullRequests(),
            .issues => self.state.refreshIssues(),
            .repositories => self.state.refreshRepositories(),
        }

        self.tui.setLoading(false);
        self.tui.setStatusMessage(null);
        self.last_refresh_time = std.time.timestamp();
    }

    fn checkAutoRefresh(self: *App) void {
        const now = std.time.timestamp();
        if (now - self.last_refresh_time > self.refresh_interval) {
            self.state.refreshNotifications();
            self.last_refresh_time = now;
        }
    }

    fn syncStateToUI(self: *App) void {
        self.tui.setNotifications(self.state.notifications);
        self.tui.setPullRequests(self.state.pull_requests);
        self.tui.setIssues(self.state.issues);
        self.tui.setRepositories(self.state.repositories);

        self.tui.updateDashboard(
            self.state.getUnreadNotificationCount(),
            self.state.getOpenPRCount(),
            self.state.getOpenIssueCount(),
            self.state.repositories.len,
        );

        if (self.state.error_message) |err| {
            var buf: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&buf, "Error: {s}", .{err}) catch "Error occurred";
            self.tui.setStatusMessage(msg);
        }
    }
};

test "App configuration" {
    const config = Config.init(std.testing.allocator);
    try std.testing.expectEqualStrings("dark", config.ui.theme);
}
