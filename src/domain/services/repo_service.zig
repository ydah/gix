const std = @import("std");
const Allocator = std.mem.Allocator;
const Repository = @import("../models/repository.zig").Repository;
const GitHubClient = @import("../../infrastructure/github/client.zig").GitHubClient;
const Endpoints = @import("../../infrastructure/github/endpoints.zig").Endpoints;
const Cache = @import("../../infrastructure/storage/cache.zig").Cache;

pub const RepoService = struct {
    allocator: Allocator,
    client: *GitHubClient,
    cache: ?*Cache,
    repositories: []Repository,
    capacity: usize,

    pub fn init(allocator: Allocator, client: *GitHubClient, cache: ?*Cache) RepoService {
        return RepoService{
            .allocator = allocator,
            .client = client,
            .cache = cache,
            .repositories = &.{},
            .capacity = 0,
        };
    }

    pub fn deinit(self: *RepoService) void {
        for (self.repositories) |*repo| {
            repo.deinit();
        }
        if (self.capacity > 0) {
            self.allocator.free(self.repositories.ptr[0..self.capacity]);
        }
    }

    pub fn fetchUserRepos(self: *RepoService) ![]const Repository {
        const cache_key = "user_repos";

        if (self.cache) |cache| {
            if (cache.get(cache_key)) |cached_data| {
                try self.parseRepositories(cached_data);
                return self.repositories;
            }
        }

        var response = try self.client.get(Endpoints.repos);
        defer response.deinit();

        if (response.status == 200) {
            try self.parseRepositories(response.body);

            if (self.cache) |cache| {
                cache.set(cache_key, response.body) catch {};
            }
        }

        return self.repositories;
    }

    pub fn search(self: *RepoService, query: []const u8) ![]const Repository {
        const endpoint = try Endpoints.searchRepos(self.allocator, query);
        defer self.allocator.free(endpoint);

        var response = try self.client.get(endpoint);
        defer response.deinit();

        if (response.status == 200) {
            const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, response.body, .{}) catch return self.repositories;
            defer parsed.deinit();

            if (parsed.value.object.get("items")) |items| {
                try self.parseRepositoriesFromArray(items.array.items);
            }
        }

        return self.repositories;
    }

    pub fn cloneRepo(self: *RepoService, clone_url: []const u8, dest_path: []const u8) !void {
        var child = std.process.Child.init(&.{ "git", "clone", clone_url, dest_path }, self.allocator);
        child.spawn() catch return error.CloneFailed;
        _ = child.wait() catch return error.CloneFailed;
    }

    fn parseRepositories(self: *RepoService, json_data: []const u8) !void {
        for (self.repositories) |*repo| {
            repo.deinit();
        }

        const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, json_data, .{}) catch return;
        defer parsed.deinit();

        if (parsed.value != .array) return;

        try self.parseRepositoriesFromArray(parsed.value.array.items);
    }

    fn parseRepositoriesFromArray(self: *RepoService, items: []const std.json.Value) !void {
        const count = items.len;
        if (count > self.capacity) {
            if (self.capacity > 0) {
                self.allocator.free(self.repositories.ptr[0..self.capacity]);
            }
            const new_slice = try self.allocator.alloc(Repository, count);
            self.repositories = new_slice[0..0];
            self.capacity = count;
        }

        var idx: usize = 0;
        for (items) |item| {
            const repo = Repository.parseJson(self.allocator, item) catch continue;
            self.repositories.ptr[idx] = repo;
            idx += 1;
        }
        self.repositories = self.repositories.ptr[0..idx];
    }
};

test "RepoService initialization" {
    var client = GitHubClient.initWithToken(std.testing.allocator, "test");
    defer client.deinit();

    var service = RepoService.init(std.testing.allocator, &client, null);
    defer service.deinit();

    try std.testing.expect(service.repositories.len == 0);
}
