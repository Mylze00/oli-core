#!/bin/bash

# 1. Démarrer le serveur en arrière-plan
echo "🚀 Démarrage du serveur temporaire..."
PORT=3000 node src/server.js > /dev/null 2>&1 &
SERVER_PID=$!

# 2. Attendre que le serveur soit prêt (5 secondes)
echo "⏳ Attente du lancement (5s)..."
sleep 5

# 3. Lancer le test
echo "▶️ Lancement du script de test..."
node test_payment_simulation.js

# 4. Arrêter le serveur
echo "🛑 Arrêt du serveur temporaire..."
kill $SERVER_PID
