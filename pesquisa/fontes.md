# Fontes pesquisadas

Regra: cada fonte só entra no artigo depois de aberta e lida. Preencher "Acesso" e "Verificado" ao ler.

## Tema 1: índices (B-tree, expressão, chave estrangeira, ordenação)

| # | Fonte | Link | Acesso | Verificado | O que afirma (com minhas palavras) | Problemas |
|---|---|---|---|---|---|---|
| 1 | PostgreSQL 16, 11.7 Indexes on Expressions | https://www.postgresql.org/docs/16/indexes-expressional.html | | [ ] | Consulta com lower(col) pode usar índice criado sobre lower(col); a expressão é calculada na escrita, não na busca. | P4 |
| 2 | PostgreSQL, 5.5 Constraints, Foreign Keys | https://www.postgresql.org/docs/current/ddl-constraints.html#DDL-CONSTRAINTS-FK | | [ ] | Chave estrangeira não cria índice automaticamente nas colunas referenciadoras; convém indexá-las. | P1 |
| 3 | PostgreSQL 16, 11.4 Indexes and ORDER BY | https://www.postgresql.org/docs/16/indexes-ordering.html | | [ ] | Índice B-tree compatível com o ORDER BY dispensa a ordenação; com LIMIT lê só as primeiras linhas. | P3 |
| 4 | Winand, Use The Index Luke: Fetching the Next Page | https://use-the-index-luke.com/sql/partial-results/fetch-next-page | | [ ] | OFFSET conta as linhas desde o início; o método seek parte da última linha vista. | P3 |
| 5 | Winand, We need tool support for keyset pagination | https://use-the-index-luke.com/no-offset | | [ ] | OFFSET obriga o banco a buscar e ordenar as linhas puladas (afirmação do autor; opinião, não medição própria). | P3 |
| 6 | Comer, The Ubiquitous B-Tree, ACM Computing Surveys 11(2), 1979 | https://doi.org/10.1145/356770.356776 | | [ ] | Revisão do B-tree e do B+-tree e dos custos de busca, inserção e remoção. Acadêmica. | base |

## Tema 2: N+1 e pool de conexões

| # | Fonte | Link | Acesso | Verificado | O que afirma (com minhas palavras) | Problemas |
|---|---|---|---|---|---|---|
| 7 | node-postgres, Pooling | https://node-postgres.com/features/pooling | | [ ] | Recomenda pool para quem faz consultas com frequência; abrir conexão por consulta atrasa a aplicação; pool.query evita vazar cliente. | P2 |
| 8 | PostgreSQL, How Connections are Established | https://www.postgresql.org/docs/16/connect-estab.html | | [ ] | Modelo de um processo de servidor por conexão; o processo principal cria um novo a cada pedido. | P2 |
| 9 | Yang et al., How not to structure your database-backed web applications, ICSE 2018 | https://doi.org/10.1145/3180155.3180194 | | [ ] | Estudo de 12 aplicações com ORM: 9 anti-padrões; 64 correções com aceleração mediana de 2x. Estudo em Rails; relação com a API é por analogia. Acadêmica. | P1 |
| 10 | PostgreSQL 16, Row and Array Comparisons (ANY/SOME) | https://www.postgresql.org/docs/16/functions-comparisons.html | | [ ] | expressão = ANY(array) é verdadeiro se algum elemento casar; extensão do PostgreSQL. | P1 |
| 11 | OpenReplay, Understanding the N+1 Query Problem | https://blog.openreplay.com/n-1-query-problem/ | | [ ] | Duas correções: JOIN (uma ida, pode duplicar linhas) ou consulta em lote com IN (duas idas, sem duplicar). Blog; peso menor. | P1 |

## Tema 3: agregação e pré-agregação

