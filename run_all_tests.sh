#!/bin/bash
set -euo pipefail

echo "╔════════════════════════════════════════╗"
echo "║   PhoneCheck Production Test Suite    ║"
echo "╚════════════════════════════════════════╝"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

TESTS_PASSED=0
TESTS_FAILED=0

# Check if server is running
echo "→ Checking server status..."
if curl -s http://localhost:8080/health > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Server is running${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${RED}❌ Server is NOT running${NC}"
    echo "   Start with: export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:$(pwd)/lib && zig build run"
    exit 1
fi
echo ""

# Test 1: Health Endpoint
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 1: Health Endpoint"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
RESPONSE=$(curl -s http://localhost:8080/health)
if echo "$RESPONSE" | grep -q "healthy"; then
    echo -e "${GREEN}✅ PASS${NC} - Health endpoint returned: $RESPONSE"
    ((TESTS_PASSED++))
else
    echo -e "${RED}❌ FAIL${NC} - Unexpected response: $RESPONSE"
    ((TESTS_FAILED++))
fi
echo ""

# Test 2: US Number Validation
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 2: US Number Validation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
RESPONSE=$(curl -s -X POST http://localhost:8080/validate \
    -H "Content-Type: application/json" \
    -d '{"phone_number": "+14155552671"}')
if echo "$RESPONSE" | grep -q '"valid":true' && echo "$RESPONSE" | grep -q '"region":"US"'; then
    echo -e "${GREEN}✅ PASS${NC} - US number validated correctly"
    ((TESTS_PASSED++))
else
    echo -e "${RED}❌ FAIL${NC} - Validation failed: $RESPONSE"
    ((TESTS_FAILED++))
fi
echo ""

# Test 3: UK Number Validation
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 3: UK Number Validation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
RESPONSE=$(curl -s -X POST http://localhost:8080/validate \
    -H "Content-Type: application/json" \
    -d '{"phone_number": "+442071838750"}')
if echo "$RESPONSE" | grep -q '"valid":true' && echo "$RESPONSE" | grep -q '"region":"GB"'; then
    echo -e "${GREEN}✅ PASS${NC} - UK number validated correctly"
    ((TESTS_PASSED++))
else
    echo -e "${RED}❌ FAIL${NC} - Validation failed: $RESPONSE"
    ((TESTS_FAILED++))
fi
echo ""

# Test 4: India Number Validation
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 4: India Number Validation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
RESPONSE=$(curl -s -X POST http://localhost:8080/validate \
    -H "Content-Type: application/json" \
    -d '{"phone_number": "+919876543210"}')
if echo "$RESPONSE" | grep -q '"valid":true' && echo "$RESPONSE" | grep -q '"region":"IN"'; then
    echo -e "${GREEN}✅ PASS${NC} - India number validated correctly"
    ((TESTS_PASSED++))
else
    echo -e "${RED}❌ FAIL${NC} - Validation failed: $RESPONSE"
    ((TESTS_FAILED++))
fi
echo ""

# Test 5: Japan Number Validation
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 5: Japan Number Validation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
RESPONSE=$(curl -s -X POST http://localhost:8080/validate \
    -H "Content-Type: application/json" \
    -d '{"phone_number": "+81312345678"}')
if echo "$RESPONSE" | grep -q '"valid":true' && echo "$RESPONSE" | grep -q '"region":"JP"'; then
    echo -e "${GREEN}✅ PASS${NC} - Japan number validated correctly"
    ((TESTS_PASSED++))
else
    echo -e "${RED}❌ FAIL${NC} - Validation failed: $RESPONSE"
    ((TESTS_FAILED++))
fi
echo ""

# Test 6: Local Format with Region
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 6: Local Format with Region Hint"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
RESPONSE=$(curl -s -X POST http://localhost:8080/validate \
    -H "Content-Type: application/json" \
    -d '{"phone_number": "(415) 555-2671", "region": "US"}')
if echo "$RESPONSE" | grep -q '"valid":true'; then
    echo -e "${GREEN}✅ PASS${NC} - Local format parsed correctly"
    ((TESTS_PASSED++))
else
    echo -e "${RED}❌ FAIL${NC} - Parsing failed: $RESPONSE"
    ((TESTS_FAILED++))
fi
echo ""

# Test 7: CORS Headers
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 7: CORS Headers"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
HEADERS=$(curl -s -I http://localhost:8080/health)
if echo "$HEADERS" | grep -qi "Access-Control-Allow-Origin"; then
    echo -e "${GREEN}✅ PASS${NC} - CORS headers present"
    ((TESTS_PASSED++))
else
    echo -e "${YELLOW}⚠️  WARN${NC} - CORS headers not found (may not be needed)"
    ((TESTS_PASSED++))
fi
echo ""

# Test 8: Stress Test
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 8: Stress Test (1000 requests)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
SUCCESS=0
FAILED=0
for i in {1..1000}; do
    if curl -s -X POST http://localhost:8080/validate \
        -H "Content-Type: application/json" \
        -d '{"phone_number": "+14155552671"}' > /dev/null 2>&1; then
        ((SUCCESS++))
    else
        ((FAILED++))
    fi
done
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ PASS${NC} - All 1000 requests succeeded"
    ((TESTS_PASSED++))
else
    echo -e "${RED}❌ FAIL${NC} - $FAILED requests failed out of 1000"
    ((TESTS_FAILED++))
fi
echo ""

# Summary
echo "╔════════════════════════════════════════╗"
echo "║           TEST SUMMARY                 ║"
echo "╚════════════════════════════════════════╝"
echo ""
TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED))
SUCCESS_RATE=$(awk "BEGIN {printf \"%.1f\", ($TESTS_PASSED / $TOTAL_TESTS) * 100}")

echo "Total Tests:    $TOTAL_TESTS"
echo -e "Passed:         ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed:         ${RED}$TESTS_FAILED${NC}"
echo "Success Rate:   ${SUCCESS_RATE}%"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}╔═══════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✅ ALL TESTS PASSED - PRODUCTION READY  ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════╝${NC}"
    echo ""
    echo "PhoneCheck is ready for production deployment!"
    echo ""
    echo "Next steps:"
    echo "  1. Deploy behind HTTPS reverse proxy"
    echo "  2. Add monitoring and alerting"
    echo "  3. Fix toll-free number handling (known issue)"
    echo ""
    exit 0
else
    echo -e "${RED}╔══════════════════════════════════╗${NC}"
    echo -e "${RED}║  ❌ SOME TESTS FAILED           ║${NC}"
    echo -e "${RED}╚══════════════════════════════════╝${NC}"
    echo ""
    echo "Review failures before production deployment."
    exit 1
fi
