#!/bin/bash

# =====================================================
# 🚀 SCRIPT DE DÉMARRAGE AUTOMATISÉ - oli-core
# =====================================================
# Usage: ./startup.sh
# Résultat: Vérification complète + démarrage backend

set -e  # Exit on error

# Couleurs pour output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =====================================================
# FONCTIONS UTILITAIRES
# =====================================================

print_header() {
    echo -e "\n${BLUE}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# =====================================================
# PHASE 1: VÉRIFICATIONS DE BASE
# =====================================================

print_header "PHASE 1: Vérifications de base"

# Vérifier qu'on est dans le bon répertoire
if [ ! -f "package.json" ]; then
    print_error "package.json non trouvé. Assurez-vous d'être dans ~/oli-core"
    exit 1
fi
print_success "Répertoire: $(pwd)"

# Vérifier Node.js
if ! command -v node &> /dev/null; then
    print_error "Node.js non installé"
    exit 1
fi
NODE_VERSION=$(node --version)
print_success "Node.js: $NODE_VERSION"

# Vérifier npm
if ! command -v npm &> /dev/null; then
    print_error "npm non installé"
    exit 1
fi
NPM_VERSION=$(npm --version)
print_success "npm: $NPM_VERSION"

# =====================================================
# PHASE 2: VÉRIFICATIONS ENV
# =====================================================

print_header "PHASE 2: Configuration d'environnement"

# Vérifier .env.local
if [ ! -f ".env.local" ]; then
    print_warning ".env.local manquant"
    if [ -f ".env.example" ]; then
        print_warning "Copie depuis .env.example..."
        cp .env.example .env.local
        print_success ".env.local créé (À compléter!)"
    fi
else
    print_success ".env.local trouvé"
fi

# Vérifier clés critiques
if grep -q "OPENROUTER_API_KEY" .env.local; then
    print_success "OPENROUTER_API_KEY configurée"
else
    print_error "OPENROUTER_API_KEY manquante dans .env.local"
fi

if grep -q "DB_HOST" .env.local; then
    print_success "DB_HOST configurée"
else
    print_error "DB_HOST manquante dans .env.local"
fi

# =====================================================
# PHASE 3: VÉRIFIER INFRASTRUCTURE
# =====================================================

print_header "PHASE 3: État Infrastructure"

# Backend Render
print_warning "Vérification backend Render..."
if timeout 5 curl -s https://oli-core.onrender.com/health > /dev/null 2>&1; then
    print_success "Backend Render: LIVE ✓"
else
    print_warning "Backend Render: Peut être DOWN ou en démarrage"
fi

# PostgreSQL
print_warning "Vérification base de données..."
if command -v psql &> /dev/null; then
    if psql -h dpg-d5f5o9q4d50c73chl7ng-a.onrender.com -U oli_db_user -d oli_db -c "SELECT 1" > /dev/null 2>&1; then
        print_success "PostgreSQL: ACCESSIBLE ✓"
    else
        print_warning "PostgreSQL: INACCESSIBLE (Vérifier credentials .env.local)"
    fi
else
    print_warning "psql non installé (install: sudo apt-get install postgresql-client)"
fi

# Vercel
print_warning "Vérification Vercel Apps..."
if timeout 5 curl -s https://oli-seller.vercel.app > /dev/null 2>&1; then
    print_success "oli_seller: LIVE ✓"
else
    print_warning "oli_seller: Peut être DOWN"
fi

# =====================================================
# PHASE 4: DÉPENDANCES
# =====================================================

print_header "PHASE 4: Installation dépendances"

if [ -d "node_modules" ]; then
    print_success "node_modules trouvé (skip install)"
    read -p "Forcer réinstall? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Suppression node_modules..."
        rm -rf node_modules package-lock.json
        npm install
    fi
else
    print_warning "Installation node_modules..."
    npm install
fi

# =====================================================
# PHASE 5: MIGRATIONS
# =====================================================

print_header "PHASE 5: Vérification migrations DB"

# Vérifier table user_avatar_history
if command -v psql &> /dev/null; then
    AVATAR_TABLE=$(psql -h dpg-d5f5o9q4d50c73chl7ng-a.onrender.com -U oli_db_user -d oli_db \
                       -c "\dt user_avatar_history" 2>/dev/null | grep -c user_avatar_history || echo 0)
    
    if [ "$AVATAR_TABLE" -gt 0 ]; then
        print_success "Table user_avatar_history: EXISTS ✓"
        
        # Compter avatars
        COUNT=$(psql -h dpg-d5f5o9q4d50c73chl7ng-a.onrender.com -U oli_db_user -d oli_db \
                     -c "SELECT COUNT(*) FROM user_avatar_history" 2>/dev/null | tail -1 | xargs || echo "0")
        echo "   Avatars migrés: $COUNT"
    else
        print_warning "Table user_avatar_history: MANQUANTE"
        read -p "Créer la table maintenant? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if [ -f "fix_avatar_history_table.sql" ]; then
                print_warning "Exécution migration..."
                psql -h dpg-d5f5o9q4d50c73chl7ng-a.onrender.com \
                     -U oli_db_user -d oli_db \
                     -f fix_avatar_history_table.sql
                print_success "Migration complétée"
            fi
        fi
    fi
else
    print_warning "psql non disponible (skip vérification migrations)"
fi

# =====================================================
# PHASE 6: STATUS FINAL
# =====================================================

print_header "PHASE 6: Résumé"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  📊 STATUS SYSTÈME"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✓ Répertoire: $(pwd)"
echo "✓ Node.js: $NODE_VERSION"
echo "✓ npm: $NPM_VERSION"
echo "✓ Configuration: .env.local présent"
echo ""
echo "🌐 Infrastructure:"
echo "  • Backend Render: https://oli-core.onrender.com"
echo "  • Database PostgreSQL: dpg-d5f5o9q4d50c73chl7ng-a.onrender.com"
echo "  • Vercel Seller: https://oli-seller.vercel.app"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# =====================================================
# PRÊT À DÉMARRER?
# =====================================================

echo ""
read -p "Démarrer le backend maintenant? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_header "DÉMARRAGE BACKEND"
    echo ""
    echo "🚀 npm run dev"
    echo ""
    npm run dev
else
    print_header "Prêt à démarrer"
    echo ""
    echo "Pour démarrer le backend, exécute:"
    echo "  npm run dev"
    echo ""
    echo "Pour oli_seller (dans nouveau terminal):"
    echo "  cd oli_seller && npm run dev"
    echo ""
fi

