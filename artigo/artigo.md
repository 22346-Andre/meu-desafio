# De 3,7 a 178 req/s com os mesmos recursos reservados: o banco era o gargalo, e cada mudança foi medida

## 1. Resumo

Uma API Node.js com PostgreSQL, limitada a 1,5 CPU e 768 MiB no total, atendia 3,67 req/s com p95 de 18,2 s, com o banco no limite de CPU. Faltavam índices, havia um N+1, uma conexão por consulta e agregações recalculadas a cada chamada. Apliquei e medi 13 mudanças, uma por vez, sem alterar as respostas da API. O resultado final é de 178,4 req/s, p95 de 206,7 ms e 97% menos CPU de banco por requisição, com a mesma soma de recursos reservada. O banco continua sendo o gargalo.

## 2. Contexto e diagnóstico

**Fato.** A linha de base, medida três vezes (`resultados/*-00-linha-de-base`), deu 3,67 req/s, p95 de 18.163,2 ms e banco a 98,5% de 1 CPU, enquanto a API usava 7% de 0,5 CPU. Remedida sete dias depois, no mesmo código, a variação foi de até 1,4% (`experimentos.md`, seção "Controle").

**Como descobri.** Só existiam índices de chave primária (`diagnostico/banco/indices.txt`). O `EXPLAIN ANALYZE` mostrou varredura completa de `pedidos` em 378 ms e de `itens_pedido` em 166 ms para achar poucas linhas (`diagnostico/banco/explain-03-pedidos-do-cliente.txt`). Uma chamada a `/clientes/:id/pedidos` abria 17 sessões no banco para um cliente com 5 pedidos e 10 itens (`diagnostico/banco/n-mais-1-escala.txt`), e uma consulta com conexão nova levou 4,1 ms contra 0,11 ms com a conexão reaproveitada (`diagnostico/banco/custo-conexao.txt`). `top-produtos` agregava 1,5 milhão de itens a cada chamada, em 1.068 ms (`diagnostico/banco/explain-07-top-produtos.txt`). Os problemas estão em `diagnostico/problemas.md`.

**Hipóteses de causa.** (1) Faltam índices nas chaves estrangeiras, em `lower(email)` e em `status` e data. (2) O N+1 e a conexão por consulta multiplicam as idas ao banco. (3) Agregações são recalculadas a cada chamada. (4) A configuração padrão não considera o limite de 1 CPU.

## 3. Estado da arte

### Índices
A documentação do PostgreSQL diz que uma consulta com `lower(col)` pode usar um índice criado sobre essa expressão [1], e que um índice B-tree compatível com o `ORDER BY` dispensa a ordenação e, com `LIMIT`, lê só as primeiras linhas [2].

### N+1 e pool de conexões
Yang et al. catalogam anti-padrões de desempenho em aplicações com ORM, incluindo dados recuperados e não usados [5]; o estudo é sobre Rails, então a relação com esta API é por analogia. O `node-postgres` recomenda um pool para quem consulta com frequência [3], porque o PostgreSQL cria um processo de servidor por conexão [4]. `= ANY(array)` permite buscar vários registros numa consulta [6].

### Pré-agregação
Uma visão materializada guarda o resultado da consulta e é lida como tabela, mais rápida, mas nem sempre atual [7]; a literatura trata o custo de mantê-la atualizada [8].

### Paralelismo e limites de recursos
A consulta paralela depende de `max_parallel_workers_per_gather` ser maior que zero [9]. O Docker aplica limites de CPU como cota por período, e o período padrão é de 100 ms [10].

**Opinião.** Nenhuma fonte diz para desligar o paralelismo com 1 CPU; essa foi uma hipótese minha, testada no experimento 09.

## 4. Alternativas consideradas

| Alternativa | Custo | Desempenho | Risco | Esforço |
|---|---|---|---|---|
| Índices e reescrita de consultas | dezenas de MB de disco | alto (3,5 vezes a vazão, de 3,67 para 13,02 req/s, só com os três índices e o N+1 em lotes) | baixo; o contrato detecta mudança de resposta | baixo |
| Pré-agregação com visões materializadas | poucos MB de disco | alto nas duas rotas atacadas | respostas defasadas se houver escrita | médio |
| Redistribuir os limites de recursos | zero (mesma soma reservada) | +30% de vazão | a API passou a sofrer throttling a ~178 req/s | baixo |
| Cache externo (Redis, não aplicado) | um serviço novo | semelhante às visões | invalidação de cache | alto |
| Paginação por chave (não aplicada) | zero | só no pior caso de paginação | muda os parâmetros da rota, o que o contrato proíbe | médio |

## 5. Solução escolhida e por quê

