const std = @import("std");

// Fuzzing harness for JSON output formatting
// Tests for crashes in response generation

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdin = std.io.getStdIn().reader();
    const input = try stdin.readAllAlloc(allocator, 10 * 1024);
    defer allocator.free(input);

    if (input.len < 10) return;

    // Parse fuzzing input as mock validation result fields
    var parts = std.mem.splitScalar(u8, input, '|');

    const type_str = parts.next() orelse return;
    const region = parts.next() orelse return;
    const e164 = parts.next() orelse return;
    const intl = parts.next() orelse return;
    const national = parts.next() orelse return;

    // Format JSON response manually (as we do in the API)
    var response_buffer: std.ArrayListUnmanaged(u8) = .{};
    defer response_buffer.deinit(allocator);

    const writer = response_buffer.writer(allocator);

    // Test for format string vulnerabilities and buffer overflows
    writer.print(
        "{{\"valid\":{},\"possible\":{},\"type\":\"{s}\",\"country_code\":{d},\"national_number\":{d},\"region\":\"{s}\",\"e164_format\":\"{s}\",\"international_format\":\"{s}\",\"national_format\":\"{s}\",\"possibility_reason\":\"{s}\"}}",
        .{
            true,
            true,
            type_str,
            @as(u32, 1),
            @as(u64, 1234567890),
            region,
            e164,
            intl,
            national,
            "IS_POSSIBLE",
        },
    ) catch return;

    // Ensure output is valid JSON-ish (no crashes)
    _ = response_buffer.items;
}
