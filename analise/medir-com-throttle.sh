#!/usr/bin/env bash
# Roda scripts/medir.sh e resume o throttling do cgroup (cpu.stat) do banco e da API durante a execução.
# Uso (na raiz do repositório): bash analise/medir-com-throttle.sh 11-api-menor
# O resumo também é anexado a /tmp/throttle-resumo.txt (fora do repositório, para não sujar o Git entre as execuções).
set -uo pipefail
export MSYS_NO_PATHCONV=1

rotulo="${1:?informe o rótulo, ex.: 11-api-menor}"

cpu_stat() { docker compose exec -T "$1" cat /sys/fs/cgroup/cpu.stat | tr -d '\r'; }
campo() { echo "$2" | awk -v k="$1" '$1 == k {v = $2} END {print v + 0}'; }

resumo() { # resumo <nome> <antes> <depois>
  local p t u
  p=$(( $(campo nr_periods "$3") - $(campo nr_periods "$2") ))
  t=$(( $(campo nr_throttled "$3") - $(campo nr_throttled "$2") ))
  u=$(( $(campo throttled_usec "$3") - $(campo throttled_usec "$2") ))
  awk -v nome="$1" -v p="$p" -v t="$t" -v u="$u" 'BEGIN { printf "  %-6s períodos ativos: %d | com throttling: %d (%.1f%%) | throttled_usec somado: %.1f s (soma entre CPUs, pode passar do tempo de relógio)\n", nome, p, t, (p > 0 ? 100 * t / p : 0), u / 1000000 }'
}

antes_banco=$(cpu_stat banco); antes_api=$(cpu_stat api)
scripts/medir.sh "$rotulo"
depois_banco=$(cpu_stat banco); depois_api=$(cpu_stat api)

{
  echo "Throttling do cgroup durante a execução de $rotulo ($(date +%H:%M:%S)):"
  resumo banco "$antes_banco" "$depois_banco"
  resumo api "$antes_api" "$depois_api"
} | tee -a /tmp/throttle-resumo.txt
