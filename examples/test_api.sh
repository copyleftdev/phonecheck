#!/bin/bash
# Quick bash script to test the PhoneCheck API

API_URL="${API_URL:-http://localhost:8080}"

echo "🧪 Testing PhoneCheck API at $API_URL"
echo ""

# Health check
echo "→ Health Check"
curl -s "$API_URL/health" | jq .
echo ""
echo ""

# Test US number
echo "→ Test US Mobile Number"
curl -s -X POST "$API_URL/validate" \
  -H "Content-Type: application/json" \
  -d '{"phone_number": "+14155552671"}' | jq .
echo ""
echo ""

# Test UK number
echo "→ Test UK Number"
curl -s -X POST "$API_URL/validate" \
  -H "Content-Type: application/json" \
  -d '{"phone_number": "+442071838750", "region": "GB"}' | jq .
echo ""
echo ""

# Test invalid number
echo "→ Test Invalid Number"
curl -s -X POST "$API_URL/validate" \
  -H "Content-Type: application/json" \
  -d '{"phone_number": "+1234"}' | jq .
echo ""
echo ""

echo "✅ Tests complete!"
