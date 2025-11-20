const std = @import("std");
const libphonenumber = @import("libphonenumber.zig");

const PORT = 8080;
const MAX_BODY_SIZE = 1024 * 16;

const ValidateRequest = struct {
    phone_number: []const u8,
    region: ?[]const u8 = null,
};

const ValidateResponse = struct {
    valid: bool,
    possible: bool,
    type: []const u8,
    country_code: u32,
    national_number: u64,
    region: []const u8,
    e164_format: []const u8,
    international_format: []const u8,
    national_format: []const u8,
    possibility_reason: []const u8,
};

const ErrorResponse = struct {
    @"error": []const u8,
    message: []const u8,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const validator = libphonenumber.PhoneValidator.init();

    const address = try std.net.Address.parseIp("0.0.0.0", PORT);
    var server = try address.listen(.{
        .reuse_address = true,
    });
    defer server.deinit();

    std.debug.print("🚀 PhoneCheck REST API listening on http://0.0.0.0:{d}\n", .{PORT});
    std.debug.print("Endpoints:\n", .{});
    std.debug.print("  POST /validate - Validate a phone number\n", .{});
    std.debug.print("  GET  /health   - Health check\n\n", .{});

    while (true) {
        const connection = try server.accept();

        const thread = try std.Thread.spawn(.{}, handleConnection, .{
            allocator,
            connection,
            validator,
        });
        thread.detach();
    }
}

fn handleConnection(
    allocator: std.mem.Allocator,
    connection: std.net.Server.Connection,
    validator: libphonenumber.PhoneValidator,
) void {
    defer connection.stream.close();

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    handleRequest(arena_allocator, connection, validator) catch |err| {
        std.debug.print("Error handling request: {}\n", .{err});
    };
}

fn handleRequest(
    allocator: std.mem.Allocator,
    connection: std.net.Server.Connection,
    validator: libphonenumber.PhoneValidator,
) !void {
    var buffer: [4096]u8 = undefined;

    const bytes_read = try connection.stream.read(&buffer);
    if (bytes_read == 0) return;

    const request_data = buffer[0..bytes_read];
    var lines = std.mem.splitScalar(u8, request_data, '\n');
    const request_line = lines.next() orelse return error.InvalidRequest;

    var parts = std.mem.splitScalar(u8, request_line, ' ');
    const method = parts.next() orelse return error.InvalidMethod;
    const path_raw = parts.next() orelse return error.InvalidPath;

    const path = std.mem.trim(u8, path_raw, &std.ascii.whitespace);

    std.debug.print("{s} {s}\n", .{ method, path });

    if (std.mem.eql(u8, method, "GET") and std.mem.eql(u8, path, "/health")) {
        try sendHealthCheck(connection);
    } else if (std.mem.eql(u8, method, "POST") and std.mem.eql(u8, path, "/validate")) {
        try handleValidate(allocator, connection, request_data, validator);
    } else if (std.mem.eql(u8, method, "OPTIONS")) {
        try sendCorsPrelight(connection);
    } else {
        try sendNotFound(connection);
    }
}

fn handleValidate(
    allocator: std.mem.Allocator,
    connection: std.net.Server.Connection,
    request_data: []const u8,
    validator: libphonenumber.PhoneValidator,
) !void {
    const body_start = std.mem.indexOf(u8, request_data, "\r\n\r\n") orelse
        std.mem.indexOf(u8, request_data, "\n\n") orelse
        return error.NoBody;

    const body = request_data[body_start + 4 ..];
    if (body.len == 0) return error.EmptyBody;

    const parsed = std.json.parseFromSlice(
        ValidateRequest,
        allocator,
        body,
        .{ .ignore_unknown_fields = true },
    ) catch {
        return sendError(connection, 400, "Invalid JSON");
    };
    defer parsed.deinit();

    const req = parsed.value;

    const result = validatePhoneNumber(
        allocator,
        validator,
        req.phone_number,
        req.region,
    ) catch |err| {
        const msg = switch (err) {
            error.ParseFailed => "Failed to parse phone number",
            error.OutOfMemory => "Out of memory",
        };
        return sendError(connection, 400, msg);
    };
    defer {
        allocator.free(result.type);
        allocator.free(result.region);
        allocator.free(result.e164_format);
        allocator.free(result.international_format);
        allocator.free(result.national_format);
        allocator.free(result.possibility_reason);
    }

    var response_buffer: std.ArrayListUnmanaged(u8) = .{};
    defer response_buffer.deinit(allocator);

    const writer = response_buffer.writer(allocator);
    try writer.print(
        "{{\"valid\":{},\"possible\":{},\"type\":\"{s}\",\"country_code\":{d},\"national_number\":{d},\"region\":\"{s}\",\"e164_format\":\"{s}\",\"international_format\":\"{s}\",\"national_format\":\"{s}\",\"possibility_reason\":\"{s}\"}}",
        .{
            result.valid,
            result.possible,
            result.type,
            result.country_code,
            result.national_number,
            result.region,
            result.e164_format,
            result.international_format,
            result.national_format,
            result.possibility_reason,
        },
    );

    try sendResponse(
        connection,
        200,
        "application/json",
        response_buffer.items,
    );
}

