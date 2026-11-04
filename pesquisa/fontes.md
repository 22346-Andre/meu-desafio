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
