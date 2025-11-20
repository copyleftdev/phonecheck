const std = @import("std");
const libphonenumber = @import("libphonenumber");

// Property-based tests for phone validation
// These test invariants that should always hold

test "valid E.164 numbers should parse" {
    const allocator = std.testing.allocator;
    const validator = libphonenumber.PhoneValidator.init();

    // Property: All E.164 format numbers should parse
    const e164_numbers = [_][]const u8{
        "+14155552671",
        "+442071838750",
        "+81312345678",
        "+919876543210",
        "+61291234567",
        "+5511987654321",
        "+4930123456",
        "+33123456789",
        "+86123456789",
    };

    for (e164_numbers) |number| {
        const parsed = try validator.parse(allocator, number, null);
        defer parsed.deinit();

        // Property: Valid numbers should be possible
        try std.testing.expect(parsed.isPossible());
    }
}

test "parsed numbers should format consistently" {
    const allocator = std.testing.allocator;
    const validator = libphonenumber.PhoneValidator.init();

    const number = "+14155552671";
    const parsed = try validator.parse(allocator, number, null);
    defer parsed.deinit();

    // Property: E.164 format should be stable
    const e164 = try parsed.format(allocator, .E164);
    defer allocator.free(e164);

    try std.testing.expectEqualStrings(number, e164);

    // Property: Re-parsing formatted number should give same result
    const reparsed = try validator.parse(allocator, e164, null);
    defer reparsed.deinit();

    try std.testing.expectEqual(parsed.getCountryCode(), reparsed.getCountryCode());
    try std.testing.expectEqual(parsed.getNationalNumber(), reparsed.getNationalNumber());
}

test "country codes should be positive" {
    const allocator = std.testing.allocator;
    const validator = libphonenumber.PhoneValidator.init();

    const numbers = [_][]const u8{
        "+14155552671",
        "+442071838750",
        "+81312345678",
    };

    for (numbers) |number| {
        const parsed = try validator.parse(allocator, number, null);
        defer parsed.deinit();

        // Property: Country codes are always positive
        const code = parsed.getCountryCode();
        try std.testing.expect(code > 0);
        try std.testing.expect(code < 1000); // Max country code is 3 digits
    }
}

test "national numbers should be positive" {
    const allocator = std.testing.allocator;
    const validator = libphonenumber.PhoneValidator.init();

    const numbers = [_][]const u8{
        "+14155552671",
        "+442071838750",
    };

    for (numbers) |number| {
        const parsed = try validator.parse(allocator, number, null);
        defer parsed.deinit();

        // Property: National numbers are positive
        try std.testing.expect(parsed.getNationalNumber() > 0);
    }
}

test "valid numbers should have valid regions" {
    const allocator = std.testing.allocator;
    const validator = libphonenumber.PhoneValidator.init();

    const test_cases = [_]struct {
        number: []const u8,
        expected_region: []const u8,
    }{
        .{ .number = "+14155552671", .expected_region = "US" },
        .{ .number = "+442071838750", .expected_region = "GB" },
        .{ .number = "+81312345678", .expected_region = "JP" },
        .{ .number = "+919876543210", .expected_region = "IN" },
    };

    for (test_cases) |tc| {
        const parsed = try validator.parse(allocator, tc.number, null);
        defer parsed.deinit();

        const region = try parsed.getRegion(allocator);
        defer allocator.free(region);

        // Property: Valid numbers have correct region codes
        try std.testing.expectEqualStrings(tc.expected_region, region);
    }
}

test "formatted outputs should be non-empty" {
    const allocator = std.testing.allocator;
    const validator = libphonenumber.PhoneValidator.init();

    const number = "+14155552671";
    const parsed = try validator.parse(allocator, number, null);
    defer parsed.deinit();

    // Property: All format types should produce non-empty strings
    const formats = [_]libphonenumber.PhoneNumberFormat{
        .E164,
        .INTERNATIONAL,
        .NATIONAL,
        .RFC3966,
    };

    for (formats) |fmt| {
        const formatted = try parsed.format(allocator, fmt);
        defer allocator.free(formatted);

        // Property: Formatted output is never empty
        try std.testing.expect(formatted.len > 0);
    }
}

test "memory safety - no leaks on parse failure" {
    const allocator = std.testing.allocator;
    const validator = libphonenumber.PhoneValidator.init();

    const invalid_numbers = [_][]const u8{
        "",
        "invalid",
        "+++",
        "12345", // Too short
    };

    // Property: Parse failures shouldn't leak memory
    for (invalid_numbers) |number| {
        _ = validator.parse(allocator, number, null) catch continue;
    }

    // If we reach here without leaks, test passes
}

test "parsing with region hint" {
    const allocator = std.testing.allocator;
    const validator = libphonenumber.PhoneValidator.init();

    // Property: Local format should parse with region hint
    const parsed = try validator.parse(allocator, "4155552671", "US");
    defer parsed.deinit();

    try std.testing.expectEqual(@as(u32, 1), parsed.getCountryCode());
}

test "type detection consistency" {
    const allocator = std.testing.allocator;
    const validator = libphonenumber.PhoneValidator.init();

    const number = "+14155552671";
    const parsed = try validator.parse(allocator, number, null);
    defer parsed.deinit();

    // Property: Type should be one of the known types
    const phone_type = parsed.getType();

    // Valid types are within our enum range
    const valid = switch (phone_type) {
        .FIXED_LINE,
        .MOBILE,
        .FIXED_LINE_OR_MOBILE,
        .TOLL_FREE,
        .PREMIUM_RATE,
        .SHARED_COST,
        .VOIP,
        .PERSONAL_NUMBER,
        .PAGER,
        .UAN,
        .VOICEMAIL,
        .UNKNOWN,
        => true,
    };

    try std.testing.expect(valid);
}