fn validatePhoneNumber(
    allocator: std.mem.Allocator,
    validator: libphonenumber.PhoneValidator,
    phone_number: []const u8,
    region: ?[]const u8,
) !ValidateResponse {
    const parsed = try validator.parse(allocator, phone_number, region);
    defer parsed.deinit();

    const phone_type = parsed.getType();
    const type_str = try phoneTypeToString(allocator, phone_type);

    const possibility = parsed.isPossibleWithReason();
    const possibility_str = try possibilityToString(allocator, possibility);

    return ValidateResponse{
        .valid = parsed.isValid(),
        .possible = parsed.isPossible(),
        .type = type_str,
        .country_code = parsed.getCountryCode(),
        .national_number = parsed.getNationalNumber(),
        .region = try parsed.getRegion(allocator),
        .e164_format = try parsed.format(allocator, .E164),
        .international_format = try parsed.format(allocator, .INTERNATIONAL),
        .national_format = try parsed.format(allocator, .NATIONAL),
        .possibility_reason = possibility_str,
    };
}

fn phoneTypeToString(
    allocator: std.mem.Allocator,
    phone_type: libphonenumber.PhoneNumberType,
) ![]const u8 {
    const str = switch (phone_type) {
        .FIXED_LINE => "FIXED_LINE",
        .MOBILE => "MOBILE",
        .FIXED_LINE_OR_MOBILE => "FIXED_LINE_OR_MOBILE",
        .TOLL_FREE => "TOLL_FREE",
        .PREMIUM_RATE => "PREMIUM_RATE",
        .SHARED_COST => "SHARED_COST",
        .VOIP => "VOIP",
        .PERSONAL_NUMBER => "PERSONAL_NUMBER",
        .PAGER => "PAGER",
        .UAN => "UAN",
        .VOICEMAIL => "VOICEMAIL",
        .UNKNOWN => "UNKNOWN",
    };
    return try allocator.dupe(u8, str);
}

fn possibilityToString(
    allocator: std.mem.Allocator,
    result: libphonenumber.ValidationResult,
) ![]const u8 {
    const str = switch (result) {
        .IS_POSSIBLE => "IS_POSSIBLE",
        .INVALID_COUNTRY_CODE => "INVALID_COUNTRY_CODE",
        .TOO_SHORT => "TOO_SHORT",
        .TOO_LONG => "TOO_LONG",
        .IS_POSSIBLE_LOCAL_ONLY => "IS_POSSIBLE_LOCAL_ONLY",
        .INVALID_LENGTH => "INVALID_LENGTH",
    };
    return try allocator.dupe(u8, str);
}

fn sendHealthCheck(connection: std.net.Server.Connection) !void {
    const response =
        \\{"status":"healthy","service":"phonecheck","version":"1.0.0"}
    ;
    try sendResponse(connection, 200, "application/json", response);
}

fn sendNotFound(connection: std.net.Server.Connection) !void {
    const response =
        \\{"error":"not_found","message":"Endpoint not found"}
    ;
    try sendResponse(connection, 404, "application/json", response);
}

fn sendError(
    connection: std.net.Server.Connection,
    status: u16,
    message: []const u8,
) !void {
    var buffer: [512]u8 = undefined;
    const response = try std.fmt.bufPrint(
        &buffer,
        "{{\"error\":\"validation_error\",\"message\":\"{s}\"}}",
        .{message},
    );
    try sendResponse(connection, status, "application/json", response);
}

fn sendCorsPrelight(connection: std.net.Server.Connection) !void {
    const response =
        "HTTP/1.1 204 No Content\r\n" ++
        "Access-Control-Allow-Origin: *\r\n" ++
        "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n" ++
        "Access-Control-Allow-Headers: Content-Type\r\n" ++
        "Access-Control-Max-Age: 86400\r\n" ++
        "\r\n";
    _ = try connection.stream.write(response);
}

fn sendResponse(
    connection: std.net.Server.Connection,
    status: u16,
    content_type: []const u8,
    body: []const u8,
) !void {
    var buffer: [2048]u8 = undefined;
    const status_text = if (status == 200) "OK" else if (status == 404) "Not Found" else "Bad Request";

    const header = try std.fmt.bufPrint(
        &buffer,
        "HTTP/1.1 {d} {s}\r\n" ++
            "Content-Type: {s}\r\n" ++
            "Content-Length: {d}\r\n" ++
            "Access-Control-Allow-Origin: *\r\n" ++
            "Connection: close\r\n" ++
            "\r\n",
        .{ status, status_text, content_type, body.len },
    );

    _ = try connection.stream.write(header);
    _ = try connection.stream.write(body);
}

test "basic validation" {
    const validator = libphonenumber.PhoneValidator.init();
    const allocator = std.testing.allocator;

    const result = try validatePhoneNumber(
        allocator,
        validator,
        "+14155552671",
        null,
    );
    defer {
        allocator.free(result.type);
        allocator.free(result.region);
        allocator.free(result.e164_format);
        allocator.free(result.international_format);
        allocator.free(result.national_format);
        allocator.free(result.possibility_reason);
    }

    try std.testing.expect(result.valid);
    try std.testing.expectEqual(@as(u32, 1), result.country_code);
}
