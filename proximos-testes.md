# Próximos testes

Ideias pesquisadas ou observadas no diagnóstico que não foram aplicadas e medidas neste repositório. Nenhum resultado abaixo é de uma medição de carga: onde há evidência, ela é de um diagnóstico salvo no repositório e está indicada.

Status de todas: **Pesquisada, teste futuro**.

## 1. random_page_cost menor (1,1) depois do índice sobre criado_em::date
- **De onde veio:** documentação do PostgreSQL sobre as constantes de custo do planejador (https://www.postgresql.org/docs/16/runtime-config-query.html); pganalyze (https://pganalyze.com/blog/5mins-postgres-tuning-random-page-cost); Cybertec (https://www.cybertec-postgresql.com/en/better-postgresql-performance-on-ssds/); Vondra, em tom de cautela (https://vondra.me/posts/some-more-thoughts-on-random-page-cost/).
- **Evidência no repositório:** o what-if de vendas-por-dia (diagnostico/banco/what-if-vendas-por-dia.txt, rodado em transação com ROLLBACK) mostrou, com o índice já criado, 22,1 ms com o valor padrão e 13,0 ms com 1,1 (EXPLAIN ANALYZE, execução única).
- **Ganho que acredito:** pequeno: ~9 ms em uma rota que tem 8% das requisições, menos de 1 ms por requisição.
- **Como testaria:** `-c random_page_cost=1.1` no command do serviço banco, três medições, comparando com o experimento 14.
- **O que precisaria:** ~30 minutos. Risco: a documentação alerta que mudar constantes de custo com poucos experimentos é arriscado, e outros planos podem mudar.

## 2. Índice de trigramas (pg_trgm) na busca de produtos
- **De onde veio:** documentação do PostgreSQL sobre pg_trgm (https://www.postgresql.org/docs/16/pgtrgm.html).
- **Evidência no repositório:** a consulta de busca leva ~9 ms em varredura sequencial de 20 mil linhas (diagnostico/banco/explain-05-busca-produtos.txt).
- **Ganho que acredito:** pequeno em CPU de banco (~1,4 ms por requisição, 15% do tráfego), limitado porque a consulta ordena por nome antes de aplicar o limite de 20.
- **Como testaria:** `CREATE EXTENSION pg_trgm` e um índice GIN com gin_trgm_ops em produtos(nome), em um .sql novo; três medições.
- **O que precisaria:** confirmar que a extensão está disponível na imagem postgres:16.4; ~40 minutos.

## 3. Tamanho do pool de conexões (4 e 20)
- **De onde veio:** documentação do node-postgres sobre pooling (https://node-postgres.com/features/pooling), que recomenda um pool mas não indica o tamanho.
- **Evidência no repositório:** só o tamanho 10 foi medido (experimento 06). O db.js já lê DB_POOL_MAX.
- **Ganho que acredito:** desconhecido. Um pool menor reduziria backends simultâneos no banco, que estava a ~96% da memória quando o pool foi introduzido.
- **Como testaria:** `DB_POOL_MAX` nas variáveis de ambiente do serviço api, três medições por valor.
- **O que precisaria:** ~30 minutos por valor.

## 4. Menos dados por consulta: não trazer `observacoes` e usar índice que cubra as colunas
- **De onde veio:** Yang et al., ICSE 2018, que cataloga "dados recuperados e não usados" entre os anti-padrões (https://doi.org/10.1145/3180155.3180194; estudo sobre ORM em Rails, relação por analogia).
- **Evidência no repositório:** pedidos.observacoes tem em média 274 caracteres (diagnostico/banco/tamanho-observacoes.txt), e /pedidos e /clientes/:id/pedidos usam SELECT * enquanto devolvem poucas colunas.
- **Ganho que acredito:** menos bytes lidos e transferidos; um índice com INCLUDE poderia dispensar a leitura da tabela na listagem por status.
- **Como testaria:** trocar SELECT * pelas colunas usadas e criar o índice, em dois experimentos separados.
- **O que precisaria:** ~1 hora; atenção à ordem e aos tipos para não quebrar o contrato.

## 5. Paginação profunda (página 15000, OFFSET de 299.980)
- **De onde veio:** Winand, Use The Index, Luke (https://use-the-index-luke.com/sql/partial-results/fetch-next-page e https://use-the-index-luke.com/no-offset).
- **Evidência no repositório:** só o contrato exercita a página 15000, e a carga usa páginas até 1.000 (carga/teste-carga.js). O plano dessa página usou ordenação em disco, 428,6 ms (diagnostico/banco/explain-04-pedidos-por-status.txt) e 273,9 ms com o paralelismo desligado (diagnostico/banco/depois-09-explain-04-pedidos-por-status.txt).
- **Ganho que acredito:** nenhum na carga; só no pior caso do contrato.
- **Como testaria:** não com paginação por chave, que mudaria os parâmetros da rota; uma subconsulta que busca só os ids da página e depois as linhas.
- **O que precisaria:** uma carga que exercite páginas profundas (a ferramenta de medição não pode ser alterada).

## 6. Mais CPU para o banco e para a API (custo)
- **De onde veio:** documentação do Docker sobre limites de recursos (https://docs.docker.com/engine/containers/resource_constraints/) e sobre a seção deploy do Compose (https://docs.docker.com/reference/compose-file/deploy/).
- **Evidência no repositório:** throttling do banco em 84% a 98% dos períodos e da API em 15% a 24% no experimento 14 (diagnostico/throttle-completo.txt).
- **Ganho que acredito:** vazão aproximadamente proporcional à CPU do banco, como no experimento 12 (+25% de CPU, +30% de vazão), e menos throttling na API com 0,5 CPU.
- **Como testaria:** banco em 1,5 CPU e API em 0,5 CPU, comparando a vazão com o custo do recurso a mais.
- **O que precisaria:** decisão de aceitar o custo adicional (a soma passaria de 1,5 para 2,0 CPU).

## 7. Consistência das visões materializadas se a aplicação passar a escrever
- **De onde veio:** documentação do PostgreSQL sobre visões materializadas e REFRESH (https://www.postgresql.org/docs/16/rules-materializedviews.html e https://www.postgresql.org/docs/16/sql-refreshmaterializedview.html); Gupta e Mumick (https://dblp.org/rec/journals/debu/GuptaM95.html).
- **Evidência no repositório:** as duas visões (mv_receita_por_produto e mv_total_por_status) só são corretas com dados fixos e API somente de leitura.
- **Ganho que acredito:** não é ganho de desempenho, é correção: com escrita, as visões precisariam de REFRESH MATERIALIZED VIEW CONCURRENTLY ou de outra estratégia de atualização.
- **Como testaria:** simular escritas e medir o custo do REFRESH e a defasagem.
- **O que precisaria:** uma rota de escrita, que hoje não existe.

## 8. shared_buffers e work_mem
- **De onde veio:** documentação do PostgreSQL sobre consumo de recursos (https://www.postgresql.org/docs/16/runtime-config-resource.html).
- **Evidência no repositório:** shared_buffers de 128 MB já era 25% do limite de 512 MiB original (diagnostico/banco/configuracao.txt); depois dos índices, não há ordenação em disco na carga.
- **Ganho que acredito:** provavelmente pequeno. Com 640 MiB, 25% seriam 160 MB.
- **Como testaria:** `-c shared_buffers=160MB`, três medições.
- **O que precisaria:** ~30 minutos.

## 9. Ideias do diagnóstico, sem fonte externa (hipóteses próprias)
- **Parar de registrar o corpo de cada resposta (api/src/server.js).** A API gasta ~1 ms de CPU por requisição; a fração que vem do registro não foi medida. Teria que ser testado com perfilamento do Node ou em um experimento isolado.
- **Atualizar dependências com vulnerabilidades.** O `npm ci` do build avisa de 4 vulnerabilidades (1 moderada e 3 altas). Não é desempenho, é um risco observado e fora do escopo deste desafio.
