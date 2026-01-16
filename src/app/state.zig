const std = @import("std");
const Allocator = std.mem.Allocator;

const Notification = @import("../domain/models/notification.zig").Notification;
const PullRequest = @import("../domain/models/pull_request.zig").PullRequest;
const Issue = @import("../domain/models/issue.zig").Issue;
const Repository = @import("../domain/models/repository.zig").Repository;

const NotificationService = @import("../domain/services/notification_service.zig").NotificationService;
const PRService = @import("../domain/services/pr_service.zig").PRService;
const RepoService = @import("../domain/services/repo_service.zig").RepoService;

const GitHubClient = @import("../infrastructure/github/client.zig").GitHubClient;
const Cache = @import("../infrastructure/storage/cache.zig").Cache;

pub const AppState = struct {
    allocator: Allocator,

    notification_service: NotificationService,
    pr_service: PRService,
    repo_service: RepoService,
    cache: Cache,

    notifications: []const Notification,
    pull_requests: []const PullRequest,
    issues: []const Issue,
    repositories: []const Repository,

    current_repo_owner: ?[]const u8,
    current_repo_name: ?[]const u8,

    loading: bool,
    error_message: ?[]const u8,
    last_refresh: i64,

    pub fn init(allocator: Allocator, client: *GitHubClient) AppState {
        var cache = Cache.init(allocator, 100 * 1024 * 1024, 300);

        return AppState{
            .allocator = allocator,
            .notification_service = NotificationService.init(allocator, client, &cache),
            .pr_service = PRService.init(allocator, client, &cache),
            .repo_service = RepoService.init(allocator, client, &cache),
            .cache = cache,
            .notifications = &.{},
            .pull_requests = &.{},
            .issues = &.{},
            .repositories = &.{},
            .current_repo_owner = null,
            .current_repo_name = null,
            .loading = false,
            .error_message = null,
            .last_refresh = 0,
        };
    }

    pub fn deinit(self: *AppState) void {
        self.notification_service.deinit();
        self.pr_service.deinit();
        self.repo_service.deinit();
        self.cache.deinit();
    }

    pub fn refreshNotifications(self: *AppState) void {
        self.loading = true;
        self.error_message = null;

        self.notifications = self.notification_service.fetch() catch |err| {
            self.error_message = @errorName(err);
            self.loading = false;
            return;
        };

        self.loading = false;
        self.last_refresh = std.time.timestamp();
    }

    pub fn refreshRepositories(self: *AppState) void {
        self.loading = true;
        self.error_message = null;

        self.repositories = self.repo_service.fetchUserRepos() catch |err| {
            self.error_message = @errorName(err);
            self.loading = false;
            return;
        };

        self.loading = false;
        self.last_refresh = std.time.timestamp();
    }

    pub fn selectRepository(self: *AppState, owner: []const u8, name: []const u8) void {
        self.current_repo_owner = owner;
        self.current_repo_name = name;
    }

    pub fn refreshPullRequests(self: *AppState) void {
        if (self.current_repo_owner == null or self.current_repo_name == null) {
            return;
        }

        self.loading = true;
        self.error_message = null;

        self.pull_requests = self.pr_service.fetchPullRequests(
            self.current_repo_owner.?,
            self.current_repo_name.?,
        ) catch |err| {
            self.error_message = @errorName(err);
            self.loading = false;
            return;
        };

        self.loading = false;
    }

    pub fn refreshIssues(self: *AppState) void {
        if (self.current_repo_owner == null or self.current_repo_name == null) {
            return;
        }

        self.loading = true;
        self.error_message = null;

        self.issues = self.pr_service.fetchIssues(
            self.current_repo_owner.?,
            self.current_repo_name.?,
        ) catch |err| {
            self.error_message = @errorName(err);
            self.loading = false;
            return;
        };

        self.loading = false;
    }

    pub fn refreshAll(self: *AppState) void {
        self.refreshNotifications();
        self.refreshRepositories();
        if (self.current_repo_owner != null) {
            self.refreshPullRequests();
            self.refreshIssues();
        }
    }

    pub fn getUnreadNotificationCount(self: *const AppState) usize {
        var count: usize = 0;
        for (self.notifications) |n| {
            if (n.unread) count += 1;
        }
        return count;
    }

    pub fn getOpenPRCount(self: *const AppState) usize {
        var count: usize = 0;
        for (self.pull_requests) |pr| {
            if (pr.state == .open) count += 1;
        }
        return count;
    }

    pub fn getOpenIssueCount(self: *const AppState) usize {
        var count: usize = 0;
        for (self.issues) |issue| {
            if (issue.state == .open) count += 1;
        }
        return count;
    }
};
