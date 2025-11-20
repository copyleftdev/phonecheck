const std = @import("std");

pub const PhoneNumberUtil = opaque {};
pub const PhoneNumber = opaque {};

pub const PhoneNumberType = enum(c_int) {
    FIXED_LINE = 0,
    MOBILE = 1,
    FIXED_LINE_OR_MOBILE = 2,
    TOLL_FREE = 3,
    PREMIUM_RATE = 4,
    SHARED_COST = 5,
    VOIP = 6,
    PERSONAL_NUMBER = 7,
    PAGER = 8,
    UAN = 9,
    VOICEMAIL = 10,
    UNKNOWN = -1,
};

pub const ValidationResult = enum(c_int) {
    IS_POSSIBLE = 0,
    INVALID_COUNTRY_CODE = 1,
    TOO_SHORT = 2,
    TOO_LONG = 3,
    IS_POSSIBLE_LOCAL_ONLY = 4,
    INVALID_LENGTH = 5,
};

pub const MatchType = enum(c_int) {
    NOT_A_NUMBER = 0,
    NO_MATCH = 1,
    SHORT_NSN_MATCH = 2,
    NSN_MATCH = 3,
    EXACT_MATCH = 4,
};

pub const ErrorType = enum(c_int) {
    NO_ERROR = 0,
    INVALID_COUNTRY_CODE_ERROR = 1,
    NOT_A_NUMBER = 2,
    TOO_SHORT_NSN = 3,
    TOO_SHORT_AFTER_IDD = 4,
    TOO_LONG = 5,
};

pub const PhoneNumberFormat = enum(c_int) {
    E164 = 0,
    INTERNATIONAL = 1,
    NATIONAL = 2,
    RFC3966 = 3,
};

extern "c" fn phoneutil_get_instance() *PhoneNumberUtil;
extern "c" fn phoneutil_parse(
    util: *PhoneNumberUtil,
    number_to_parse: [*:0]const u8,
    default_region: [*:0]const u8,
    phone_number: *?*PhoneNumber,
    error_type: *ErrorType,
) bool;

extern "c" fn phoneutil_is_valid_number(
    util: *PhoneNumberUtil,
    number: *PhoneNumber,
) bool;

extern "c" fn phoneutil_is_possible_number(
    util: *PhoneNumberUtil,
    number: *PhoneNumber,
) bool;

extern "c" fn phoneutil_is_possible_number_with_reason(
    util: *PhoneNumberUtil,
    number: *PhoneNumber,
) ValidationResult;

extern "c" fn phoneutil_get_number_type(
    util: *PhoneNumberUtil,
    number: *PhoneNumber,
) PhoneNumberType;

extern "c" fn phoneutil_format_number(
    util: *PhoneNumberUtil,
    number: *PhoneNumber,
    format: PhoneNumberFormat,
    formatted: *[*]u8,
    formatted_len: *usize,
) void;

extern "c" fn phoneutil_get_region_code(
    util: *PhoneNumberUtil,
    number: *PhoneNumber,
    region: *[*]u8,
    region_len: *usize,
) void;

extern "c" fn phoneutil_get_country_code(
    number: *PhoneNumber,
) c_int;

extern "c" fn phoneutil_get_national_number(
    number: *PhoneNumber,
) u64;

extern "c" fn phoneutil_is_number_match(
    util: *PhoneNumberUtil,
    number1: *PhoneNumber,
    number2: *PhoneNumber,
) MatchType;

extern "c" fn phoneutil_free_number(number: *PhoneNumber) void;
extern "c" fn phoneutil_free_string(str: [*]u8) void;

