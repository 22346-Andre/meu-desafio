-- Experimento 05: visão materializada com a receita por produto (P6).
-- Correta enquanto os dados não mudarem: a API só lê, e os dados são fixos (banco/02-dados.sql).
CREATE MATERIALIZED VIEW mv_receita_por_produto AS
SELECT pr.id AS id, pr.nome AS nome, pr.categoria AS categoria,
       sum(i.quantidade) AS unidades,
       sum(i.quantidade * i.preco_unitario_centavos) AS receita_centavos
  FROM itens_pedido i
  JOIN pedidos p ON p.id = i.pedido_id
  JOIN produtos pr ON pr.id = i.produto_id
 WHERE p.status <> 'cancelado'
 GROUP BY pr.id, pr.nome, pr.categoria;

CREATE INDEX idx_mv_receita_por_produto ON mv_receita_por_produto (receita_centavos DESC, id);
ANALYZE mv_receita_por_produto;
