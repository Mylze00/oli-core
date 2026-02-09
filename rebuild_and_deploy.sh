#!/usr/bin/env bash

# Script de rebuild et redéploiement Flutter Web vers Firebase Hosting
set -e

echo "🧹 Étape 1/4: Nettoyage du cache Flutter..."
cd ~/oli-core/oli_app
flutter clean

echo "📦 Étape 2/4: Récupération des dépendances..."
flutter pub get

echo "🔨 Étape 3/4: Build Web (sans WASM)..."
flutter build web --release --no-wasm-dry-run

echo "🚀 Étape 4/4: Déploiement Firebase..."
cd ~/oli-core/oli_app
firebase deploy --only hosting:oli-app

echo "✅ Déploiement terminé avec succès!"
echo "🌐 Visite: https://oli-app.web.app"
