# 🚀 QuickStart Guide

Get PhoneCheck running in 5 minutes!

## Prerequisites Check

```bash
# Check if you have libphonenumber installed
ldconfig -p | grep phonenumber

# Check Zig version
zig version  # Should be 0.15.2 or later
```

## Option 1: Ubuntu/Debian (Recommended)

```bash
# Install dependencies
sudo apt-get update
sudo apt-get install -y libphonenumber-dev libprotobuf-dev libicu-dev

# Build and run
./build_wrapper.sh
zig build run
```

## Option 2: macOS

```bash
# Install dependencies
brew install libphonenumber protobuf icu4c

# Build and run
./build_wrapper.sh
zig build run
```

## Option 3: Docker

```bash
# Build image
docker build -t phonecheck .

# Run container
docker run -p 8080:8080 phonecheck
```

## Verify It Works

Open another terminal:

```bash
# Health check
curl http://localhost:8080/health

# Validate a phone number
curl -X POST http://localhost:8080/validate \
  -H "Content-Type: application/json" \
  -d '{"phone_number": "+14155552671"}'
```

Expected output:

```json
{
  "valid": true,
  "possible": true,
  "type": "FIXED_LINE_OR_MOBILE",
  "country_code": 1,
  "national_number": 4155552671,
  "region": "US",
  "e164_format": "+14155552671",
  "international_format": "+1 415-555-2671",
  "national_format": "(415) 555-2671",
  "possibility_reason": "IS_POSSIBLE"
}
```

## Run Tests

```bash
# Zig unit tests
zig build test

# API tests (requires server running)
./examples/test_api.sh
# or
python3 examples/test_api.py
```

## Common Issues

### "cannot find -lphonenumber"

libphonenumber not installed. Install it:

```bash
# Ubuntu/Debian
sudo apt-get install libphonenumber-dev

# macOS
brew install libphonenumber
```

### "zig: command not found"

Install Zig from https://ziglang.org/download/

### Build fails with C++ errors

Ensure you have a C++ compiler:

```bash
# Ubuntu/Debian
sudo apt-get install build-essential

# macOS
xcode-select --install
```

## Next Steps

- 📖 Read the full [README.md](README.md)
- 🏗️ Understand the [ARCHITECTURE.md](ARCHITECTURE.md)
- 🧪 Run more tests with `examples/test_api.py`
- 🚢 Deploy using the Dockerfile

## Performance Tips

For production:

```bash
# Build with optimizations
zig build -Doptimize=ReleaseFast

# Run the optimized binary
./zig-out/bin/phonecheck
```

## API Quick Reference

### Health Check

```bash
GET /health
```

### Validate Number

```bash
POST /validate
Content-Type: application/json

{
  "phone_number": "+14155552671",
  "region": "US"  // optional
}
```

### Response Fields

- `valid`: Is the number valid for its region?
- `possible`: Is the number theoretically possible?
- `type`: MOBILE, FIXED_LINE, TOLL_FREE, etc.
- `country_code`: Numeric country code (e.g., 1 for US)
- `national_number`: Number without country code
- `region`: ISO 3166-1 alpha-2 country code
- `e164_format`: International standard format
- `international_format`: Human-readable international
- `national_format`: Local format for the country
- `possibility_reason`: Why number is/isn't possible

---

**Questions?** Check the [README.md](README.md) or open an issue!
