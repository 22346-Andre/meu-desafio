-- Experimento 03: índice composto em pedidos para a listagem por status, já ordenada (P3).
CREATE INDEX idx_pedidos_status_criado ON pedidos (status, criado_em DESC, id DESC);
