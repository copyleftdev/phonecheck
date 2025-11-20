#!/bin/bash
set -euo pipefail

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     Quick Breaking Point Analysis (Simulated Annealing)   ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Check server
if ! curl -s http://localhost:8080/health > /dev/null 2>&1; then
    echo "❌ Server not running!"
    exit 1
fi

# Quick parameters
INITIAL_TEMP=50.0
COOLING_RATE=0.90
MIN_TEMP=1.0
MAX_ITERATIONS=15
SUCCESS_THRESHOLD=95.0

echo "Parameters: Temp=$INITIAL_TEMP, Cooling=$COOLING_RATE, Iterations=$MAX_ITERATIONS"
echo ""

# Test function
test_load() {
    local clients=$1
    local requests=$2
    
    # Create temp file for results
    local tmpfile=$(mktemp)
    
    # Function to run one client
    run_client() {
        local req_count=$1
        local success=0
        for ((r=1; r<=req_count; r++)); do
            if curl -s -m 2 -X POST http://localhost:8080/validate \
                -H "Content-Type: application/json" \
                -d '{"phone_number": "+14155552671"}' > /dev/null 2>&1; then
                ((success++))
            fi
        done
        echo "$success" >> "$tmpfile"
    }
    
    export -f run_client
    
    # Run clients in parallel
    for ((c=1; c<=clients; c++)); do
        run_client $requests &
    done
    
    wait
    
    # Calculate results
    local total_success=0
    local total_requests=$((clients * requests))
    
    while IFS= read -r line; do
        total_success=$((total_success + line))
    done < "$tmpfile"
    
    rm -f "$tmpfile"
    
    if [ $total_requests -eq 0 ]; then
        echo "0"
        return
    fi
    
    awk "BEGIN {printf \"%.1f\", ($total_success / $total_requests) * 100}"
}

# Initialize
current_clients=10
current_requests=20
current_load=$((current_clients * current_requests))

echo "→ Testing initial state: ${current_clients}c × ${current_requests}r = ${current_load}"
current_success=$(test_load $current_clients $current_requests)
echo "  Success: ${current_success}%"
echo ""

if (( $(awk "BEGIN {print ($current_success >= $SUCCESS_THRESHOLD)}") )); then
    current_energy=$(awk "BEGIN {print -$current_load}")
else
    current_energy=$(awk "BEGIN {print -$current_load * ($current_success / 100)}")
fi

best_clients=$current_clients
best_requests=$current_requests
best_load=$current_load
best_success=$current_success
best_energy=$current_energy

temperature=$INITIAL_TEMP
iter=0

while (( $(awk "BEGIN {print ($temperature > $MIN_TEMP)}") )) && [ $iter -lt $MAX_ITERATIONS ]; do
    ((iter++))
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Iteration $iter | Temp: $(printf '%.1f' $temperature)"
    
    # Generate neighbor (perturb one dimension)
    if [ $((RANDOM % 2)) -eq 0 ]; then
        new_clients=$((current_clients + RANDOM % 20 - 10))
        new_requests=$current_requests
    else
        new_clients=$current_clients
        new_requests=$((current_requests + RANDOM % 40 - 20))
    fi
    
    # Bounds
    [ $new_clients -lt 5 ] && new_clients=5
    [ $new_clients -gt 100 ] && new_clients=100
    [ $new_requests -lt 10 ] && new_requests=10
    [ $new_requests -gt 200 ] && new_requests=200
    
    new_load=$((new_clients * new_requests))
    
    echo "→ Testing: ${new_clients}c × ${new_requests}r = ${new_load}"
    new_success=$(test_load $new_clients $new_requests)
    
    if (( $(awk "BEGIN {print ($new_success >= $SUCCESS_THRESHOLD)}") )); then
        new_energy=$(awk "BEGIN {print -$new_load}")
    else
        new_energy=$(awk "BEGIN {print -$new_load * ($new_success / 100)}")
    fi
    
    echo "  Success: ${new_success}% | Energy: $(printf '%.0f' $new_energy)"
    
    # Accept?
    if (( $(awk "BEGIN {print ($new_energy < $current_energy)}") )); then
        accept=1
        prob=1.0
    else
        delta=$(awk "BEGIN {print $new_energy - $current_energy}")
        prob=$(awk "BEGIN {print exp(-$delta / $temperature)}")
        random=$(awk "BEGIN {print rand()}")
        if (( $(awk "BEGIN {print ($random < $prob)}") )); then
            accept=1
        else
            accept=0
        fi
    fi
    
    if [ $accept -eq 1 ]; then
        echo "  ✓ Accepted (p=$(printf '%.3f' $prob))"
        current_clients=$new_clients
        current_requests=$new_requests
        current_load=$new_load
        current_success=$new_success
        current_energy=$new_energy
        
        if (( $(awk "BEGIN {print ($current_energy < $best_energy)}") )); then
            best_clients=$current_clients
            best_requests=$current_requests
            best_load=$current_load
            best_success=$current_success
            best_energy=$current_energy
            echo "  ★ New best!"
        fi
    else
        echo "  ✗ Rejected (p=$(printf '%.3f' $prob))"
    fi
    
    echo "  Best so far: ${best_clients}c × ${best_requests}r = ${best_load} @ ${best_success}%"
    echo ""
    
    temperature=$(awk "BEGIN {print $temperature * $COOLING_RATE}")
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                   BREAKING POINT FOUND                     ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Maximum Sustainable Load:"
echo "  Concurrent Clients:    ${best_clients}"
echo "  Requests per Client:   ${best_requests}"
echo "  Total Requests:        ${best_load}"
echo "  Success Rate:          ${best_success}%"
echo ""
echo "Capacity Recommendations:"
safe=$((best_load * 80 / 100))
monitor=$((best_load * 70 / 100))
scale=$((best_load * 90 / 100))
echo "  Safe operation (80%):  ${safe} requests"
echo "  Monitor above (70%):   ${monitor} requests"
echo "  Scale before (90%):    ${scale} requests"
echo ""
echo "✅ Analysis complete!"
