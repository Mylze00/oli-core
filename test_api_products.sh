#!/bin/bash

echo "=== Test Endpoints Oli API ==="
echo ""

API_BASE="https://oli-core.onrender.com"

echo "1. Testing /products/featured (Admin OLI products)..."
curl -s "$API_BASE/products/featured?limit=5" > /tmp/featured.json
FEATURED_COUNT=$(cat /tmp/featured.json | grep -o '"id"' | wc -l)
echo "   ✓ Featured products count: $FEATURED_COUNT"
if [ $FEATURED_COUNT -eq 0 ]; then
    echo "   ⚠️  WARNING: No featured products returned!"
    echo "   Response: $(cat /tmp/featured.json | head -c 500)"
fi
echo ""

echo "2. Testing /products/verified-shops (Certified shops)..."
curl -s "$API_BASE/products/verified-shops?limit=5" > /tmp/verified.json
VERIFIED_COUNT=$(cat /tmp/verified.json | grep -o '"id"' | wc -l)
echo "   ✓ Verified shops products count: $VERIFIED_COUNT"
if [ $VERIFIED_COUNT -eq 0 ]; then
    echo "   ⚠️  WARNING: No verified shop products returned!"
    echo "   Response: $(cat /tmp/verified.json | head -c 500)"
fi
echo ""

echo "3. Testing /products/top-sellers..."
curl -s "$API_BASE/products/top-sellers?limit=5" > /tmp/topsellers.json
TOP_COUNT=$(cat /tmp/topsellers.json | grep -o '"id"' | wc -l)
echo "   ✓ Top sellers count: $TOP_COUNT"
echo ""

echo "4. Testing /products (All products)..."
curl -s "$API_BASE/products?limit=10" > /tmp/allproducts.json
ALL_COUNT=$(cat /tmp/allproducts.json | grep -o '"id"' | wc -l)
echo "   ✓ All products count: $ALL_COUNT"
echo ""

echo "=== Full Response Samples ==="
echo ""
echo "Featured (first product):"
cat /tmp/featured.json | python3 -m json.tool 2>/dev/null | head -50 || cat /tmp/featured.json | head -c 1000
echo ""
echo "Verified Shops (first product):"
cat /tmp/verified.json | python3 -m json.tool 2>/dev/null | head -50 || cat /tmp/verified.json | head -c 1000
