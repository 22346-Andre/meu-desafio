# Tempos iniciais com curl (aplicação original, sem carga)

Medidos com `time curl -s <url> > /dev/null`, duas execuções cada, antes de qualquer mudança.
São indicativos, não substituem o medir.sh.

| Rota | Execução 1 | Execução 2 |
|---|---|---|
| /relatorios/top-produtos?limite=10 | 0,901 s | 0,921 s |
| /clientes?email=cliente1@exemplo.com | 0,117 s | 0,109 s |
| /clientes/1/pedidos | 0,503 s | 0,510 s |
