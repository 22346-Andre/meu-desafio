# Evidências do banco (coletadas em 03/11/2026, aplicação original, após a linha de base)

Coletadas com `docker compose exec -T banco psql -U loja -d loja -c '<consulta>'`.
Somente leitura. Nenhuma configuração ou dado foi alterado.

Ressalva: os contadores de `uso-tabelas.txt` acumulam desde a criação do banco
(carga dos dados, curls, contrato e medições). Os idx_scan de clientes, pedidos e
produtos parecem inflados pela validação de chaves estrangeiras na carga.
