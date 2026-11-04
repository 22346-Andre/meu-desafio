# Diagnóstico: problemas, evidências e hipóteses

Convenção: **Fato** aparece na saída ou no código citado. **Hipótese** é causa provável, ainda sem teste.
Os EXPLAIN foram rodados com a API parada, uma execução por consulta: tempos isolados, não sob carga.

## Linha de base (medianas das 3 execuções)
3,67 req/s, p95 18.163 ms, CPU do banco 98,5% de 1 CPU, CPU da API 7,0% de 0,5 CPU.
Pastas: resultados/20261103-211613-00-linha-de-base, resultados/20261103-212034-00-linha-de-base, resultados/20261103-212450-00-linha-de-base.
Fato: o banco está saturado e a API quase ociosa (recursos.txt de cada pasta).

## P1. /clientes/:id/pedidos: N+1 sobre varreduras completas (peso 20%)
- Fato: api/src/rotas.js faz 1 + 1 + P + I consultas (laço com `await consultar` dentro de `for`). O cliente 42 tem 5 pedidos e 10 itens: 17 consultas (diagnostico/banco/n-mais-1-cliente-42.txt).
- Fato: pedidos por cliente_id leva 378 ms em Seq Scan; itens por pedido_id leva 166 ms em Seq Scan (diagnostico/banco/explain-03-pedidos-do-cliente.txt). Só existem índices de PK (diagnostico/banco/indices.txt).
- Estimativa: cerca de 378 + 5 x (112 a 166) ms, ou ~0,9 a 1,2 s de consulta para o cliente 42.
- Hipótese de causa: falta de índice em pedidos(cliente_id) e itens_pedido(pedido_id), mais o N+1.

## P2. Conexão nova por consulta (todas as rotas)
- Fato: api/src/db.js cria um Client, conecta, executa uma consulta e fecha, sem pool.
- Hipótese de causa: o custo de abrir conexões soma CPU num banco já saturado e explica parte dos ~300 ms de /clientes/:id sob carga, embora a consulta leve 0,07 ms (explain-01).

## P3. /pedidos: contagem e ordenação por varredura completa; OFFSET fundo vai a disco (15%)
- Fato: contagem 101 ms, página 1 99 ms, página 15000 429 ms com `Sort Method: external merge Disk: 26368kB` e `temp written=11507` (diagnostico/banco/explain-04-pedidos-por-status.txt). work_mem = 4 MB (configuracao.txt).
- Hipótese de causa: falta de índice composto em (status, criado_em, id) e OFFSET proporcional à página.

## P4. /clientes?email=: lower(email) sem índice (15%)
- Fato: Seq Scan, 99.999 linhas descartadas, 38 ms; estimativa de 500 linhas contra 1 real (diagnostico/banco/explain-02-cliente-por-email.txt).
- Hipótese de causa: um índice comum em email não serviria; seria preciso índice sobre lower(email).

## P5. /relatorios/vendas-por-dia (8%)
- Fato: 279 ms, Seq Scan em pedidos e itens_pedido, ~57 mil linhas devolvidas e agregadas em JavaScript (diagnostico/banco/explain-06-vendas-por-dia.txt, api/src/rotas.js). A consulta traz p.observacoes (média de 274 caracteres, diagnostico/banco/tamanho-observacoes.txt) em cada linha de item.
- Estimativa: ~16 MB trafegando do banco para a API por chamada.
- Fato: o planejador estimou 937 pedidos e vieram 6.369 por worker (o cast criado_em::date impede estatística e índice).
- Hipótese de causa: ausência de índice em criado_em, cast que o inutiliza, e agregação feita na API em vez do SQL.

## P6. /relatorios/top-produtos (2%)
- Fato: 1.068 ms; lê os 1,5 milhão de itens e os 500 mil pedidos a cada chamada (diagnostico/banco/explain-07-top-produtos.txt).
- Hipótese de causa: agregação completa recalculada a cada chamada.

## P7. Busca de produtos (15%): prioridade baixa
- Fato: Seq Scan em 20 mil linhas, 9 ms isolada (diagnostico/banco/explain-05-busca-produtos.txt).
- Hipótese: a lentidão sob carga (resumo.txt) vem da saturação do banco, não da consulta.

## P8. Configuração padrão do PostgreSQL
- Fato: shared_buffers 128 MB, work_mem 4 MB, effective_cache_size 4 GB num container de 512 MB, 2 workers paralelos por consulta num limite de 1 CPU (diagnostico/banco/configuracao.txt). pedidos tem 163 MB e não cabe no shared_buffers (diagnostico/banco/tabelas-tamanho.txt). JIT não apareceu em nenhum dos 7 planos.
- Hipótese de causa: parâmetros inadequados ao limite de recursos do container.

## P9. Registro de cada resposta na API (baixa prioridade)
- Fato: api/src/server.js serializa e registra todo corpo de resposta com console.log.
- Hipótese: custo pequeno hoje (API a 7% de CPU), só relevante depois que o banco deixar de ser o gargalo.

## Impacto estimado (peso x tempo isolado, ordem de grandeza)
pedidos-do-cliente ~200 ms, pedidos-por-status ~30 a 80, vendas-por-dia ~22, top-produtos ~21, cliente-por-email ~6, busca-produtos ~1.

## Evidência complementar do P1 (N+1)
- Fato: duas execuções de /clientes/:id/pedidos para clientes com 5 pedidos e 10 itens abriram 17 sessões cada, descontada a sessão da própria leitura (diagnostico/banco/n-mais-1-escala.txt). Previsto pelo código: 2 + 5 + 10 = 17.
- Controle sem requisição: +2 em 3 s, sendo 1 da própria leitura e o outro provavelmente o healthcheck do compose.
- Limite: os dois clientes têm o mesmo tamanho, então o teste mostra a contagem prevista, mas não a escala com o tamanho do cliente.
- Medição anterior (n-mais-1-cliente-42.txt): +19 sessões e +63 transações, não conclusiva. xact_commit não foi explicado e não é usado como prova.
