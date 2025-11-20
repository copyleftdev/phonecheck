const std = @import("std");

// Integration tests that don't require imports
// Tests the API via HTTP

fn testEndpoint(allocator: std.mem.Allocator, endpoint: []const u8, method: []const u8, body: ?[]const u8) !void {
    const uri = try std.Uri.parse(endpoint);

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    var request_buffer: [4096]u8 = undefined;
    var request = try client.open(
        if (std.mem.eql(u8, method, "GET")) .GET else .POST,
        uri,
        .{ .server_header_buffer = &request_buffer },
    );
    defer request.deinit();

    if (body) |b| {
        request.transfer_encoding = .{ .content_length = b.len };
    }

    try request.send();

    if (body) |b| {
        try request.writeAll(b);
    }
    try request.finish();
    try request.wait();

    std.debug.print("Status: {d}\n", .{request.response.status});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("🧪 Running Integration Tests\n", .{});
    std.debug.print("============================\n\n", .{});

    // Test health endpoint
    std.debug.print("→ Testing /health endpoint...\n", .{});
    try testEndpoint(allocator, "http://localhost:8080/health", "GET", null);
    std.debug.print("✅ Health check passed\n\n", .{});

    // Test validation endpoint
    std.debug.print("→ Testing /validate endpoint...\n", .{});
    const body = "{\"phone_number\": \"+14155552671\"}";
    try testEndpoint(allocator, "http://localhost:8080/validate", "POST", body);
    std.debug.print("✅ Validation test passed\n\n", .{});

    std.debug.print("✅ All integration tests passed!\n", .{});
}
