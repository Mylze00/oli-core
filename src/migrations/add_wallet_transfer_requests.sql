-- Migration : clés anti-doublon des transferts P2P
-- L'app envoie une clé unique par envoi (Idempotency-Key). Si la même requête
-- revient (nouvelle tentative réseau, double appui), le serveur renvoie le
-- résultat déjà enregistré au lieu de débiter une seconde fois.
-- Le serveur applique aussi cette migration au démarrage (server.js).

CREATE TABLE IF NOT EXISTS wallet_transfer_requests (
    sender_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    idempotency_key VARCHAR(80) NOT NULL,
    result JSONB,                         -- NULL tant que le transfert est en cours
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (sender_id, idempotency_key)
);

-- Nettoyage : une clé n'a d'utilité que quelques minutes.
CREATE INDEX IF NOT EXISTS idx_wallet_transfer_requests_created
    ON wallet_transfer_requests (created_at);

-- Les clés de plus de 2 jours ne servent plus : purge à chaque démarrage.
DELETE FROM wallet_transfer_requests WHERE created_at < NOW() - INTERVAL '2 days';
