-- Experimento 14: índice sobre a expressão criado_em::date para o filtro de vendas-por-dia (P5).
CREATE INDEX idx_pedidos_criado_em_data ON pedidos ((criado_em::date));
ANALYZE pedidos;
