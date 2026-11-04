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
