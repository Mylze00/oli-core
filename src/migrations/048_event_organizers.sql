-- =====================================================
-- Migration 048 : organisateurs d'événement et réservation gratuite
-- =====================================================
-- Ajouts non destructifs : une table de liaison et une colonne.

-- Plusieurs organisateurs par événement (identifiés par leur compte Oli).
-- Ce sont eux qui pourront scanner les billets à l'entrée.
CREATE TABLE IF NOT EXISTS event_organizers (
    id         SERIAL PRIMARY KEY,
    event_id   INTEGER NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    user_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    phone      VARCHAR(20),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_event_organizer UNIQUE (event_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_event_organizers_event ON event_organizers(event_id);
CREATE INDEX IF NOT EXISTS idx_event_organizers_user  ON event_organizers(user_id);

-- Événement sur réservation (entrée gratuite) : les billets sont émis sans paiement.
ALTER TABLE events ADD COLUMN IF NOT EXISTS is_free BOOLEAN NOT NULL DEFAULT FALSE;

-- Reprise : l'organisateur principal déjà renseigné devient un organisateur de la table
INSERT INTO event_organizers (event_id, user_id)
SELECT e.id, e.organizer_id
  FROM events e
 WHERE e.organizer_id IS NOT NULL
ON CONFLICT DO NOTHING;