| # | Fonte | Link | Acesso | Verificado | O que afirma (com minhas palavras) | Problemas |
|---|---|---|---|---|---|---|
| 12 | PostgreSQL 16, Materialized Views | https://www.postgresql.org/docs/16/rules-materializedviews.html | | [ ] | Visão materializada guarda o resultado como tabela; leitura costuma ser bem mais rápida, mas os dados nem sempre estão atuais; aceita índices. | P5, P6 |
| 13 | PostgreSQL 16, REFRESH MATERIALIZED VIEW | https://www.postgresql.org/docs/16/sql-refreshmaterializedview.html | | [ ] | Substitui todo o conteúdo; CONCURRENTLY evita bloquear leituras e exige índice único em colunas simples. (Lida por cópia das páginas de manual; confirmar no site oficial.) | P5, P6 |
| 14 | Gupta e Mumick, Maintenance of Materialized Views: Problems, Techniques, and Applications, IEEE Data Eng. Bull. 18(2), 1995 | https://dblp.org/rec/journals/debu/GuptaM95.html | | [ ] | Levantamento sobre visões materializadas, aplicações e problemas de manutenção. Acadêmica. (Li só o resumo; ler antes de citar.) | P5, P6 |
| 15 | Winand, Use The Index Luke: Obfuscated Conditions, Dates | https://use-the-index-luke.com/sql/where-clause/obfuscation/dates | | [ ] | Função sobre a coluna de data impede o índice comum; usar condição de intervalo explícita. Exemplos em Oracle/MySQL; confirmar no PostgreSQL com EXPLAIN. | P5 |

## Tema 4: parâmetros do PostgreSQL

| # | Fonte | Link | Acesso | Verificado | O que afirma (com minhas palavras) | Problemas |
|---|---|---|---|---|---|---|
| 16 | PostgreSQL 16, Resource Consumption | https://www.postgresql.org/docs/16/runtime-config-resource.html | | [ ] | shared_buffers: ponto de partida de 25% da memória em servidor dedicado com 1 GB ou mais; acima de 40% improvável melhorar. work_mem vale por operação de ordenação ou hash, e várias sessões somam. | P8 |
| 17 | PostgreSQL, Query Planning: Planner Cost Constants | https://www.postgresql.org/docs/16/runtime-config-query.html | | [ ] | random_page_cost padrão 4,0 assume cache alto; reduzir faz sentido com dados em memória ou SSD; effective_cache_size é só estimativa; mudar com poucos experimentos é arriscado. (Frase do risco lida em versão antiga; confirmar na 16.) | P8 |
| 18 | PostgreSQL 16, When Can Parallel Query Be Used? | https://www.postgresql.org/docs/16/when-can-parallel-query-be-used.html | | [ ] | Consulta paralela exige max_parallel_workers_per_gather maior que zero; pode rodar com menos trabalhadores que o planejado. Ler também o capítulo How Parallel Query Works. | P8 |
| 19 | pganalyze, Tuning random_page_cost and how index correlation affects query plans | https://pganalyze.com/blog/5mins-postgres-tuning-random-page-cost | | [ ] | Resume um caso de produção em que ajustar random_page_cost acelerou muito consultas. Secundário; achar o texto original. Caso de mercado. | P8 |
| 20 | Cybertec, Better PostgreSQL performance on SSDs | https://www.cybertec-postgresql.com/en/better-postgresql-performance-on-ssds/ | | [ ] | Em SSD, random_page_cost perto de 1 costuma ser benéfico. Verificar a data do texto. | P8 |
| 21 | Vondra, Some more thoughts on random_page_cost | https://vondra.me/posts/some-more-thoughts-on-random-page-cost/ | | [ ] | O ajuste deve ser específico do sistema e guiado por monitoramento; o 4,0 nunca foi o custo cru de I/O aleatório. Contraponto às fontes 19 e 20. | P8 |

## Tema 5: custo (limites de CPU e memória)

| # | Fonte | Link | Acesso | Verificado | O que afirma (com minhas palavras) | Problemas |
|---|---|---|---|---|---|---|
| 22 | Docker Docs, Resource constraints | https://docs.docker.com/engine/containers/resource_constraints/ | | [ ] | Container sem limite por padrão; é possível limitar CPU e memória; exceder o limite de memória pode levar ao encerramento de processos. | custo |
| 23 | Docker Docs, Compose Deploy Specification | https://docs.docker.com/reference/compose-file/deploy/ | | [ ] | resources distingue limits (teto) de reservations (mínimo); cpus e memory.  | custo |
