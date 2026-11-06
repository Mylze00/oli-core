-- =====================================================
-- Migration 047 : billetterie O-Ticket
-- =====================================================
-- Ajout non destructif : trois nouvelles tables, aucune donnée existante touchée.

CREATE TABLE IF NOT EXISTS events (
    id            SERIAL PRIMARY KEY,
    title         VARCHAR(200) NOT NULL,
    subtitle      TEXT,
    category      VARCHAR(30)  NOT NULL DEFAULT 'concert',
    event_date    DATE         NOT NULL,
    event_time    VARCHAR(10),
    location      VARCHAR(255) NOT NULL,
    image_url     TEXT,
    organizer_id  INTEGER REFERENCES users(id) ON DELETE SET NULL,
    status        VARCHAR(20)  NOT NULL DEFAULT 'draft',
    created_at    TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMP    NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_event_status   CHECK (status IN ('draft','published','cancelled','finished')),
    CONSTRAINT chk_event_category CHECK (category IN ('concert','cinema','sport','conference','festival','autre'))
);

CREATE TABLE IF NOT EXISTS event_ticket_types (
    id             SERIAL PRIMARY KEY,
    event_id       INTEGER NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    name           VARCHAR(100)   NOT NULL,
    price_fc       NUMERIC(14,2)  NOT NULL DEFAULT 0,
    quantity_total INTEGER        NOT NULL DEFAULT 0,
    quantity_sold  INTEGER        NOT NULL DEFAULT 0,
    created_at     TIMESTAMP      NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_tt_price CHECK (price_fc >= 0),
    CONSTRAINT chk_tt_qty   CHECK (quantity_total >= 0 AND quantity_sold >= 0)
);

CREATE TABLE IF NOT EXISTS event_tickets (
    id             SERIAL PRIMARY KEY,
    ticket_code    VARCHAR(64) UNIQUE NOT NULL,
    event_id       INTEGER NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    ticket_type_id INTEGER REFERENCES event_ticket_types(id) ON DELETE SET NULL,
    buyer_id       INTEGER REFERENCES users(id) ON DELETE SET NULL,
    seat_label     VARCHAR(100),
    price_paid_fc  NUMERIC(14,2) NOT NULL DEFAULT 0,
    status         VARCHAR(20)   NOT NULL DEFAULT 'valid',
    used_at        TIMESTAMP,
    created_at     TIMESTAMP     NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_ticket_status CHECK (status IN ('valid','used','cancelled','refunded'))
);

CREATE INDEX IF NOT EXISTS idx_events_status   ON events(status, event_date DESC);
CREATE INDEX IF NOT EXISTS idx_tt_event        ON event_ticket_types(event_id);
CREATE INDEX IF NOT EXISTS idx_tickets_event   ON event_tickets(event_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_tickets_buyer   ON event_tickets(buyer_id);
CREATE INDEX IF NOT EXISTS idx_tickets_code    ON event_tickets(ticket_code);
