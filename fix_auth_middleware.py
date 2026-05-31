#!/usr/bin/env python3
import re

filepath = '/home/paolice-mylze/oli-core/src/middlewares/auth.middleware.js'

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

old = 'return res.status(401).json({ error: "Accès refusé - Token requis" });'
new = 'return res.status(401).json({ error: "Token requis", message: "Aucun token d\'authentification fourni" });'

if old in content:
    content = content.replace(old, new)
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print("✅ Corrigé avec succès")
else:
    print("⚠️  Pattern non trouvé — voici les lignes 14-18:")
    for i, line in enumerate(content.split('\n')[13:18], 14):
        print(f"  {i}: {line}")
