-- Experimento 02: índice composto em pedidos para a busca por cliente, já ordenada (P1).
CREATE INDEX idx_pedidos_cliente_criado ON pedidos (cliente_id, criado_em DESC, id DESC);