/// High-level Zig wrapper for phone number operations
pub const PhoneValidator = struct {
    util: *PhoneNumberUtil,

    pub fn init() PhoneValidator {
        return .{
            .util = phoneutil_get_instance(),
        };
    }

    /// Parse a phone number string with optional default region
    pub fn parse(
        self: PhoneValidator,
        allocator: std.mem.Allocator,
        number_str: []const u8,
        default_region: ?[]const u8,
    ) !ParsedNumber {
        // Ensure null termination
        const number_z = try allocator.dupeZ(u8, number_str);
        defer allocator.free(number_z);

        const region_z = if (default_region) |r|
            try allocator.dupeZ(u8, r)
        else
            try allocator.dupeZ(u8, "ZZ"); // Unknown region
        defer allocator.free(region_z);

        var phone_number: ?*PhoneNumber = null;
        var error_type: ErrorType = .NO_ERROR;

        const success = phoneutil_parse(
            self.util,
            number_z.ptr,
            region_z.ptr,
            &phone_number,
            &error_type,
        );

        if (!success or phone_number == null) {
            return error.ParseFailed;
        }

        return ParsedNumber{
            .number = phone_number.?,
            .validator = self,
        };
    }

    /// Check if two numbers match
    pub fn isNumberMatch(
        self: PhoneValidator,
        number1: *PhoneNumber,
        number2: *PhoneNumber,
    ) MatchType {
        return phoneutil_is_number_match(self.util, number1, number2);
    }
};

/// Represents a successfully parsed phone number
pub const ParsedNumber = struct {
    number: *PhoneNumber,
    validator: PhoneValidator,

    /// Check if the number is valid for its region
    pub fn isValid(self: ParsedNumber) bool {
        return phoneutil_is_valid_number(self.validator.util, self.number);
    }

    /// Check if the number is possible (correct length, etc)
    pub fn isPossible(self: ParsedNumber) bool {
        return phoneutil_is_possible_number(self.validator.util, self.number);
    }

    /// Get detailed possibility check result
    pub fn isPossibleWithReason(self: ParsedNumber) ValidationResult {
        return phoneutil_is_possible_number_with_reason(
            self.validator.util,
            self.number,
        );
    }

    /// Get the type of phone number
    pub fn getType(self: ParsedNumber) PhoneNumberType {
        return phoneutil_get_number_type(self.validator.util, self.number);
    }

    /// Format the number in specified format
    pub fn format(
        self: ParsedNumber,
        allocator: std.mem.Allocator,
        fmt: PhoneNumberFormat,
    ) ![]const u8 {
        var formatted_ptr: [*]u8 = undefined;
        var formatted_len: usize = 0;

        phoneutil_format_number(
            self.validator.util,
            self.number,
            fmt,
            &formatted_ptr,
            &formatted_len,
        );

        const result = try allocator.dupe(u8, formatted_ptr[0..formatted_len]);
        phoneutil_free_string(formatted_ptr);
        return result;
    }

    /// Get the region code (country) for the number
    pub fn getRegion(
        self: ParsedNumber,
        allocator: std.mem.Allocator,
    ) ![]const u8 {
        var region_ptr: [*]u8 = undefined;
        var region_len: usize = 0;

        phoneutil_get_region_code(
            self.validator.util,
            self.number,
            &region_ptr,
            &region_len,
        );

        const result = try allocator.dupe(u8, region_ptr[0..region_len]);
        phoneutil_free_string(region_ptr);
        return result;
    }

    /// Get the country calling code
    pub fn getCountryCode(self: ParsedNumber) u32 {
        return @intCast(phoneutil_get_country_code(self.number));
    }

    /// Get the national number (without country code)
    pub fn getNationalNumber(self: ParsedNumber) u64 {
        return phoneutil_get_national_number(self.number);
    }

    /// Free the phone number object
    pub fn deinit(self: ParsedNumber) void {
        phoneutil_free_number(self.number);
    }
};

test "basic phone number parsing" {
    const validator = PhoneValidator.init();
    const allocator = std.testing.allocator;

    // Test US number
    const parsed = try validator.parse(allocator, "+16502530000", null);
    defer parsed.deinit();

    try std.testing.expect(parsed.isValid());
    try std.testing.expectEqual(@as(u32, 1), parsed.getCountryCode());
}
