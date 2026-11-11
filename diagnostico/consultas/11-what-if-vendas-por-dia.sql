\set ON_ERROR_STOP on
BEGIN;
SET LOCAL max_parallel_workers_per_gather = 0;
\echo '== 1: sem índice novo, random_page_cost padrão'
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF) SELECT p.criado_em::date::text AS dia, count(DISTINCT p.id) AS pedidos, sum(i.quantidade) AS itens, sum(i.quantidade * i.preco_unitario_centavos) AS receita_centavos FROM pedidos p JOIN itens_pedido i ON i.pedido_id = p.id WHERE p.criado_em::date BETWEEN '2024-01-01' AND '2024-01-07' AND p.status <> 'cancelado' GROUP BY p.criado_em::date ORDER BY p.criado_em::date;
SET LOCAL random_page_cost = 1.1;
\echo '== 2: sem índice novo, random_page_cost 1,1'
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF) SELECT p.criado_em::date::text AS dia, count(DISTINCT p.id) AS pedidos, sum(i.quantidade) AS itens, sum(i.quantidade * i.preco_unitario_centavos) AS receita_centavos FROM pedidos p JOIN itens_pedido i ON i.pedido_id = p.id WHERE p.criado_em::date BETWEEN '2024-01-01' AND '2024-01-07' AND p.status <> 'cancelado' GROUP BY p.criado_em::date ORDER BY p.criado_em::date;
RESET random_page_cost;
CREATE INDEX idx_what_if_criado_em_data ON pedidos ((criado_em::date));
ANALYZE pedidos;
\echo '== 3: com índice sobre criado_em::date, random_page_cost padrão'
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF) SELECT p.criado_em::date::text AS dia, count(DISTINCT p.id) AS pedidos, sum(i.quantidade) AS itens, sum(i.quantidade * i.preco_unitario_centavos) AS receita_centavos FROM pedidos p JOIN itens_pedido i ON i.pedido_id = p.id WHERE p.criado_em::date BETWEEN '2024-01-01' AND '2024-01-07' AND p.status <> 'cancelado' GROUP BY p.criado_em::date ORDER BY p.criado_em::date;
SET LOCAL random_page_cost = 1.1;
\echo '== 4: com índice sobre criado_em::date, random_page_cost 1,1'
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF) SELECT p.criado_em::date::text AS dia, count(DISTINCT p.id) AS pedidos, sum(i.quantidade) AS itens, sum(i.quantidade * i.preco_unitario_centavos) AS receita_centavos FROM pedidos p JOIN itens_pedido i ON i.pedido_id = p.id WHERE p.criado_em::date BETWEEN '2024-01-01' AND '2024-01-07' AND p.status <> 'cancelado' GROUP BY p.criado_em::date ORDER BY p.criado_em::date;
ROLLBACK;
