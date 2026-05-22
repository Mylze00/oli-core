#!/bin/bash

# =====================================================
# 🎨 SCRIPT DE DÉMARRAGE - oli_seller
# =====================================================
# Usage: ./dev.sh (depuis oli_seller/)
# Résultat: Vérification env + démarrage Vite dev server

set -e

# Couleurs
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# =====================================================
# VÉRIFICATIONS
# =====================================================

print_header "Vérification oli_seller"

if [ ! -f "package.json" ]; then
    echo "❌ Erreur: package.json non trouvé"
    echo "   Exécute ce script depuis le répertoire oli_seller/"
    exit 1
fi

print_success "package.json trouvé"

# Vérifier .env.local
if [ ! -f ".env.local" ]; then
    echo "⚠️  .env.local manquant"
    if [ -f ".env.example" ]; then
        cp .env.example .env.local
        print_success ".env.local créé depuis .env.example"
    else
        echo "⚠️  Création .env.local minimal..."
        cat > .env.local << 'EOF'
VITE_OPENROUTER_API_KEY=sk-or-v1-YOUR_KEY
VITE_API_URL=http://localhost:5000
EOF
    fi
else
    print_success ".env.local trouvé"
fi

# Vérifier OPENROUTER_API_KEY
if grep -q "VITE_OPENROUTER_API_KEY" .env.local; then
    KEY=$(grep "VITE_OPENROUTER_API_KEY" .env.local | cut -d'=' -f2)
    if [ "$KEY" != "sk-or-v1-YOUR_KEY" ] && [ ! -z "$KEY" ]; then
        print_success "Clé OpenRouter configurée ✓"
    else
        echo "⚠️  Clé OpenRouter vide ou placeholder"
        echo "   Édite .env.local et ajoute ta vraie clé"
    fi
fi

# Vérifier node_modules
if [ ! -d "node_modules" ]; then
    print_header "Installation dépendances"
    npm install
else
    print_success "node_modules trouvé"
fi

# =====================================================
# DÉMARRAGE
# =====================================================

print_header "Démarrage dev server Vite"
echo ""
echo "🌐 URL locale: http://localhost:5173"
echo "🔌 Backend: http://localhost:5000 (assurez-vous qu'il tourne)"
echo ""

npm run dev

