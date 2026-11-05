# Experimentos

Cada linha é uma mudança aplicada, com antes e depois medidos pelo medir.sh (mediana de 3 execuções, calculada por analise/medianas.sh).
Comparação: "base" é a linha de base (resultados/*-00-linha-de-base); "anterior" é a mudança imediatamente anterior.

| # | Mudança | Fonte da ideia | Status | Comparado com | Pastas do antes | Pastas do depois | req/s antes → depois | p95 (ms) antes → depois | CPU/mem do banco | CPU/mem da API | Conclusão |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 01 | Índice em itens_pedido(pedido_id) (banco/03-indice-itens-pedido-pedido-id.sql) | Fontes 2 e 3 de pesquisa/fontes.md | Aplicada e medida | linha de base | resultados/20261103-211613-00-linha-de-base, resultados/20261103-212034-00-linha-de-base, resultados/20261103-212450-00-linha-de-base | resultados/20261104-235814-01-indice-itens-pedido, resultados/20261105-000155-01-indice-itens-pedido, resultados/20261105-000534-01-indice-itens-pedido | 3,67 → 6,09 | 18.163,2 → 9.599,4 | CPU 98,5% → 98,3%; memória 394,3 → 396,4 MiB | memória média 34,3 → 92,5 MiB; CPU não conclusiva (média acima do máximo no recursos.txt) | Ganho geral de vazão (+65,9%) e de p95 (−47,1%); p99 quase igual (−8,5%); banco continua saturado; custo: índice de 21 MB; aumento de memória da API não investigado; contrato mantido nas 3 execuções; atribuição por rota em analise/01-por-rota.md |
