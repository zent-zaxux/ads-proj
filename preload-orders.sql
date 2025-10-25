-- Preload Orders for Capacity and Recovery Testing
-- Simulates backlog from system downtime or crash recovery scenario

-- Clean existing test orders if needed
-- DELETE FROM orders WHERE user_id BETWEEN 9000 AND 9099;

-- Generate 100 PENDING orders with realistic timestamps
-- These represent orders that accumulated during downtime

INSERT INTO orders (user_id, amount, currency, status, created_at, updated_at)
SELECT 
    9000 + series AS user_id,
    ROUND((50 + (random() * 450))::numeric, 2) AS amount,  -- Random amount between 50-500
    'SGD' AS currency,
    'PENDING' AS status,
    NOW() - (INTERVAL '1 minute' * (100 - series)) AS created_at,  -- Spread over last 100 minutes
    NOW() - (INTERVAL '1 minute' * (100 - series)) AS updated_at
FROM generate_series(0, 99) AS series;

-- Verify inserted orders
SELECT 
    COUNT(*) as total_preloaded_orders,
    MIN(created_at) as oldest_order,
    MAX(created_at) as newest_order,
    MIN(user_id) as min_user_id,
    MAX(user_id) as max_user_id,
    SUM(amount) as total_amount
FROM orders 
WHERE user_id BETWEEN 9000 AND 9099;

-- Show status distribution
SELECT status, COUNT(*) as count 
FROM orders 
WHERE user_id BETWEEN 9000 AND 9099
GROUP BY status;
