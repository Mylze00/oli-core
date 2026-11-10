-- Migration : demandes de remboursement soumises à la décision d'un administrateur
-- Le serveur applique aussi ces changements au démarrage (server.js).

CREATE TABLE IF NOT EXISTS disputes (
    id SERIAL PRIMARY KEY,
    order_id INTEGER REFERENCES orders(id) ON DELETE CASCADE,
    reporter_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    target_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    reason TEXT NOT NULL,
    description TEXT,
    status VARCHAR(20) DEFAULT 'open' CHECK (status IN ('open', 'resolved', 'rejected')),
    resolution_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE disputes
    ADD COLUMN IF NOT EXISTS type VARCHAR(30) NOT NULL DEFAULT 'general',
    ADD COLUMN IF NOT EXISTS request_phase VARCHAR(20),
    ADD COLUMN IF NOT EXISTS resolved_by INTEGER REFERENCES users(id),
    ADD COLUMN IF NOT EXISTS resolved_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS refund_amount_fc NUMERIC(18,2);

CREATE UNIQUE INDEX IF NOT EXISTS ux_disputes_refund_phase
    ON disputes(order_id, request_phase)
    WHERE type = 'refund_request';
