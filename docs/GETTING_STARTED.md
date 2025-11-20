# Getting Started with PhoneCheck

Welcome! This guide will help you get PhoneCheck up and running quickly.

## What is PhoneCheck?

PhoneCheck is a **high-performance REST API** for phone number validation that wraps Google's **libphonenumber** library using **Zig** for maximum performance and safety.

### Why PhoneCheck?

- 🚀 **Blazing Fast**: Sub-millisecond validation
- 💰 **Zero Cost**: No per-request fees (unlike Twilio/Abstract)
- 🛡️ **Battle-Tested**: Uses Google's validation logic
- 🌍 **Global**: Supports 190+ countries
- 🔒 **Safe**: Memory-safe Zig + proven C++

## Installation Options

### Option 1: Quick Docker Setup (Recommended for Testing)

```bash
docker build -t phonecheck .
docker run -p 8080:8080 phonecheck
```

### Option 2: Native Installation (Best Performance)

#### Ubuntu/Debian

```bash
# Install dependencies
sudo apt-get update
sudo apt-get install -y libphonenumber-dev libprotobuf-dev libicu-dev

# Build
./build_wrapper.sh
zig build

# Run
zig build run
```

#### macOS

```bash
# Install dependencies
brew install libphonenumber protobuf icu4c

# Build
./build_wrapper.sh
zig build

# Run
zig build run
```

## First API Call

Once the server is running, try this:

```bash
curl -X POST http://localhost:8080/validate \
  -H "Content-Type: application/json" \
  -d '{"phone_number": "+14155552671"}'
```

You should see:

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

## Common Use Cases

### Validate Phone Numbers in Your App

**Python Example:**

```python
import requests

def validate_phone(number):
    response = requests.post(
        'http://localhost:8080/validate',
        json={'phone_number': number}
    )
    return response.json()

result = validate_phone('+14155552671')
if result['valid']:
    print(f"✅ Valid {result['type']} number")
    print(f"📍 Region: {result['region']}")
```

**JavaScript/Node.js Example:**

```javascript
async function validatePhone(phoneNumber) {
  const response = await fetch('http://localhost:8080/validate', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ phone_number: phoneNumber })
  });
  return response.json();
}

const result = await validatePhone('+14155552671');
console.log(`Valid: ${result.valid}`);
console.log(`Type: ${result.type}`);
```

### Format Phone Numbers

```bash
# Input: Any format
curl -X POST http://localhost:8080/validate \
  -H "Content-Type: application/json" \
  -d '{"phone_number": "(415) 555-2671", "region": "US"}'

# Output includes:
# - e164_format: "+14155552671"
# - international_format: "+1 415-555-2671"
# - national_format: "(415) 555-2671"
```

### Detect Phone Type

```bash
# Mobile, landline, toll-free, etc.
curl -X POST http://localhost:8080/validate \
  -H "Content-Type: application/json" \
  -d '{"phone_number": "+18001234567"}'

# Response includes:
# "type": "TOLL_FREE"
```

## API Endpoints

### Health Check

```bash
GET /health
```

Returns service status.

### Validate Phone Number

```bash
POST /validate
Content-Type: application/json

{
  "phone_number": "+14155552671",
  "region": "US"  // Optional: default region if not in E.164
}
```

Returns comprehensive validation results.

## Response Fields Explained

| Field | Description | Example |
|-------|-------------|---------|
| `valid` | Is the number valid for its region? | `true` |
| `possible` | Could this number exist? | `true` |
| `type` | Type of phone line | `"MOBILE"` |
| `country_code` | Numeric country code | `1` |
| `national_number` | Number without country code | `4155552671` |
| `region` | ISO 3166-1 alpha-2 code | `"US"` |
| `e164_format` | International standard | `"+14155552671"` |
| `international_format` | Human-readable international | `"+1 415-555-2671"` |
| `national_format` | Local format for country | `"(415) 555-2671"` |
| `possibility_reason` | Why number is/isn't possible | `"IS_POSSIBLE"` |

## Phone Types

- **MOBILE**: Mobile/cellular
- **FIXED_LINE**: Traditional landline
- **FIXED_LINE_OR_MOBILE**: Could be either
- **TOLL_FREE**: Toll-free (800, 888, etc.)
- **PREMIUM_RATE**: Premium rate service
- **VOIP**: Voice over IP
- **UNKNOWN**: Type cannot be determined

## Troubleshooting

### Server won't start

**Error**: "cannot find -lphonenumber"

**Solution**: Install libphonenumber development package

```bash
# Ubuntu/Debian
sudo apt-get install libphonenumber-dev

# macOS
brew install libphonenumber
```

### Invalid numbers return errors

This is expected! Invalid numbers should fail validation.

**Example Invalid:**

```bash
curl -X POST http://localhost:8080/validate \
  -H "Content-Type: application/json" \
  -d '{"phone_number": "+1234"}'

# Returns:
# {"error": "validation_error", "message": "Failed to parse phone number"}
```

### Performance is slower than expected

1. Build with optimizations:

```bash
zig build -Doptimize=ReleaseFast
./zig-out/bin/phonecheck
```

2. Ensure server has adequate resources
3. Check network latency if calling remotely

## Next Steps

### Learn More

- 📖 **Full Documentation**: [README.md](README.md)
- 🏗️ **Architecture Deep Dive**: [ARCHITECTURE.md](ARCHITECTURE.md)
- ⚖️ **vs Other Solutions**: [COMPARISON.md](COMPARISON.md)
- 🎯 **Project Overview**: [PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md)

### Run Examples

```bash
# Python test suite
python3 examples/test_api.py

# Bash tests
./examples/test_api.sh
```

### Deploy to Production

See [README.md](README.md#-deployment) for:
- Docker deployment
- Kubernetes configs
- Systemd services
- Cloud platform guides

## Support

- 🐛 **Report Issues**: GitHub Issues
- 💬 **Ask Questions**: GitHub Discussions
- 📧 **Contact**: [your-email@domain.com]

## Quick Reference Card

```
┌─────────────────────────────────────────────────────────┐
│                   PhoneCheck Cheat Sheet                │
├─────────────────────────────────────────────────────────┤
│ Start Server:                                           │
│   zig build run                                         │
│                                                         │
│ Health Check:                                           │
│   curl http://localhost:8080/health                    │
│                                                         │
│ Validate Number:                                        │
│   curl -X POST http://localhost:8080/validate \        │
│     -H "Content-Type: application/json" \              │
│     -d '{"phone_number": "+14155552671"}'              │
│                                                         │
│ Build for Production:                                   │
│   zig build -Doptimize=ReleaseFast                     │
│                                                         │
│ Run Tests:                                              │
│   zig build test                                        │
│   python3 examples/test_api.py                         │
└─────────────────────────────────────────────────────────┘
```

---

**Ready to validate millions of phone numbers?** 🚀

Start the server and make your first API call!
