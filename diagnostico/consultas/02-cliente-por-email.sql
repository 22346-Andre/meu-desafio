EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM clientes WHERE lower(email) = lower('Cliente4@Exemplo.com') ORDER BY id;
