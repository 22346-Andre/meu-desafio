#!/usr/bin/env bash
# Mediana por rota (requisições e p95) das execuções de um rótulo, lendo só o resumo.txt.
# Com dois rótulos, mostra antes -> depois. Rodar na raiz do repositório.
# Uso: bash analise/por-rota.sh 00-linha-de-base
#      bash analise/por-rota.sh 00-linha-de-base 01-indice-itens-pedido
set -euo pipefail

antes="${1:?informe o rótulo do antes}"
depois="${2:-}"

mediana() {
  sort -n | awk -v f="$1" '{a[NR]=$1} END {
    if (NR == 0) { print "NA"; exit }
    if (NR % 2) v = a[(NR+1)/2]; else v = (a[NR/2] + a[NR/2+1]) / 2;
    printf f "\n", v }'
}

# valor <rótulo> <rota> <campo>: campo 2 = requisições, campo 5 = p95 (ms)
valor() {
  local d
  for d in resultados/*-"$1"; do
    awk -v r="$2" -v c="$3" '$1 == r && $2 ~ /^[0-9]+$/ && $4 == "ms" {print $c}' "$d/resumo.txt"
  done
}

ls -d resultados/*-"$antes" > /dev/null 2>&1 || { echo "nenhuma pasta para $antes" >&2; exit 1; }
rotas=$(for d in resultados/*-"$antes"; do awk '$2 ~ /^[0-9]+$/ && $4 == "ms" {print $1}' "$d/resumo.txt"; done | sort -u)

if [ -z "$depois" ]; then
  echo "| rota | req (mediana) | p95 ms (mediana) |"
  echo "|---|---|---|"
  for r in $rotas; do
    printf "| %s | %s | %s |\n" "$r" "$(valor "$antes" "$r" 2 | mediana '%.0f')" "$(valor "$antes" "$r" 5 | mediana '%.1f')"
  done
else
  ls -d resultados/*-"$depois" > /dev/null 2>&1 || { echo "nenhuma pasta para $depois" >&2; exit 1; }
  echo "| rota | req antes → depois | p95 ms antes → depois | variação do p95 |"
  echo "|---|---|---|---|"
  for r in $rotas; do
    ra=$(valor "$antes" "$r" 2 | mediana '%.0f'); rd=$(valor "$depois" "$r" 2 | mediana '%.0f')
    pa=$(valor "$antes" "$r" 5 | mediana '%.1f'); pd=$(valor "$depois" "$r" 5 | mediana '%.1f')
    var=$(awk -v a="$pa" -v b="$pd" 'BEGIN { if (a == "NA" || b == "NA" || a == 0) print "NA"; else printf "%+.1f%%", (b - a) / a * 100 }')
    printf "| %s | %s → %s | %s → %s | %s |\n" "$r" "$ra" "$rd" "$pa" "$pd" "$var"
  done
fi
