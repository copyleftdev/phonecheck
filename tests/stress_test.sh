#!/bin/bash
set -euo pipefail

echo "💪 PhoneCheck Stress Test"
echo "========================="
echo ""

# Check if server is running
if ! curl -s http://localhost:8080/health > /dev/null 2>&1; then
    echo "❌ Server is not running!"
    echo "   Start with: zig build run"
    exit 1
fi

echo "✅ Server is running"
echo ""

# Stress test parameters
CONCURRENT_CLIENTS=50
REQUESTS_PER_CLIENT=100
TOTAL_REQUESTS=$((CONCURRENT_CLIENTS * REQUESTS_PER_CLIENT))

echo "→ Configuration:"
echo "  Concurrent clients: $CONCURRENT_CLIENTS"
echo "  Requests per client: $REQUESTS_PER_CLIENT"
echo "  Total requests: $TOTAL_REQUESTS"
echo ""

# Function to send requests
send_requests() {
    local client_id=$1
    local success=0
    local failures=0
    
    for i in $(seq 1 $REQUESTS_PER_CLIENT); do
        # Rotate through different phone numbers
        case $((i % 5)) in
            0) number="+14155552671" ;;
            1) number="+442071838750" ;;
            2) number="+81312345678" ;;
            3) number="+919876543210" ;;
            4) number="+61291234567" ;;
        esac
        
        if curl -s -X POST http://localhost:8080/validate \
            -H "Content-Type: application/json" \
            -d "{\"phone_number\": \"$number\"}" > /dev/null 2>&1; then
            ((success++))
        else
            ((failures++))
        fi
    done
    
    echo "$client_id,$success,$failures"
}

export -f send_requests
export REQUESTS_PER_CLIENT

echo "→ Starting stress test..."
start_time=$(date +%s)

# Run concurrent clients
seq 1 $CONCURRENT_CLIENTS | xargs -P $CONCURRENT_CLIENTS -I {} bash -c 'send_requests {}'  > /tmp/stress_results.txt

end_time=$(date +%s)
duration=$((end_time - start_time))

echo ""
echo "✅ Stress test complete!"
echo ""

# Calculate statistics
total_success=$(awk -F',' '{sum+=$2} END {print sum}' /tmp/stress_results.txt)
total_failures=$(awk -F',' '{sum+=$3} END {print sum}' /tmp/stress_results.txt)
success_rate=$(awk "BEGIN {printf \"%.2f\", ($total_success / $TOTAL_REQUESTS) * 100}")
requests_per_sec=$(awk "BEGIN {printf \"%.2f\", $TOTAL_REQUESTS / $duration}")

echo "📊 Results:"
echo "  Duration: ${duration}s"
echo "  Total requests: $TOTAL_REQUESTS"
echo "  Successful: $total_success"
echo "  Failed: $total_failures"
echo "  Success rate: ${success_rate}%"
echo "  Throughput: ${requests_per_sec} req/s"
echo ""

if [ "$total_failures" -eq 0 ]; then
    echo "✅ All requests succeeded!"
else
    echo "⚠️  Some requests failed. Check server logs."
fi

# Cleanup
rm /tmp/stress_results.txt
