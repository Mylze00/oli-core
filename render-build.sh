#!/bin/bash

# Script de déploiement Render avec migration automatique
# Ce script s'exécute après chaque déploiement

echo "🔄 Exécution des migrations de base de données..."
node src/run_migration.js

if [ $? -eq 0 ]; then
    echo "✅ Migrations terminées avec succès"
else
    echo "❌ Erreur lors des migrations"
    exit 1
fi

echo "🚀 Démarrage du serveur..."
