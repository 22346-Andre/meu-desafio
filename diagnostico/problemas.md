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

## Atualização do P3 depois do experimento 03 (P3b: paginação profunda)
- Fato: com o índice (status, criado_em DESC, id DESC), a contagem passou a Index Only Scan (22,3 ms) e a página 1 a Index Scan (0,9 ms), mas a página 15000 (OFFSET 299980) continuou em Seq Scan com ordenação em disco, 582,3 ms em execução única (diagnostico/banco/depois-03-explain-04-pedidos-por-status.txt).
- Hipótese de causa: pular 300 mil linhas por índice exige ler as linhas na tabela, e o planejador estima isso mais caro que varrer e ordenar. A rota usa SELECT * e devolve só 4 colunas; um índice que cubra essas colunas poderia dispensar a leitura da tabela. Não testado.

## Nota sobre o que o teste de carga exercita (leitura de carga/teste-carga.js)
- Fato: /pedidos usa pagina de 1 a 1000 (OFFSET até 19.980) e os quatro status sorteados por igual; a página 15000 só aparece no contrato. O P3b (paginação profunda) fica como risco de pior caso, não como gargalo medido na carga.
- Fato: vendas-por-dia usa janelas de 7 dias (inicio de 0 a 724 dias a partir de 2024-01-01); o EXPLAIN 06 usou 31 dias e é um caso mais pesado. EXPLAIN com 7 dias em diagnostico/banco/explain-08-vendas-por-dia-7-dias.txt.
- Fato: cada usuário virtual faz uma requisição por iteração, sem pausa; a latência média acompanha 20 usuários dividido pela vazão.

## Atualização do P5 e do P6 (execuções repetidas com cache aquecido)
- Fato: com a janela de 7 dias da carga, vendas-por-dia leva de 46 a 115 ms em consulta isolada com cache aquecido, 8 execuções (diagnostico/banco/explain-08-repeticoes.txt); em execuções anteriores, só exibidas na tela, de 32 a 88 ms; a primeira execução depois de reiniciar o Docker levou 820,6 ms. O 576,8 ms de diagnostico/banco/explain-08-vendas-por-dia-7-dias.txt foi uma execução com cache frio. A varredura de pedidos custa de 33 a 92 ms dentro do plano nas 8 execuções salvas.
- Estimativa (execuções isoladas, tempo de relógio): top-produtos leva ~1.068 ms por chamada; com 2% das requisições a ~9,85 req/s, são ~0,2 chamadas por segundo, ou ~21% de 1 CPU, a maior fatia individual. vendas-por-dia soma ~3 ms por requisição em média.

## Notas consolidadas depois do experimento 04
- Custo de conexão (P2): consulta real por id em clientes leva 0,111 ms com conexão persistente e 4,124 ms com conexão nova a cada transação, com 2,109 ms de tempo de conexão (diagnostico/banco/custo-conexao.txt). A API abre ~5,35 conexões por requisição em média (5 pedidos por cliente e 3 itens por pedido, em média), ~53 por segundo a 9,85 req/s, ou ~211 ms por segundo em tempo de relógio. Limites: um cliente, socket local, banco ocioso, tempo de relógio e não CPU de servidor.
- O que a carga exercita (carga/teste-carga.js): /pedidos usa pagina de 1 a 1000 (OFFSET até 19.980); vendas-por-dia usa janelas de 7 dias; top-produtos usa limite=10; cada usuário faz uma requisição por iteração, sem pausa. O P3b (paginação profunda, página 15000) só aparece no contrato.
- vendas-por-dia com janela de 7 dias: 8 execuções salvas, de 46 a 115 ms (mediana ~87 ms) com cache aquecido (diagnostico/banco/explain-08-repeticoes.txt); a primeira execução depois de reiniciar o Docker levou 820,6 ms (vista na tela, não salva). Ponta a ponta pela API: de 124 a 206 ms depois da primeira chamada, que levou 670 ms (diagnostico/tempos-curl-depois-04.txt). A diferença para o tempo do banco é, como hipótese, transferência de ~12.945 linhas com observacoes e agregação em JavaScript.
- Ponta a ponta sem carga (diagnostico/tempos-curl-depois-04.txt): top-produtos de 0,84 a 0,92 s (1ª chamada: 1,14 s); /pedidos pagina 500 de 67 a 71 ms; /clientes?email de 37 a 43 ms; /clientes/42/pedidos de 28 a 31 ms, contra 503 e 510 ms em diagnostico/tempos-iniciais-curl.md (sessões diferentes; comparação indicativa).
- N+1 depois do experimento 04: +6 e +5 sessões para os clientes 42 e 7, ou 5 e 4 descontada a sessão da leitura (diagnostico/banco/n-mais-1-depois-04.txt), contra 17 antes (diagnostico/banco/n-mais-1-escala.txt).

## Notas depois do experimento 05
- Fato: top-produtos passou de 1.068 ms (EXPLAIN isolado, diagnostico/banco/explain-07-top-produtos.txt) para 0,541 ms (Index Scan na visão materializada, diagnostico/banco/depois-05-explain-top-produtos.txt); ponta a ponta pela API, de 0,84 a 0,92 s para 8 a 12 ms (saída do curl no experimento 05). A visão ocupa 1,7 MB (diagnostico/banco/depois-05-visao.txt).
- Fato: com a rota mais pesada removida, pedidos-por-status e vendas-por-dia, não alteradas, caíram no p95 (analise/05-por-rota.md), enquanto no experimento 04 tinham subido. Consistente com disputa de CPU num teste fechado; hipótese, não provada.
- Fato: o pico de memória do banco chegou a 489,2 MiB (95,5% do limite de 512 MiB) nas execuções do 05 (analise/05-picos.md). Não verificado se o número inclui cache de arquivos do sistema.
- Consistência com a hipótese do cpu_max: no 05 o cpu_max da API (32,0, 32,7 e 33,5, todos com dois dígitos) bate com os picos numéricos do recursos.csv, e o do banco (99,8 e 99,9) fica abaixo da média (100,9) e dos picos numéricos (108,6 a 109,4). Compatível com comparação de texto no medir.sh; hipótese, o script não foi lido por inteiro.
- Risco da visão materializada: só é correta com dados fixos e API somente de leitura; com escrita, exigiria REFRESH MATERIALIZED VIEW (fonte 13 de pesquisa/fontes.md).

## Notas depois do experimento 06 (pool de conexões)
- Fato: sessões novas por chamada de /clientes/:id/pedidos: 4 a 5 depois do experimento 04, 2 e 0 com o pool (diagnostico/banco/pool-depois-06.txt); 2 conexões abertas em repouso; nenhum erro de pool no log da API.
- Conta derivada: CPU média do banco por requisição de 0,046 para 0,027 CPU-segundo, ~19 ms por requisição, ou ~11 ms por conexão evitada (~1,75 conexões por requisição depois do N+1); o pgbench (diagnostico/banco/custo-conexao.txt) tinha medido ~4 ms de tempo de relógio por conexão, por baixo (um cliente, socket local, consulta simples).
- Fato: o pico de memória do banco chegou a 506,0 MiB (98,8% do limite de 512 MiB) e o pico numérico de CPU da API a 41,4% de 1 CPU (83% do limite de 0,5 CPU) (analise/06-picos.md). Não verificado se a memória do docker stats inclui cache de arquivos.
- Fato: o cpu_max do recursos.txt da API (41,4, 42,5 e 38,1) bate com os picos numéricos, como previsto pela hipótese de comparação de texto no medir.sh.
- Medição feita em outra sessão do Docker (banco reiniciado) que a do experimento 05.
