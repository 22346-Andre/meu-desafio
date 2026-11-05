#!/usr/bin/env bash
# Pico numérico de CPU e memória por container, lendo o recursos.csv de cada execução de um rótulo.
# Existe porque o cpu_max do recursos.txt compara valores como texto (ver diagnostico/cpu-max-recursos.txt).
# Uso (na raiz do repositório): bash analise/picos.sh 02-indice-pedidos-cliente
set -euo pipefail

rotulo="${1:?informe o rótulo, ex.: 02-indice-pedidos-cliente}"
pastas=(resultados/*-"$rotulo")
[ -d "${pastas[0]}" ] || { echo "nenhuma pasta para $rotulo" >&2; exit 1; }

echo "| execução | container | pico de CPU (%) | pico de memória (MiB) |"
echo "|---|---|---|---|"
for d in "${pastas[@]}"; do
  awk -F, -v pasta="$(basename "$d")" 'NR > 1 {
    c = $3; gsub("%", "", c); c += 0
    split($4, partes, " "); m = partes[1]
    if (m ~ /GiB/) { sub("GiB", "", m); m = m * 1024 } else if (m ~ /KiB/) { sub("KiB", "", m); m = m / 1024 } else { sub("MiB", "", m) }
    m += 0
    if (c > pc[$2]) pc[$2] = c
    if (m > pm[$2]) pm[$2] = m
    vistos[$2] = 1
  } END {
    for (n in vistos) printf "| %s | %s | %.2f | %.1f |\n", pasta, n, pc[n], pm[n]
  }' "$d/recursos.csv" | sort
done
