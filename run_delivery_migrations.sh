#!/bin/bash
# =====================================================
# Script d'Exécution Sécurisée - Migrations Delivery
# =====================================================
# Usage: ./run_delivery_migrations.sh [local|production]
# =====================================================

set -e  # Arrêt si erreur

ENVIRONMENT=${1:-local}

# Couleurs pour output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Migration Système de Livraison${NC}"
echo -e "${BLUE}Environnement: ${ENVIRONMENT}${NC}"
echo ""

# =====================================================
# CONFIGURATION DATABASE
# =====================================================
if [ "$ENVIRONMENT" = "local" ]; then
    DB_HOST="127.0.0.1"
    DB_PORT="5432"
    DB_NAME="oli_db"
    DB_USER="postgres"
    DB_PASSWORD="PIXELcongo243"
    DATABASE_URL="postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}"
elif [ "$ENVIRONMENT" = "production" ]; then
    # Sur Render, DATABASE_URL est déjà défini dans les env vars
    if [ -z "$DATABASE_URL" ]; then
        echo -e "${RED}❌ ERREUR: DATABASE_URL n'est pas défini${NC}"
        echo "Exécutez: export DATABASE_URL='postgresql://...'"
        exit 1
    fi
else
    echo -e "${RED}❌ Environnement invalide: ${ENVIRONMENT}${NC}"
    echo "Usage: $0 [local|production]"
    exit 1
fi

# =====================================================
# ÉTAPE 1: BACKUP
# =====================================================
echo -e "${YELLOW}📦 Étape 1/4: Création du backup...${NC}"

BACKUP_DIR="./backups"
mkdir -p $BACKUP_DIR

BACKUP_FILE="${BACKUP_DIR}/backup_delivery_$(date +%Y%m%d_%H%M%S).sql"

pg_dump "$DATABASE_URL" > "$BACKUP_FILE" 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Backup créé: ${BACKUP_FILE}${NC}"
else
    echo -e "${RED}❌ Échec du backup - ARRÊT${NC}"
    exit 1
fi

echo ""

# =====================================================
# ÉTAPE 2: VÉRIFICATION PRÉ-MIGRATION
# =====================================================
echo -e "${YELLOW}🔍 Étape 2/4: Vérification des tables existantes...${NC}"

psql "$DATABASE_URL" -t -c "
SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'deliveries') 
        THEN 'EXISTE DÉJÀ'
        ELSE 'OK - À créer'
    END as deliveries_status,
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'orders' AND column_name = 'deliverer_id')
        THEN 'EXISTE DÉJÀ'
        ELSE 'OK - À ajouter'
    END as deliverer_id_status;
"

echo ""
read -p "Continuer la migration? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}⚠️ Migration annulée${NC}"
    exit 0
fi

# =====================================================
# ÉTAPE 3: EXÉCUTION MIGRATIONS
# =====================================================
echo ""
echo -e "${YELLOW}📊 Étape 3/4: Exécution des migrations...${NC}"

# Migration 026
echo -e "${BLUE}  → Migration 026: Table deliveries${NC}"
psql "$DATABASE_URL" -f src/migrations/026_create_deliveries_table.sql

# Migration 027
echo -e "${BLUE}  → Migration 027: Deliverer dans orders${NC}"
psql "$DATABASE_URL" -f src/migrations/027_add_deliverer_to_orders.sql

echo -e "${GREEN}✅ Migrations exécutées${NC}"
echo ""

# =====================================================
# ÉTAPE 4: VÉRIFICATION POST-MIGRATION
# =====================================================
echo -e "${YELLOW}🔍 Étape 4/4: Vérification finale...${NC}"

VERIFICATION=$(psql "$DATABASE_URL" -t -A -c "
SELECT COUNT(*) 
FROM information_schema.tables 
WHERE table_name = 'deliveries';
")

if [ "$VERIFICATION" = "1" ]; then
    echo -e "${GREEN}✅ Table deliveries créée${NC}"
else
    echo -e "${RED}❌ Table deliveries NON créée${NC}"
    exit 1
fi

DELIVERER_COL=$(psql "$DATABASE_URL" -t -A -c "
SELECT COUNT(*) 
FROM information_schema.columns 
WHERE table_name = 'orders' AND column_name = 'deliverer_id';
")

if [ "$DELIVERER_COL" = "1" ]; then
    echo -e "${GREEN}✅ Colonne deliverer_id ajoutée${NC}"
else
    echo -e "${RED}❌ Colonne deliverer_id NON ajoutée${NC}"
    exit 1
fi

# =====================================================
# RÉSUMÉ FINAL
# =====================================================
echo ""
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ MIGRATION RÉUSSIE${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo ""
echo -e "📦 Backup: ${BACKUP_FILE}"
echo -e "📊 Tables modifiées:"
echo -e "   ✅ deliveries (créée)"
echo -e "   ✅ orders (+ deliverer_id)"
echo ""
echo -e "📍 Prochaines étapes:"
echo -e "   1. Tester: curl https://oli-core.onrender.com/orders/delivery"
echo -e "   2. Créer endpoint assign-deliverer"
echo -e "   3. Déployer oli_delivery app"
echo ""
echo -e "${GREEN}════════════════════════════════════════${NC}"
