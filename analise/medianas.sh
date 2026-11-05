#!/usr/bin/env bash
# Calcula a mediana das execuções de um rótulo, lendo só os arquivos gerados pelo medir.sh.
# Uso (na raiz do repositório): bash analise/medianas.sh 00-linha-de-base
set -euo pipefail

rotulo="${1:?informe o rótulo, ex.: 00-linha-de-base}"
pastas=(resultados/*-"$rotulo")
if [ ! -d "${pastas[0]}" ]; then
  echo "nenhuma pasta encontrada para o rótulo $rotulo" >&2
  exit 1
fi

# mediana <formato>: lê números da entrada padrão (um por linha)
mediana() {
  sort -n | awk -v f="$1" '{a[NR]=$1} END {
    if (NR == 0) { print "NA"; exit }
    if (NR % 2) v = a[(NR+1)/2]; else v = (a[NR/2] + a[NR/2+1]) / 2;
    printf f "\n", v }'
}

# resumo <pasta> <texto da linha> <expressão sed>: extrai um número do resumo.txt
resumo() { grep -m1 "$2" "$1/resumo.txt" | sed -E "$3"; }

echo "Rótulo: $rotulo | execuções: ${#pastas[@]}"
for d in "${pastas[@]}"; do echo "  - $d"; done
echo

echo "| métrica | mediana |"
echo "|---|---|"
printf "| req/s | %s |\n" "$(for d in "${pastas[@]}"; do resumo "$d" '/s:' 's/.*:[[:space:]]+([0-9.]+).*/\1/'; done | mediana '%.2f')"
printf "| latência mediana (ms) | %s |\n" "$(for d in "${pastas[@]}"; do resumo "$d" 'Tempo de resposta' 's/.*mediana ([0-9.]+) ms.*/\1/'; done | mediana '%.1f')"
printf "| p95 (ms) | %s |\n" "$(for d in "${pastas[@]}"; do resumo "$d" 'Tempo de resposta' 's/.*p95 ([0-9.]+) ms.*/\1/'; done | mediana '%.1f')"
printf "| p99 (ms) | %s |\n" "$(for d in "${pastas[@]}"; do resumo "$d" 'Tempo de resposta' 's/.*p99 ([0-9.]+) ms.*/\1/'; done | mediana '%.1f')"
echo

echo "| container | CPU média (%) | CPU máx (%) | memória média (MiB) | memória máx (MiB) |"
echo "|---|---|---|---|---|"
containers=$(awk '$1 ~ /^desafio-performance-/ {print $1}' "${pastas[0]}/recursos.txt" | sort -u)
for c in $containers; do
  col() { # col <campo>: valor do campo na linha do container, em cada pasta
    for d in "${pastas[@]}"; do
      awk -v c="$c" -v k="$1" '$1 == c {
        if (k == "cpu_med") v = $3; else if (k == "cpu_max") v = $4;
        else if (k == "mem_med") { v = $5; u = $6 } else { v = $7; u = $8 }
        gsub("%", "", v);
        if (u == "GiB") v = v * 1024; else if (u == "KiB") v = v / 1024;
        print v }' "$d/recursos.txt"
    done
  }
  printf "| %s | %s | %s | %s | %s |\n" "$c" \
    "$(col cpu_med | mediana '%.1f')" "$(col cpu_max | mediana '%.1f')" \
    "$(col mem_med | mediana '%.1f')" "$(col mem_max | mediana '%.1f')"
done
