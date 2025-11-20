const std = @import("std");
const libphonenumber = @import("../src/libphonenumber.zig");

// Fuzzing harness for phone number validation
// This tests the core validation logic with random inputs

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const validator = libphonenumber.PhoneValidator.init();

    // Read fuzzing input from stdin (AFL/LibFuzzer compatible)
    const stdin = std.io.getStdIn().reader();
    const input = try stdin.readAllAlloc(allocator, 10 * 1024); // Max 10KB
    defer allocator.free(input);

    // If input is empty, exit
    if (input.len == 0) return;

    // Split input into phone number and optional region
    var parts = std.mem.splitScalar(u8, input, '|');
    const phone_number = parts.next() orelse return;
    const region = parts.next();

    // Try to parse and validate
    const parsed = validator.parse(allocator, phone_number, region) catch {
        // Parse failure is expected for fuzzing - not a bug
        return;
    };
    defer parsed.deinit();

    // Exercise all methods to find crashes
    _ = parsed.isValid();
    _ = parsed.isPossible();
    _ = parsed.isPossibleWithReason();
    _ = parsed.getType();
    _ = parsed.getCountryCode();
    _ = parsed.getNationalNumber();

    // Try formatting in all formats
    _ = parsed.format(allocator, .E164) catch return;
    _ = parsed.format(allocator, .INTERNATIONAL) catch return;
    _ = parsed.format(allocator, .NATIONAL) catch return;
    _ = parsed.format(allocator, .RFC3966) catch return;

    // Get region
    _ = parsed.getRegion(allocator) catch return;
}
