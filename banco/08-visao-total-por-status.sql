-- Experimento 10: visão materializada com o total de pedidos por status (P3).
-- Correta enquanto os dados não mudarem: a API só lê, e os dados são fixos (banco/02-dados.sql).
CREATE MATERIALIZED VIEW mv_total_por_status AS
SELECT status, count(*) AS total FROM pedidos GROUP BY status;

CREATE UNIQUE INDEX idx_mv_total_por_status ON mv_total_por_status (status);
ANALYZE mv_total_por_status;
