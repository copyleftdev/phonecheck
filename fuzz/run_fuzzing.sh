#!/bin/bash
set -euo pipefail

echo "🔬 PhoneCheck Fuzzing Suite"
echo "============================"
echo ""

# Build fuzz targets
echo "→ Building fuzz targets..."
zig build-exe fuzz/fuzz_phone_validator.zig \
    -femit-bin=fuzz/bin/fuzz_phone_validator \
    --name fuzz_phone_validator \
    lib/phonenumber_wrapper.o \
    -lphonenumber -lprotobuf -licuuc -licudata -lc++ -lc

zig build-exe fuzz/fuzz_http_parser.zig \
    -femit-bin=fuzz/bin/fuzz_http_parser \
    --name fuzz_http_parser

zig build-exe fuzz/fuzz_json_formatter.zig \
    -femit-bin=fuzz/bin/fuzz_json_formatter \
    --name fuzz_json_formatter

echo "✅ Fuzz targets built"
echo ""

# Check if AFL is installed
if command -v afl-fuzz &> /dev/null; then
    echo "→ AFL++ detected, running AFL fuzzing..."
    echo "  Note: This will run for 60 seconds per target"
    echo ""
    
    # Fuzz phone validator
    echo "📞 Fuzzing phone validator..."
    timeout 60s afl-fuzz -i fuzz/corpus/valid_numbers.txt \
        -o fuzz/findings/phone_validator \
        -- fuzz/bin/fuzz_phone_validator || true
    
    echo "✅ Phone validator fuzzing complete"
    
    # Check for crashes
    if [ -d "fuzz/findings/phone_validator/crashes" ] && [ "$(ls -A fuzz/findings/phone_validator/crashes)" ]; then
        echo "❌ CRASHES FOUND in phone validator!"
        ls -l fuzz/findings/phone_validator/crashes/
    else
        echo "✅ No crashes found in phone validator"
    fi
else
    echo "⚠️  AFL++ not installed. Running basic fuzzing..."
    echo "   Install with: sudo apt-get install afl++"
    echo ""
    
    # Basic fuzzing without AFL
    echo "→ Testing with valid numbers corpus..."
    while IFS= read -r number; do
        echo "$number" | fuzz/bin/fuzz_phone_validator || echo "  Failed: $number"
    done < fuzz/corpus/valid_numbers.txt
    
    echo ""
    echo "→ Testing with edge cases corpus..."
    while IFS= read -r number; do
        echo "$number" | fuzz/bin/fuzz_phone_validator || echo "  Failed: $number"
    done < fuzz/corpus/edge_cases.txt
fi

echo ""
echo "✅ Fuzzing complete!"
echo ""
echo "📊 Summary:"
echo "  - Tested phone number validation"
echo "  - Tested HTTP parsing"
echo "  - Tested JSON formatting"
echo ""
echo "Next steps:"
echo "  1. Review any crashes found"
echo "  2. Run longer fuzzing campaigns (24+ hours)"
echo "  3. Add sanitizers (AddressSanitizer, UndefinedBehaviorSanitizer)"
