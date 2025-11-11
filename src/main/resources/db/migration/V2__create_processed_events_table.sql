-- Create processed_events table for idempotency tracking
-- This table ensures Kafka messages are not processed twice

CREATE TABLE IF NOT EXISTS processed_events (
    id BIGSERIAL PRIMARY KEY,
    event_id VARCHAR(255) UNIQUE NOT NULL,
    event_type VARCHAR(100) NOT NULL,
    consumer_group VARCHAR(100),
    aggregate_id VARCHAR(500),
    processed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Create index on event_id for fast lookups
CREATE UNIQUE INDEX IF NOT EXISTS idx_processed_events_event_id ON processed_events(event_id);

-- Create index on processed_at for cleanup queries
CREATE INDEX IF NOT EXISTS idx_processed_events_processed_at ON processed_events(processed_at);

-- Add comment to table
COMMENT ON TABLE processed_events IS 'Tracks processed Kafka events to ensure idempotent message processing';
COMMENT ON COLUMN processed_events.event_id IS 'Unique event identifier (UUID) from BaseEvent';
COMMENT ON COLUMN processed_events.event_type IS 'Type of event processed (e.g., ORDER_CREATED, PAYMENT_COMPLETED)';
COMMENT ON COLUMN processed_events.consumer_group IS 'Kafka consumer group that processed the event';
COMMENT ON COLUMN processed_events.aggregate_id IS 'Business entity ID (orderId, paymentId, etc.)';
COMMENT ON COLUMN processed_events.processed_at IS 'Timestamp when event was successfully processed';
