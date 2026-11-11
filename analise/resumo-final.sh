#!/usr/bin/env bash
# Tabela final: uma linha por rótulo, com as medianas calculadas por analise/medianas.sh.
# Uso (na raiz do repositório): bash analise/resumo-final.sh | tee analise/resumo-final.md
set -euo pipefail

rotulos=(00-linha-de-base 01-indice-itens-pedido 02-indice-pedidos-cliente 03-indice-pedidos-status 04-n-mais-1-lotes 05-mv-top-produtos 06-pool-10 07-indice-email-lower 08-vendas-sql 09-sem-paralelismo 10-mv-total-status 11-api-menor 12-banco-maior 13-linha-de-base-remedida)
[ "$#" -gt 0 ] && rotulos=("$@")

echo "| rótulo | req/s | latência mediana (ms) | p95 (ms) | p99 (ms) | CPU média do banco (%) | CPU do banco por requisição (CPU-s) | CPU média da API (%) |"
echo "|---|---|---|---|---|---|---|---|"
for r in "${rotulos[@]}"; do
  if ! ls -d resultados/*-"$r" > /dev/null 2>&1; then echo "| $r | sem pasta em resultados/ | | | | | | |"; continue; fi
  saida=$(bash analise/medianas.sh "$r")
  req=$(echo "$saida" | awk -F'|' '/\| req\/s/ {gsub(/ /, "", $3); print $3}')
  lat=$(echo "$saida" | awk -F'|' '/\| latência mediana/ {gsub(/ /, "", $3); print $3}')
  p95=$(echo "$saida" | awk -F'|' '/\| p95/ {gsub(/ /, "", $3); print $3}')
  p99=$(echo "$saida" | awk -F'|' '/\| p99/ {gsub(/ /, "", $3); print $3}')
  cpub=$(echo "$saida" | awk -F'|' '/desafio-performance-banco/ {gsub(/ /, "", $3); print $3}')
  cpua=$(echo "$saida" | awk -F'|' '/desafio-performance-api/ {gsub(/ /, "", $3); print $3}')
  porreq=$(awk -v c="$cpub" -v q="$req" 'BEGIN { if (q > 0) printf "%.4f", c / 100 / q; else print "NA" }')
  echo "| $r | $req | $lat | $p95 | $p99 | $cpub | $porreq | $cpua |"
done
