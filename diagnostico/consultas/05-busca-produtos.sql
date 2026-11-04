EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM produtos WHERE nome ILIKE '%' || 'mesa' || '%' ORDER BY nome, id LIMIT 20;
