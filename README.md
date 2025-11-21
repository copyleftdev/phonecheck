# 📞 PhoneCheck - Expert-Level Phone Validation REST API

[![CI](https://github.com/copyleftdev/phonecheck/actions/workflows/ci.yml/badge.svg)](https://github.com/copyleftdev/phonecheck/actions/workflows/ci.yml)
[![Docker Build](https://github.com/copyleftdev/phonecheck/actions/workflows/docker.yml/badge.svg)](https://github.com/copyleftdev/phonecheck/actions/workflows/docker.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Zig](https://img.shields.io/badge/Zig-0.15.2-orange.svg)](https://ziglang.org/)
[![libphonenumber](https://img.shields.io/badge/libphonenumber-8.12.57-blue.svg)](https://github.com/google/libphonenumber)
[![Production Ready](https://img.shields.io/badge/production-ready-brightgreen.svg)](docs/PRODUCTION_READINESS.md)

A high-performance, production-ready REST API for phone number validation built with **Zig** and wrapping **Google's libphonenumber** C++ library.

> 🚀 **Free alternative to Twilio Lookup** - Validate 10M numbers/month for $40 instead of $50,000
> 
> ⚡ **2,500+ req/s throughput** - Battle-tested with simulated annealing load analysis
> 
> 🔒 **Memory-safe** - Zig's compile-time guarantees + arena allocators

## Documentation

- **[Quick Start](docs/QUICKSTART.md)** - Get started in 5 minutes
- **[Architecture](docs/ARCHITECTURE.md)** - Technical design and implementation
- **[Testing](docs/TESTING.md)** - Comprehensive testing guide
- **[Production Readiness](docs/PRODUCTION_READINESS.md)** - Deployment checklist
- **[Advanced Testing](docs/ADVANCED_TESTING.md)** - Simulated annealing breaking point analysis

## 🚀 Features

- **Industry-Standard Validation**: Powered by Google's libphonenumber (used by Google, Android, iOS)
- **Zero-Copy FFI**: Direct C/C++ interop with no marshalling overhead
- **Ultra-Fast**: Zig's performance + libphonenumber's battle-tested algorithms
- **Comprehensive Analysis**:
  - ✅ Validity checking (correct for region)
  - ✅ Possibility checking (correct length/structure)
  - ✅ Phone type detection (mobile, fixed-line, toll-free, etc.)
  - ✅ Region/country code extraction
  - ✅ Multiple format outputs (E.164, international, national)
  - ✅ Number comparison and matching
- **190+ Countries**: Full international support
- **REST API**: Simple HTTP JSON interface
- **Production-Ready**: CORS support, error handling, health checks

## 📋 Prerequisites

### System Dependencies

You need to install Google's libphonenumber C++ library:

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install -y \
    libphonenumber-dev \
    libprotobuf-dev \
    libicu-dev \
    cmake \
    build-essential
```

**macOS (Homebrew):**
```bash
brew install libphonenumber protobuf icu4c
```

**Arch Linux:**
```bash
sudo pacman -S libphonenumber protobuf icu
```

**Build from source** (if packages not available):
```bash
# Clone and build libphonenumber
git clone https://github.com/google/libphonenumber.git
cd libphonenumber/cpp
mkdir build && cd build
cmake ..
make -j$(nproc)
sudo make install
sudo ldconfig
```

### Zig

Install Zig 0.15.2 or later:
```bash
# Download from https://ziglang.org/download/
# Or use your package manager
```

## 🔧 Installation

1. **Clone the repository:**
```bash
git clone <your-repo>
cd phonecheck
```

2. **Build the C++ wrapper:**
```bash
./build_wrapper.sh
```

3. **Build the Zig application:**
```bash
zig build
```

4. **Run the server:**
```bash
zig build run
```

The API will start on `http://0.0.0.0:8080`

## 📚 API Documentation

### Health Check

**Endpoint:** `GET /health`

**Response:**
```json
{
  "status": "healthy",
  "service": "phonecheck",
  "version": "1.0.0"
}
```

### Validate Phone Number

**Endpoint:** `POST /validate`

**Request Body:**
```json
{
  "phone_number": "+14155552671",
  "region": "US"  // Optional: ISO 3166-1 alpha-2 country code
}
```

**Response:**
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

**Phone Types:**
- `FIXED_LINE` - Traditional landline
- `MOBILE` - Mobile phone
- `FIXED_LINE_OR_MOBILE` - Could be either
- `TOLL_FREE` - Toll-free number
- `PREMIUM_RATE` - Premium rate number
- `SHARED_COST` - Shared cost service
- `VOIP` - VoIP number
- `PERSONAL_NUMBER` - Personal number
- `PAGER` - Pager
- `UAN` - Universal Access Number
- `VOICEMAIL` - Voicemail access
- `UNKNOWN` - Unknown type

**Possibility Reasons:**
- `IS_POSSIBLE` - Number is valid
- `INVALID_COUNTRY_CODE` - Invalid country code
- `TOO_SHORT` - Too few digits
- `TOO_LONG` - Too many digits
- `IS_POSSIBLE_LOCAL_ONLY` - Valid locally only
- `INVALID_LENGTH` - Invalid length for region

## 🧪 Testing

Run the test suite:
```bash
zig build test
```

## 📖 Usage Examples

### cURL

```bash
# Validate a US number
curl -X POST http://localhost:8080/validate \
  -H "Content-Type: application/json" \
  -d '{"phone_number": "+14155552671"}'

# Validate with explicit region
curl -X POST http://localhost:8080/validate \
  -H "Content-Type: application/json" \
  -d '{"phone_number": "4155552671", "region": "US"}'

# International number
curl -X POST http://localhost:8080/validate \
  -H "Content-Type: application/json" \
  -d '{"phone_number": "+442071838750", "region": "GB"}'
```

### Python

```python
import requests

def validate_phone(number: str, region: str = None):
    response = requests.post(
        "http://localhost:8080/validate",
        json={"phone_number": number, "region": region}
    )
    return response.json()

# Example usage
result = validate_phone("+14155552671")
print(f"Valid: {result['valid']}")
print(f"Type: {result['type']}")
print(f"International: {result['international_format']}")
```

### JavaScript/TypeScript

```typescript
async function validatePhone(
  phoneNumber: string,
  region?: string
): Promise<ValidationResult> {
  const response = await fetch('http://localhost:8080/validate', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ phone_number: phoneNumber, region })
  });
  return response.json();
}

// Example usage
const result = await validatePhone('+14155552671');
console.log(`Valid: ${result.valid}`);
console.log(`Type: ${result.type}`);
```

## 🏗️ Architecture

```
┌─────────────┐
│   Client    │
│ (HTTP/JSON) │
└──────┬──────┘
       │
       ▼
┌─────────────────────┐
│   Zig HTTP Server   │
│  - Routing          │
│  - JSON parsing     │
│  - Error handling   │
└──────┬──────────────┘
       │ Zero-copy FFI
       ▼
┌─────────────────────┐
│  C++ Wrapper        │
│  - Type conversion  │
│  - Memory safety    │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│  libphonenumber     │
│  - Parsing          │
│  - Validation       │
│  - Formatting       │
└─────────────────────┘
```

## 🎯 Performance

- **Sub-millisecond** validation latency
- **Zero allocation** in hot paths (using arena allocators)
- **Concurrent request handling** via Zig threads
- **Direct C FFI** with no serialization overhead

## 🔒 Safety

Following [Tiger Style](https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md) principles:

- ✅ Explicit bounds on all buffers
- ✅ No recursion
- ✅ Arena allocators for request scoping
- ✅ Fail-fast error handling
- ✅ Comprehensive input validation

## 🚢 Deployment

### Docker

```dockerfile
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    libphonenumber-dev libprotobuf-dev libicu-dev

COPY zig-out/bin/phonecheck /usr/local/bin/
EXPOSE 8080
CMD ["phonecheck"]
```

### Systemd Service

```ini
[Unit]
Description=PhoneCheck REST API
After=network.target

[Service]
Type=simple
User=phonecheck
ExecStart=/usr/local/bin/phonecheck
Restart=always

[Install]
WantedBy=multi-user.target
```

## 📊 Monitoring

The API exposes structured logs via stdout. Key metrics:

- Request method and path
- Response status codes
- Error messages
- Connection handling

Integrate with your logging infrastructure (ELK, Loki, CloudWatch, etc.)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests: `zig build test`
5. Submit a pull request

## 📄 License

MIT License - See LICENSE file

## 🙏 Acknowledgments

- **Google's libphonenumber**: The gold standard for phone number handling
- **Zig**: Modern systems programming with safety and performance
- **TigerBeetle**: Inspiration for robust, zero-technical-debt coding practices

## 📞 Support

- Issues: [GitHub Issues](your-repo/issues)
- Discussions: [GitHub Discussions](your-repo/discussions)

---

**Built with ❤️ using Zig and libphonenumber**
