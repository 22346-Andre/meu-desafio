# Ambiente de medição

- Sistema: Windows, terminal Git Bash
- Docker Desktop 29.7.2, Compose v5.3.1
- Recursos do Docker: 12 CPUs, 7,69 GiB de memória
- Hardware: Ryzen 5 5600GT, 16 GB de RAM
- Condições: na tomada, plano de alto desempenho, programas pesados fechados
- Parâmetros de carga: padrão do medir.sh (VUS=20, DURACAO=60s, AQUECIMENTO=15s, SEMENTE=42)
- Execução no Git Bash com `MSYS_NO_PATHCONV=1`, para evitar que o Git Bash converta o caminho `/carga/teste-carga.js` dentro do container do k6. Nenhum arquivo de scripts/ foi alterado.
- Três tentativas iniciais de `medir.sh 00-linha-de-base` (03/11/2026, ~21:10) falharam antes da carga, com o erro "moduleSpecifier ... couldn't be found" do k6. Geraram só um contexto.txt, sem resumo.txt, e as pastas foram apagadas antes de qualquer commit.
