#!/bin/bash
set -euo pipefail

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  PhoneCheck Breaking Point Analysis (Simulated Annealing) ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Check if server is running
if ! curl -s http://localhost:8080/health > /dev/null 2>&1; then
    echo "❌ Server is not running!"
    exit 1
fi

# Simulated Annealing Parameters
INITIAL_TEMP=100.0
COOLING_RATE=0.95
MIN_TEMP=0.1
MAX_ITERATIONS=50

# Acceptable success rate threshold (95%)
SUCCESS_THRESHOLD=95.0

# State: (concurrent_clients, requests_per_client)
# We optimize for maximum load while maintaining >95% success

# Function to run load test and measure success rate
run_load_test() {
    local clients=$1
    local requests=$2
    local total_requests=$((clients * requests))
    
    echo "  Testing: ${clients} clients × ${requests} requests = ${total_requests} total" >&2
    
    # Run the load test
    local success=0
    local failed=0
    
    # Function to send requests for one client
    send_client_requests() {
        local client_success=0
        local client_failed=0
        
        for i in $(seq 1 $requests); do
            if curl -s -X POST http://localhost:8080/validate \
                -H "Content-Type: application/json" \
                -d '{"phone_number": "+14155552671"}' \
                --max-time 5 > /dev/null 2>&1; then
                ((client_success++))
            else
                ((client_failed++))
            fi
        done
        
        echo "$client_success,$client_failed"
    }
    
    export -f send_client_requests
    export requests
    
    # Run clients in parallel
    local results=$(seq 1 $clients | xargs -P $clients -I {} bash -c 'send_client_requests' 2>/dev/null)
    
    # Aggregate results
    while IFS=',' read -r s f; do
        success=$((success + s))
        failed=$((failed + f))
    done <<< "$results"
    
    local total=$((success + failed))
    if [ $total -eq 0 ]; then
        echo "0"
        return
    fi
    
    # Calculate success rate
    local success_rate=$(awk "BEGIN {printf \"%.2f\", ($success / $total) * 100}")
    echo "$success_rate"
}

# Energy function: we want to maximize load while keeping success rate > threshold
# Energy = -load (if success_rate >= threshold) or -load * (success_rate/100) (if below)
calculate_energy() {
    local clients=$1
    local requests=$2
    local success_rate=$3
    
    local load=$((clients * requests))
    
    # If success rate is acceptable, energy is negative load (we want to maximize load)
    # If success rate is unacceptable, penalize heavily
    if (( $(awk "BEGIN {print ($success_rate >= $SUCCESS_THRESHOLD)}") )); then
        # Good performance - energy is negative of load (lower energy = higher load)
        echo "-$load"
    else
        # Poor performance - heavy penalty
        local penalty=$(awk "BEGIN {printf \"%.0f\", -$load * ($success_rate / 100.0)}")
        echo "$penalty"
    fi
}

# Generate neighbor state
generate_neighbor() {
    local clients=$1
    local requests=$2
    
    # Randomly perturb one dimension
    if [ $((RANDOM % 2)) -eq 0 ]; then
        # Perturb clients (±1 to ±10)
        local delta=$((RANDOM % 20 - 10))
        clients=$((clients + delta))
    else
        # Perturb requests (±10 to ±50)
        local delta=$((RANDOM % 100 - 50))
        requests=$((requests + delta))
    fi
    
    # Ensure valid bounds
    [ $clients -lt 1 ] && clients=1
    [ $clients -gt 500 ] && clients=500
    [ $requests -lt 10 ] && requests=10
    [ $requests -gt 1000 ] && requests=1000
    
    echo "$clients $requests"
}

# Acceptance probability for simulated annealing
accept_probability() {
    local current_energy=$1
    local new_energy=$2
    local temperature=$3
    
    # If new solution is better (lower energy), always accept
    if (( $(awk "BEGIN {print ($new_energy < $current_energy)}") )); then
        echo "1.0"
        return
    fi
    
    # Otherwise, accept with probability exp(-(new_energy - current_energy) / temperature)
    local prob=$(awk "BEGIN {
        delta = $new_energy - $current_energy;
        if (delta < 0) print 1.0;
        else print exp(-delta / $temperature);
    }")
    
    echo "$prob"
}

# Simulated Annealing Algorithm
echo "→ Starting Simulated Annealing to find breaking point..."
echo ""
echo "Parameters:"
echo "  Initial Temperature: $INITIAL_TEMP"
echo "  Cooling Rate: $COOLING_RATE"
echo "  Minimum Temperature: $MIN_TEMP"
echo "  Success Threshold: ${SUCCESS_THRESHOLD}%"
echo "  Max Iterations: $MAX_ITERATIONS"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Initialize with a safe starting point
current_clients=10
current_requests=50
current_load=$((current_clients * current_requests))