Primeiro reduzi o trabalho por requisição, porque o banco estava a 98% de CPU e a API quase ociosa: índices, N+1 em lotes, visões materializadas, pool de conexões e agregação no SQL, nessa ordem, pela fatia estimada de custo de cada rota. Depois dimensionei os recursos com evidência: a API usava pouco, então reduzi seu limite, e o banco, que estava com throttling de cgroup em 97% dos períodos de 100 ms (`diagnostico/throttle-completo.txt`), recebeu a diferença, mantendo a soma reservada. Descartei o cache externo por custo, e a paginação por chave por mudar a interface.

## 6. Experimento e resultado

Todas as medições usaram `scripts/medir.sh` (20 usuários, 60 s, três execuções, mediana), com o contrato mantido e os números calculados por scripts em `analise/`. Detalhes e pastas exatas estão em [experimentos.md](../experimentos.md), e a tabela com todos os rótulos em [analise/resumo-final.md](../analise/resumo-final.md).

| Mudança | Hipótese | p95 antes → depois (ms) | req/s antes → depois | CPU e memória do banco (mediana) | Pastas de resultados | Conclusão |
|---|---|---|---|---|---|---|
| 01 índice em `itens(pedido_id)` | evita varrer 1,5 mi de itens | 18.163,2 → 9.599,4 | 3,67 → 6,09 | 0,2684 → 0,1614 CPU-s/req (394 → 396 MiB) | `resultados/*-01-indice-itens-pedido` | ganho |
| 02 índice em `pedidos(cliente_id, criado_em, id)` | busca ordenada pelo índice | 9.599,4 → 8.537,9 | 6,09 → 7,04 | 0,1614 → 0,1339 CPU-s/req (396 → 381 MiB) | `resultados/*-02-indice-pedidos-cliente` | ganho pequeno |
| 03 índice em `pedidos(status, criado_em, id)` | listagem ordenada sem varredura | 8.537,9 → 7.309,1 | 7,04 → 9,85 | 0,1339 → 0,1007 CPU-s/req (381 → 412 MiB) | `resultados/*-03-indice-pedidos-status` | ganho |
| 04 N+1 em lotes | de 17 para 4 consultas | 7.309,1 → 6.506,6 | 9,85 → 13,02 | 0,1007 → 0,0759 CPU-s/req (412 → 411 MiB) | `resultados/*-04-n-mais-1-lotes` | ganho; rota alvo −76% no p95 |
| 05 visão de `top-produtos` | tira 1,07 s por chamada | 6.506,6 → 2.317,5 | 13,02 → 21,90 | 0,0759 → 0,0461 CPU-s/req (411 → 452 MiB) | `resultados/*-05-mv-top-produtos` | maior queda de p95 |
| 06 pool de 10 conexões | evita ~4 ms por conexão | 2.317,5 → 1.304,3 | 21,90 → 35,86 | 0,0461 → 0,0269 CPU-s/req (452 → 471 MiB) | `resultados/*-06-pool-10` | ganho |
| 07 índice em `lower(email)` | busca sem varredura | 1.304,3 → 1.163,0 | 35,86 → 45,72 | 0,0269 → 0,0215 CPU-s/req (471 → 474 MiB) | `resultados/*-07-indice-email-lower` | ganho |
| 08 `vendas-por-dia` agregada no SQL | menos CPU da API | 1.163,0 → 1.006,9 | 45,72 → 54,72 | 0,0215 → 0,0179 CPU-s/req (474 → 466 MiB) | `resultados/*-08-vendas-sql` | CPU da API −86% |
| 09 paralelismo desligado | menos CPU com 1 CPU | 1.006,9 → 909,6 | 54,72 → 71,04 | 0,0179 → 0,0136 CPU-s/req (466 → 470 MiB) | `resultados/*-09-sem-paralelismo` | ganho |
| 10 visão dos totais por status | tira a contagem por chamada | 909,6 → 910,5 | 71,04 → 81,60 | 0,0136 → 0,0121 CPU-s/req (470 → 465 MiB) | `resultados/*-10-mv-total-status` | vazão sim, p95 não |
| 11 API com 0,25 CPU e 128 MiB | mesma vazão, menos recurso | 910,5 → 995,9 | 81,60 → 81,17 | 0,0121 → 0,0120 CPU-s/req (465 → 468 MiB) | `resultados/*-11-api-menor` | sem ganho de vazão; economiza 0,25 CPU e 128 MiB |
| 12 banco com 1,25 CPU e 640 MiB | o limite de CPU do banco era o gargalo | 995,9 → 747,9 | 81,17 → 105,70 | 0,0120 → 0,0116 CPU-s/req (468 → 490 MiB) | `resultados/*-12-banco-maior` | +30% de vazão, mesma soma reservada |
| 14 índice sobre `criado_em::date` | consulta de 58 para 22 ms | 747,9 → 206,7 | 105,70 → 178,41 | 0,0116 → 0,0069 CPU-s/req (490 → 510 MiB) | `resultados/*-14-indice-criado-em-data` | maior ganho de vazão |
| 13 controle (linha de base remedida) | medir a deriva | 18.163,2 → 18.341,9 | 3,67 → 3,62 | 0,2684 → 0,2677 CPU-s/req (394 → 396 MiB) | `resultados/*-13-linha-de-base-remedida` | deriva de 1% |

