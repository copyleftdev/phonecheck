const std = @import("std");

// Fuzzing harness for HTTP request parsing
// Tests for crashes in HTTP parsing logic

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdin = std.io.getStdIn().reader();
    const input = try stdin.readAllAlloc(allocator, 64 * 1024); // Max 64KB
    defer allocator.free(input);

    if (input.len == 0) return;

    // Parse HTTP request line
    var lines = std.mem.splitScalar(u8, input, '\n');
    const request_line = lines.next() orelse return;

    var parts = std.mem.splitScalar(u8, request_line, ' ');
    _ = parts.next() orelse return; // method
    const path = parts.next() orelse return;

    // Trim path and check for buffer overflows
    _ = std.mem.trim(u8, path, &std.ascii.whitespace);

    // Find body
    const body_marker = "\r\n\r\n";
    if (std.mem.indexOf(u8, input, body_marker)) |pos| {
        const body = input[pos + 4 ..];

        // Try to parse as JSON
        const parsed = std.json.parseFromSlice(
            struct {
                phone_number: ?[]const u8 = null,
                region: ?[]const u8 = null,
            },
            allocator,
            body,
            .{ .ignore_unknown_fields = true },
        ) catch return; // Parse errors are expected
        defer parsed.deinit();
    }
}
