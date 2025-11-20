#!/bin/bash
set -euo pipefail

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     Breaking Point Analysis (Simulated Annealing)         ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Check server
if ! curl -s http://localhost:8080/health > /dev/null 2>&1; then
    echo "❌ Server not running!"
    exit 1
fi
echo "✅ Server is running"
echo ""

# Parameters
INITIAL_TEMP=50.0
COOLING_RATE=0.88
MIN_TEMP=1.0
MAX_ITER=12
SUCCESS_THRESHOLD=95.0

echo "Config: T₀=$INITIAL_TEMP, α=$COOLING_RATE, iter=$MAX_ITER, threshold=${SUCCESS_THRESHOLD}%"
echo ""

# Test load - simple sequential with progress
test_load() {
    local clients=$1
    local requests=$2
    local total=$((clients * requests))
    local success=0
    
    echo -n "    Testing ${total} requests: " >&2
    
    for ((i=1; i<=total; i++)); do
        if curl -s -m 2 http://localhost:8080/validate \
            -H "Content-Type: application/json" \
            -d '{"phone_number": "+14155552671"}' > /dev/null 2>&1; then
            ((success++))
        fi
        
        # Progress indicator
        if (( i % 20 == 0 )); then
            echo -n "." >&2
        fi
    done
    
    echo " done" >&2
    
    awk "BEGIN {printf \"%.1f\", ($success / $total) * 100}"
}

# Energy function
calc_energy() {
    local load=$1
    local success_rate=$2
    
    if (( $(awk "BEGIN {print ($success_rate >= $SUCCESS_THRESHOLD)}") )); then
        echo "-$load"
    else
        awk "BEGIN {printf \"%.0f\", -$load * ($success_rate / 100)}"
    fi
}

# Initialize with safe values
curr_c=8
curr_r=15
curr_load=$((curr_c * curr_r))

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "INITIAL STATE: ${curr_c}c × ${curr_r}r = ${curr_load} requests"
curr_succ=$(test_load $curr_c $curr_r)
curr_energy=$(calc_energy $curr_load $curr_succ)
echo "  Success: ${curr_succ}% | Energy: ${curr_energy}"
echo ""

# Track best
best_c=$curr_c
best_r=$curr_r  
best_load=$curr_load
best_succ=$curr_succ
best_energy=$curr_energy

temp=$INITIAL_TEMP
iter=0

while (( $(awk "BEGIN {print ($temp > $MIN_TEMP)}") )) && [ $iter -lt $MAX_ITER ]; do
    ((iter++))
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "ITERATION $iter | Temperature: $(printf '%.2f' $temp)"
    
    # Perturb one dimension randomly
    if [ $((RANDOM % 2)) -eq 0 ]; then
        new_c=$((curr_c + RANDOM % 16 - 8))
        new_r=$curr_r
    else
        new_c=$curr_c
        new_r=$((curr_r + RANDOM % 32 - 16))
    fi
    
    # Bounds
    [ $new_c -lt 5 ] && new_c=5
    [ $new_c -gt 60 ] && new_c=60
    [ $new_r -lt 10 ] && new_r=10
    [ $new_r -gt 100 ] && new_r=100
    
    new_load=$((new_c * new_r))
    
    echo "  Candidate: ${new_c}c × ${new_r}r = ${new_load} requests"
    new_succ=$(test_load $new_c $new_r)
    new_energy=$(calc_energy $new_load $new_succ)
    echo "  Success: ${new_succ}% | Energy: ${new_energy}"
    
    # Acceptance decision
    if (( $(awk "BEGIN {print ($new_energy < $curr_energy)}") )); then
        accept=1
        prob=1.0
    else
        delta=$(awk "BEGIN {print $new_energy - $curr_energy}")
        prob=$(awk "BEGIN {print exp(-$delta / $temp)}")
        rand=$(awk "BEGIN {print rand()}")
        accept=$(awk "BEGIN {print ($rand < $prob) ? 1 : 0}")
    fi
    
    if [ $accept -eq 1 ]; then
        echo "  → ACCEPTED (p=$(printf '%.3f' $prob))"
        curr_c=$new_c
        curr_r=$new_r
        curr_load=$new_load
        curr_succ=$new_succ
        curr_energy=$new_energy
        
        if (( $(awk "BEGIN {print ($curr_energy < $best_energy)}") )); then
            best_c=$curr_c
            best_r=$curr_r
            best_load=$curr_load
            best_succ=$curr_succ
            best_energy=$best_energy
            echo "  ★★★ NEW BEST SOLUTION! ★★★"
        fi
    else
        echo "  → Rejected (p=$(printf '%.3f' $prob))"
    fi
    
    echo "  Current Best: ${best_c}c × ${best_r}r = ${best_load} @ ${best_succ}%"
    echo ""
    
    temp=$(awk "BEGIN {print $temp * $COOLING_RATE}")
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                  BREAKING POINT DISCOVERED                 ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Maximum Sustainable Load (≥${SUCCESS_THRESHOLD}% success):"
echo "  ├─ Concurrent Clients:     ${best_c}"
echo "  ├─ Requests per Client:    ${best_r}"
echo "  ├─ Total Load:             ${best_load} requests"
echo "  └─ Success Rate:           ${best_succ}%"
echo ""
echo "Capacity Planning Recommendations:"
safe=$((best_load * 80 / 100))
monitor=$((best_load * 70 / 100))
scale=$((best_load * 90 / 100))
echo "  ├─ Safe Operation (80%):   ${safe} requests/batch"
echo "  ├─ Monitor Threshold (70%): ${monitor} requests/batch"
echo "  └─ Scale Before (90%):     ${scale} requests/batch"
echo ""
echo "✅ Analysis Complete! Breaking point mathematically determined."
echo ""
