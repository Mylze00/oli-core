-- Migration : un transfert d'argent ne peut produire qu'un seul billet dans la messagerie
-- Le serveur applique aussi ces changements au démarrage (server.js).

CREATE UNIQUE INDEX IF NOT EXISTS idx_messages_cash_transfer_reference
    ON messages ((metadata->'cash_transfer'->>'reference'))
    WHERE metadata ? 'cash_transfer';
