#!/bin/bash
set -euo pipefail

echo "🧪 Running Property-Based Tests"
echo "================================"
echo ""

# Build property tests
echo "→ Building property tests..."
zig test tests/property_tests.zig \
    -I/usr/include \
    -I/usr/local/include \
    -L/home/sigma/Projects/phonecheck/lib \
    -lphonenumber_wrapper \
    -lc \
    -lc++

echo ""
echo "✅ All property tests passed!"
echo ""
echo "Properties verified:"
echo "  ✓ Valid E.164 numbers parse correctly"
echo "  ✓ Formatted numbers are consistent"
echo "  ✓ Country codes are in valid range"
echo "  ✓ National numbers are positive"
echo "  ✓ Region codes match expected values"
echo "  ✓ All format types produce non-empty output"
echo "  ✓ No memory leaks on parse failures"
echo "  ✓ Region hints work correctly"
echo "  ✓ Phone types are within valid enum range"