echo "→ Testing initial state..."
current_success_rate=$(run_load_test $current_clients $current_requests)
current_energy=$(calculate_energy $current_clients $current_requests $current_success_rate)

echo "  Initial: ${current_clients} clients × ${current_requests} requests"
echo "  Load: ${current_load} | Success: ${current_success_rate}% | Energy: ${current_energy}"
echo ""

# Track best solution found
best_clients=$current_clients
best_requests=$current_requests
best_load=$current_load
best_success_rate=$current_success_rate
best_energy=$current_energy

# Temperature
temperature=$INITIAL_TEMP
iteration=0

while (( $(awk "BEGIN {print ($temperature > $MIN_TEMP)}") )) && [ $iteration -lt $MAX_ITERATIONS ]; do
    ((iteration++))
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Iteration $iteration | Temperature: $(printf '%.2f' $temperature)"
    echo ""
    
    # Generate neighbor
    read -r new_clients new_requests <<< $(generate_neighbor $current_clients $current_requests)
    new_load=$((new_clients * new_requests))
    
    echo "→ Testing candidate: ${new_clients} clients × ${new_requests} requests (load: ${new_load})"
    
    # Evaluate neighbor
    new_success_rate=$(run_load_test $new_clients $new_requests)
    new_energy=$(calculate_energy $new_clients $new_requests $new_success_rate)
    
    echo "  Success Rate: ${new_success_rate}% | Energy: ${new_energy}"
    
    # Decide whether to accept
    acceptance_prob=$(accept_probability $current_energy $new_energy $temperature)
    random_val=$(awk "BEGIN {print rand()}")
    
    if (( $(awk "BEGIN {print ($random_val < $acceptance_prob)}") )); then
        echo "  ✓ Accepted (prob: $(printf '%.3f' $acceptance_prob))"
        current_clients=$new_clients
        current_requests=$new_requests
        current_load=$new_load
        current_success_rate=$new_success_rate
        current_energy=$new_energy
        
        # Update best if this is better
        if (( $(awk "BEGIN {print ($current_energy < $best_energy)}") )); then
            best_clients=$current_clients
            best_requests=$current_requests
            best_load=$current_load
            best_success_rate=$current_success_rate
            best_energy=$current_energy
            echo "  ★ New best solution!"
        fi
    else
        echo "  ✗ Rejected (prob: $(printf '%.3f' $acceptance_prob))"
    fi
    
    echo ""
    echo "Current best: ${best_clients} clients × ${best_requests} requests = ${best_load} total"
    echo "Best success rate: ${best_success_rate}%"
    echo ""
    
    # Cool down
    temperature=$(awk "BEGIN {print $temperature * $COOLING_RATE}")
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                    BREAKING POINT FOUND                    ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Maximum Sustainable Load:"
echo "  Concurrent Clients:    ${best_clients}"
echo "  Requests per Client:   ${best_requests}"
echo "  Total Requests:        ${best_load}"
echo "  Success Rate:          ${best_success_rate}%"
echo ""
echo "System Capacity:"
echo "  Maximum throughput at ${SUCCESS_THRESHOLD}% success rate"
echo "  Breaking point: ~${best_load} requests"
echo ""

# Verify the breaking point
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "→ Verifying breaking point with 3 test runs..."
echo ""

verify_sum=0
for i in {1..3}; do
    echo "Verification run $i/3..."
    verify_rate=$(run_load_test $best_clients $best_requests)
    verify_sum=$(awk "BEGIN {print $verify_sum + $verify_rate}")
    echo "  Success rate: ${verify_rate}%"
done

verify_avg=$(awk "BEGIN {printf \"%.2f\", $verify_sum / 3}")
echo ""
echo "Average success rate: ${verify_avg}%"

if (( $(awk "BEGIN {print ($verify_avg >= $SUCCESS_THRESHOLD)}") )); then
    echo "✅ Breaking point verified!"
else
    echo "⚠️  Success rate below threshold in verification"
fi

echo ""
echo "Analysis complete. Results saved to breaking_point_analysis.txt"

# Save results
cat > breaking_point_analysis.txt <<EOF
PhoneCheck Breaking Point Analysis
Generated: $(date)

Simulated Annealing Results:
  Iterations: $iteration
  Final Temperature: $temperature

Breaking Point Configuration:
  Concurrent Clients: $best_clients
  Requests per Client: $best_requests
  Total Load: $best_load requests
  Success Rate: $best_success_rate%
  
Verification (3 runs):
  Average Success Rate: $verify_avg%
  
Recommendations:
  - Safe operational load: ~$((best_load * 80 / 100)) requests (80% of max)
  - Monitor closely above: ~$((best_load * 70 / 100)) requests (70% of max)
  - Add capacity before: ~$((best_load * 90 / 100)) requests (90% of max)
EOF

echo ""
echo "Done! 🎯"
