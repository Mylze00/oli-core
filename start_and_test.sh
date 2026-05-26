#!/bin/bash

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║   🚀 DÉMARRAGE DU SYSTÈME ET TESTS WALLET OLI            ║"
echo "║   Numéro de test : +243827088682                         ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

cd /home/paolice-mylze/oli-core

# Vérifier si le serveur est déjà en cours d'exécution
if curl -s http://localhost:5000/health > /dev/null 2>&1; then
    echo "✅ Le serveur est déjà démarré !"
    SKIP_START=true
else
    echo "🚀 Démarrage du serveur OLI..."
    SKIP_START=false
    
    # Démarrer le serveur en arrière-plan
    npm start > /tmp/oli-server.log 2>&1 &
    SERVER_PID=$!
    
    echo "   PID du serveur : $SERVER_PID"
    echo "   Logs : /tmp/oli-server.log"
    
    echo ""
    echo "⏳ Attente du démarrage du serveur..."
    
    # Attendre jusqu'à 30 secondes que le serveur démarre
    COUNTER=0
    MAX_WAIT=30
    while [ $COUNTER -lt $MAX_WAIT ]; do
        if curl -s http://localhost:5000/health > /dev/null 2>&1; then
            echo "✅ Serveur démarré avec succès après ${COUNTER}s !"
            break
        fi
        sleep 1
        COUNTER=$((COUNTER + 1))
        echo -n "."
    done
    
    echo ""
    
    # Vérifier si le serveur a bien démarré
    if ! curl -s http://localhost:5000/health > /dev/null 2>&1; then
        echo "❌ Le serveur n'a pas démarré correctement après ${MAX_WAIT}s."
        echo ""
        echo "📋 Dernières lignes des logs :"
        tail -20 /tmp/oli-server.log
        
        if [ ! -z "$SERVER_PID" ]; then
            kill $SERVER_PID 2>/dev/null
        fi
        exit 1
    fi
fi

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║   🧪 LANCEMENT DES TESTS WALLET                          ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Lancer les tests
node test_wallet_operations.js
TEST_EXIT=$?

echo ""

# Si on a démarré le serveur, l'arrêter
if [ "$SKIP_START" = false ]; then
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║   🛑 ARRÊT DU SERVEUR                                    ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    
    if [ ! -z "$SERVER_PID" ]; then
        kill $SERVER_PID 2>/dev/null
        echo "✅ Serveur arrêté (PID: $SERVER_PID)"
    fi
else
    echo "ℹ️  Le serveur était déjà démarré, il reste en cours d'exécution."
fi

echo ""

# Résumé final
if [ $TEST_EXIT -eq 0 ]; then
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║   ✅ TOUS LES TESTS ONT RÉUSSI !                         ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
else
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║   ⚠️  CERTAINS TESTS ONT ÉCHOUÉ                          ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
fi

echo ""
echo "📊 Pour vérifier les données en base :"
echo "   psql \$DATABASE_URL -c \"SELECT * FROM users WHERE phone = '+243827088682';\""
echo ""
echo "📋 Pour voir les logs complets du serveur :"
echo "   cat /tmp/oli-server.log"
echo ""

exit $TEST_EXIT