**O que não funcionou.** O experimento 10 não mexeu no p95 (909,6 → 910,5 ms) e o 11 piorou 9,4% (910,5 → 995,9 ms), dentro de um par de valores que já alternava (~910 e ~995 ms). No experimento 01, `vendas-por-dia` piorou 142% no p95 sem ser alterada, o que atribuo, como hipótese, à disputa de CPU num teste fechado. Por rota, o p95 variou de −41% a +17% sem nenhuma mudança na remedição da linha de base (de 3 a 62 requisições por execução): só confio nos números gerais.

## 7. Limites e testes futuros

As visões materializadas só são corretas porque os dados são fixos e a API só lê; com escrita, exigiriam `REFRESH`. O teste é fechado, com 20 usuários por 60 s numa única máquina, então os números absolutos não se transferem, mas as razões entre eles sim. A API, com 0,25 CPU, sofre throttling de 16% a 24% dos períodos a ~178 req/s. O `cpu_max` e o `mem_max` do `recursos.txt` comparam texto e erram quando os valores mudam de casa decimal (`diagnostico/problemas.md`), por isso usei picos calculados à parte. Não provei que o throttling do cgroup explica as medianas em degraus de ~100 ms.

**O que derrubaria a conclusão:** uma carga com escrita, ou uma remedição em outra máquina com razões muito diferentes. Ficaram em [proximos-testes.md](../proximos-testes.md) o `random_page_cost`, `pg_trgm` na busca, o tamanho do pool, menos colunas por consulta e mais CPU para o banco.

## 8. Referências

1. PostgreSQL Global Development Group. *Indexes on Expressions (PostgreSQL 16)*. https://www.postgresql.org/docs/16/indexes-expressional.html. Acesso em: 13 nov. 2026.
2. PostgreSQL Global Development Group. *Indexes and ORDER BY (PostgreSQL 16)*. https://www.postgresql.org/docs/16/indexes-ordering.html. Acesso em: 13 nov. 2026.
3. node-postgres. *Pooling*. https://node-postgres.com/features/pooling. Acesso em: 13 nov. 2026.
4. PostgreSQL Global Development Group. *How Connections Are Established (PostgreSQL 16)*. https://www.postgresql.org/docs/16/connect-estab.html. Acesso em: 13 nov. 2026.
5. Yang, J. et al. *How not to structure your database-backed web applications: a study of performance bugs in the wild*. ICSE 2018. https://doi.org/10.1145/3180155.3180194. Acesso em: 13 nov. 2026.
6. PostgreSQL Global Development Group. *Row and Array Comparisons (PostgreSQL 16)*. https://www.postgresql.org/docs/16/functions-comparisons.html. Acesso em: 13 nov. 2026.
7. PostgreSQL Global Development Group. *Materialized Views (PostgreSQL 16)*. https://www.postgresql.org/docs/16/rules-materializedviews.html. Acesso em: 13 nov. 2026.
8. Gupta, A.; Mumick, I. S. *Maintenance of Materialized Views: Problems, Techniques, and Applications*. IEEE Data Engineering Bulletin 18(2), 1995. https://dblp.org/rec/journals/debu/GuptaM95.html. Acesso em: 13 nov. 2026.
9. PostgreSQL Global Development Group. *When Can Parallel Query Be Used? (PostgreSQL 16)*. https://www.postgresql.org/docs/16/when-can-parallel-query-be-used.html. Acesso em: 13 nov. 2026.
10. Docker Inc. *Resource constraints*. https://docs.docker.com/engine/containers/resource_constraints/. Acesso em: 13 nov. 2026.

## 9. Uso de IA

Usei modelos de linguagem (Claude e Gemini) para planejar as etapas, interpretar as saídas, escrever os scripts de análise em `analise/`, pesquisar fontes e revisar este texto. Verifiquei os resultados com o verificador de contrato em todas as medições, os números saem de `resultados/` por scripts, e abri e li cada fonte citada antes de usá-la.
