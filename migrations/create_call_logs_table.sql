CREATE TABLE IF NOT EXISTS call_logs (
    id SERIAL PRIMARY KEY,
    caller_id INT REFERENCES users(id) ON DELETE CASCADE,
    receiver_id INT REFERENCES users(id) ON DELETE CASCADE,
    call_type VARCHAR(20) DEFAULT 'audio',
    status VARCHAR(20) DEFAULT 'missed', -- 'missed', 'answered', 'rejected', 'cancelled'
    duration_seconds INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ended_at TIMESTAMP
);
