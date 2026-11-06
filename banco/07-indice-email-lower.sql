-- Experimento 07: índice sobre lower(email) para a busca por e-mail sem diferenciar maiúsculas (P4).
CREATE INDEX idx_clientes_email_lower ON clientes (lower(email));
ANALYZE clientes;
