-- Migration : taux USD → FC figé sur chaque commande
-- NULL pour les commandes antérieures, débitées sans conversion.
-- Le serveur applique aussi cette colonne au démarrage (server.js).

ALTER TABLE orders ADD COLUMN IF NOT EXISTS exchange_rate NUMERIC(14,4);
