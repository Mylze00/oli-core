import json

with open('/tmp/products_response.json') as f:
    d = json.load(f)

prods = d.get('products', []) if isinstance(d, dict) else d
print(f'Total products returned: {len(prods)}')
print(f'hasMore: {d.get("hasMore")}')
print(f'limit: {d.get("limit")}')
print(f'offset: {d.get("offset")}')

# All unique sellers (handle None)
sellers = set()
for p in prods:
    s = p.get('sellerName') or 'None'
    sellers.add(s)

print(f'\nUnique sellers ({len(sellers)}):')
for s in sorted(sellers):
    count = len([p for p in prods if (p.get('sellerName') or 'None') == s])
    print(f'  {s} ({count} products)')

# Check if any product matches chaussure
print('\nSearching for chaussure...')
for p in prods:
    name = (p.get('name') or '').lower()
    if 'chaussure' in name or 'chaussur' in name:
        print(f'  FOUND: id={p.get("id")} name={p.get("name")}')

# Print last 5 products (oldest in the list)
print('\nLast 5 products (oldest):')
for p in prods[-5:]:
    print(f'  id={p.get("id")} name={p.get("name")} seller={p.get("sellerName")} created={p.get("createdAt")}')

# Print first 3 products (newest)
print('\nFirst 3 products (newest):')
for p in prods[:3]:
    print(f'  id={p.get("id")} name={p.get("name")} seller={p.get("sellerName")} created={p.get("createdAt")}')
