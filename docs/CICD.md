# CI/CD Pipeline

PhoneCheck uses GitHub Actions for continuous integration and deployment.

## Workflows

### 1. CI Pipeline (`.github/workflows/ci.yml`)

**Triggers:**
- Push to `main` branch
- Pull requests to `main`

**Jobs:**

#### Build and Test
- Sets up Zig 0.15.2
- Installs system dependencies (libphonenumber, protobuf, ICU)
- Builds C++ wrapper
- Compiles PhoneCheck
- Runs unit tests
- Starts server and validates API endpoints
- Checks code formatting

#### Security Scan
- Runs Trivy vulnerability scanner
- Uploads results to GitHub Security tab
- Scans filesystem for security issues

**Status:** [![CI](https://github.com/copyleftdev/phonecheck/actions/workflows/ci.yml/badge.svg)](https://github.com/copyleftdev/phonecheck/actions/workflows/ci.yml)

### 2. Docker Build (`.github/workflows/docker.yml`)

**Triggers:**
- Push to `main` branch
- Version tags (`v*`)
- Pull requests to `main`

**Actions:**
- Builds Docker image using buildx
- Pushes to GitHub Container Registry (ghcr.io)
- Tags images with:
  - Branch name
  - PR number
  - Semantic version
  - Git SHA
- Uses layer caching for faster builds

**Status:** [![Docker Build](https://github.com/copyleftdev/phonecheck/actions/workflows/docker.yml/badge.svg)](https://github.com/copyleftdev/phonecheck/actions/workflows/docker.yml)

**Image:** `ghcr.io/copyleftdev/phonecheck:main`

### 3. Release Pipeline (`.github/workflows/release.yml`)

**Triggers:**
- Version tags (`v*`)

**Actions:**
- Builds optimized release binary (`-Doptimize=ReleaseFast`)
- Creates distribution tarball with:
  - Compiled binary
  - Shared library
  - README and LICENSE
- Generates release notes
- Creates GitHub Release with artifacts

**Usage:**
```bash
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0
```

## Container Usage

### Pull Image
```bash
docker pull ghcr.io/copyleftdev/phonecheck:main
```

### Run Container
```bash
docker run -p 8080:8080 ghcr.io/copyleftdev/phonecheck:main
```

### Test Container
```bash
curl http://localhost:8080/health
curl -X POST http://localhost:8080/validate \
  -H "Content-Type: application/json" \
  -d '{"phone_number": "+14155552671"}'
```

## Release Process

1. **Update Version**
   - Bump version in relevant files
   - Update CHANGELOG (if present)

2. **Create Tag**
   ```bash
   git tag -a v1.0.0 -m "Release v1.0.0: Description"
   git push origin v1.0.0
   ```

3. **Automated Actions**
   - CI runs full test suite
   - Docker image built and pushed
   - Release binary compiled
   - GitHub Release created with artifacts

4. **Verify**
   - Check GitHub Actions for green builds
   - Verify Docker image: `docker pull ghcr.io/copyleftdev/phonecheck:v1.0.0`
   - Download and test release artifact

## Security

### Vulnerability Scanning
- Trivy scans on every push
- Results uploaded to GitHub Security
- Alerts for critical/high vulnerabilities

### Container Security
- Base image: Official Zig Docker image
- Minimal dependencies
- Non-root user execution (in Dockerfile)
- Layer caching for reproducibility

## Local Testing

### Test CI Locally
```bash
# Install act (GitHub Actions local runner)
brew install act  # or: curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# Run CI workflow
act push
```

### Build Docker Locally
```bash
docker build -t phonecheck:local .
docker run -p 8080:8080 phonecheck:local
```

### Run Tests
```bash
./build_wrapper.sh
zig build
./run_all_tests.sh
```

## Monitoring

### Build Status
- Check [Actions tab](https://github.com/copyleftdev/phonecheck/actions)
- Green checkmark = passing
- Red X = failing
- Yellow dot = in progress

### Security Alerts
- Check [Security tab](https://github.com/copyleftdev/phonecheck/security)
- Review Dependabot alerts
- Review Trivy scan results

## Environment Variables

None required for CI/CD. All dependencies are system-installed.

## Badges

Add to README:
```markdown
[![CI](https://github.com/copyleftdev/phonecheck/actions/workflows/ci.yml/badge.svg)](https://github.com/copyleftdev/phonecheck/actions/workflows/ci.yml)
[![Docker Build](https://github.com/copyleftdev/phonecheck/actions/workflows/docker.yml/badge.svg)](https://github.com/copyleftdev/phonecheck/actions/workflows/docker.yml)
```

## Troubleshooting

### CI Fails on Dependency Install
- Check system package versions
- Update apt package names if changed
- Verify libphonenumber availability

### Docker Build Timeout
- Increase timeout in workflow
- Use smaller base image
- Optimize layer ordering

### Release Artifact Missing
- Check zig build output
- Verify tarball creation step
- Ensure release permissions set

## Future Enhancements

- [ ] Add deployment to cloud providers
- [ ] Implement staging environment
- [ ] Add performance benchmarking in CI
- [ ] Integrate with monitoring services
- [ ] Add automated changelog generation
- [ ] Implement semantic versioning automation

---

**Status:** All workflows operational ✅

**Last Updated:** 2025-11-20
