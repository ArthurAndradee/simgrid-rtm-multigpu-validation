# Campanha 2026-10: dados novos

Esta branch (`campanha-2026-10`) reúne o que foi medido e simulado depois da
submissão ao SSCAD. O `main` continua sendo o artefato do artigo, sem
mudanças.

As figuras e tabelas do artigo foram refeitas com os dados novos, com as
mesmas métricas, a mesma janela de análise e o mesmo estilo dos scripts do
artigo. Estão todas em [`artigo_novos_dados/`](artigo_novos_dados/), cada uma
em PDF e PNG, nas versões `_pt` e `_en`.

## O que foi rodado

**1. Strong scaling, hardware real (chuc)**
- Todas as 101 formas de partição (triplas ordenadas px×py×pz) para
  np = 1, 2, 4, 8, 12, 16, 20 e 24, ou seja, de 1 a 6 nós.
- N = 968 fixo, 100 iterações, `--skip-output`, 5 repetições por forma
  (505 execuções).
- 1 GPU A100 por processo, 4 por nó, rede nativa (sem `tc`, sem `UCX_TLS`),
  forma imposta com a opção nova `--topology PX,PY,PZ` (`src/main.c`).
- Cada execução passou pela checagem de integridade do checkpoint (trace com
  todos os ranks, `dc.output` sem erro). Duas repetições de np=24 foram
  recusadas pela checagem (rastros de um nó ausentes) e refeitas
  automaticamente. O tamanho de partição gravado em cada `dc.output` confere
  com o plano nas 505.

**2. Simulações Level 2 (SimGrid/SMPI, sem GPU)**
- *As 12 configurações do artigo* (1–4 nós × 1/10/25 Gbit/s, mesmos N da
  Tabela 3), com as constantes de computação do artigo e duas políticas de
  compartilhamento do link de cada nó na plataforma:
  - `SHARED` (padrão do SimGrid, usada em todas as simulações do artigo):
    envio e recebimento de um nó dividem a mesma banda;
  - `SPLITDUPLEX`: cada sentido tem a banda inteira.
- *As 101 formas do strong scaling*, com constantes de computação extraídas
  por (forma, rank) dos traces reais, em duas plataformas (`SHARED`):
  25 Gbit/s e 45 Gbit/s (banda medida pelo netcal no modo nativo, ver abaixo).
- Calibração de rede: a herdada do poti (Cornebize), sem alteração
  (`simgrid-chuc-validation/calibrations/poti_cornebize.cfg`).
- Ambiente: `generate_platform_xml.py` + SimGrid 4.0 (Debian), na chirop-3.
  O Level 2 do artigo usou `platform_shared_nic.cpp` + o SimGrid do flake. Nas
  12 configurações com `SHARED`, a vazão simulada agora difere da do artigo em
  até 3,0% (1 nó e 25 Gbit/s: idêntica).
- O Level 1 (amostragem real na GPU) **não** foi refeito.

**3. Medições de rede na chuc (netcal)**
- [`netcal/netcal.c`](../netcal/netcal.c): amostras no estilo da calibração de
  Cornebize (tamanhos log-uniformes de 1 B a 16 MiB, ordem aleatória;
  pingpong, send, isend, recv, iprobe, test), 2 nós (chuc-2, chuc-3), 1 rank
  por nó, ~1,5 milhão de amostras em
  [`netcal/results/`](../netcal/results/) (`.csv.gz` + `.meta`).
- Condições: nativa; nativa com `UCX_MAX_RNDV_RAILS=1`; TCP + `tc tbf` a 25,
  10 e 1 Gbit/s (`UCX_TLS=tcp`, interface kavlan).
- `ucx_devices_*.txt`: saída de `ucx_info -d` nos nós.

Valores medidos (mensagens ≥ 8 MB para a banda; ≤ 64 B para a ida e volta):

| condição | banda efetiva | ida e volta |
|---|---|---|
| nativa | ~45 Gbit/s | 5,6 µs |
| nativa, `UCX_MAX_RNDV_RAILS=1` | 22,7 Gbit/s | 5,6 µs |
| TCP + tbf 25 Gbit/s | ~16 Gbit/s | 75 µs |
| TCP + tbf 10 Gbit/s | ~11 Gbit/s | 77 µs |
| TCP + tbf 1 Gbit/s | 0,965 Gbit/s | 65 µs |

## Métricas (as mesmas do artigo)

- **Vazão** e **tempo total**: linha global `*` do `dc.output` (janela de
  `dc_worker_process`, `src/main.c`).
- **ME**: 1 − (tempo em chamadas MPI / (janela × ranks)), com a janela do
  primeiro `MPI_Irecv` ao último `MPI_Waitall` entre todos os ranks
  (`analysis/masking_effectiveness.R`; no simulado, o mesmo cálculo com o
  prefixo `PMPI_` removido).
- **Erro de fidelidade**: vazão em % relativo; ME em pontos percentuais
  (simulado − real).
- **Real nas configurações do artigo**: os valores da Tabela 3 do artigo
  (`analysis/results_package/tables/part1_statistics.csv`).

## Itens do artigo refeitos

| artigo | arquivo(s) em `artigo_novos_dados/` | conteúdo |
|---|---|---|
| Tabela 3 | `tabela3_strongscale.{csv,tex}` | vazão e ME (média ± IC 95%, 5 reps) das 101 formas |
| Figura 2 | `figura2_strongscale_real_*` | linhas do tempo por rank, só real: melhor, mediana e pior forma (por vazão média) de cada np, de 1 a 6 nós (`_4linhas`: np = 4, 8, 16, 24) |
| Figura 2 | `figura2_strongscale_real_vs_level2_{25,45}gbps_*` | as mesmas formas, real (esq.) e Level 2 (dir.) na mesma célula |
| Figura 2 | `figura2_artigo_level2_{shared,splitduplex}_*` | as 12 configurações do artigo, real (esq.) e Level 2 (dir.), no layout da Figura 2 |
| Figura 3 | `figura3_strongscale_me_*`, `figura3_strongscale_vazao_*` | ME e vazão × np: um ponto por forma (média ± IC 95%) e a mediana das formas |
| Figura 4 | `figura4_artigo_level2_*` (+ `_dados_*.csv`) | (ganho 10→25) / (ganho 1→10), 2–4 nós: real do artigo, Level 2 SHARED e Level 2 SPLITDUPLEX |
| Tabela 4 | `tabela4_artigo_level2.{csv,tex}` | 12 configurações: real, Level 2 SHARED e SPLITDUPLEX, erros de vazão e ME; o CSV traz também o tempo da janela do laço |
| Tabela 4 | `tabela4_strongscale_level2.csv`, `figura_tabela4_strongscale_*` | 101 formas × 2 plataformas: real × simulado (vazão e ME) |

Notas:
- **Figura 4:** o strong scaling foi rodado em uma única condição de rede,
  então a Figura 4 só existe para as configurações do artigo. A barra "Real"
  reproduz exatamente a Figura 4 do artigo.
- **Figura 2:** em cada célula, as duas metades têm o eixo normalizado à
  própria janela; a duração absoluta está na faixa acima. Rank em ordem
  numérica.
- **Figura 3:** np = 1 não tem ME (não há chamadas MPI).
- **Paineis da Figura 2:** `figura2_strongscale_paineis.csv` e
  `figura2_strongscale_real*_paineis.csv` dizem qual forma e qual repetição
  (a de tempo total mediano) aparecem em cada painel.

## Dados

| caminho | conteúdo |
|---|---|
| `analysis/strongscale_por_topologia.csv` | uma linha por forma: média, desvio e IC 95% de vazão, tempo e ME |
| `analysis/strongscale_por_rep.csv` | uma linha por execução |
| `analysis/masking_effectiveness_strongscale_all505.csv` | ME por execução |
| `analysis/level2_compute_constants_strongscale.csv` | constantes de computação por (forma, rank) usadas no Level 2 |
| `g5k/results/strongscale_native_*/rep*/` | `dc.output`, `metadata.txt` e `hostfile.mpi` de cada execução real |
| `g5k/csv/strongscale_experiments.csv`, `strongscale_plan_status.csv` | plano das 101 formas |
| `simgrid-chuc-validation/results_level2_strongscale/`, `results_level2_paper/` | `dc.output` e `metadata.txt` de cada simulação |
| `artigo_novos_dados/me_simulado.csv` | ME de cada simulação (calculado dos traces simulados) |
| `netcal/results/` | amostras do netcal |

Os traces (`dc.csv`: ~5 GB reais, ~0,8 GB simulados) não estão no
repositório; estão no NFS do Grid'5000 (Lille).

## Código

| caminho | o que é |
|---|---|
| `src/main.c`, `include/coordinator.h` | opção `--topology` |
| `g5k/scripts/03-strongscale-orchestrator.sh` | orquestrador do strong scaling (`--np`, `--only-id`) |
| `g5k/scripts/05-session-plan.sh`, `05-wait-and-run.sh`, `06-extra-idea2.sh` | plano automático da sessão de 2026-10-02 |
| `g5k/lib/run.sh` | conversão do trace com `aky_converter -l` |
| `simgrid-chuc-validation/run_level2_strongscale.sh` | Level 2 das 101 formas (`CALIB=`, `NET_BW=`) |
| `simgrid-chuc-validation/run_level2_guarded.sh` | o mesmo, com vigia de memória (~14 GB por simulação) |
| `simgrid-chuc-validation/run_level2_paper.sh` | Level 2 das 12 configurações (`PLATFORM_NIC_SHARING`) |
| `simgrid-chuc-validation/generate_platform_xml.py` | plataforma com `PLATFORM_NIC_SHARING=SHARED\|SPLITDUPLEX` |
| `simgrid-chuc-validation/tests/bidir.c` | teste mínimo das duas políticas no simulador |
| `netcal/` | coletor e script de execução |
| `nic_contention_benchmark/` | microbench de contenção (ver o README da pasta) |

## Regenerar

Da raiz do repositório:

```sh
python3 analysis/build_strongscale_summary.py
# tabelas e figuras 3, 4 e da Tabela 4 (só o repositório):
Rscript campanha-2026-10/artigo_novos_dados/build_artigo_novos_dados.R
# figuras 2 (precisam dos traces):
REAL_TRACES=<.../g5k/results> SIM_TRACES=<.../simgrid-chuc-validation> \
  Rscript campanha-2026-10/artigo_novos_dados/build_artigo_novos_dados.R
RESULTS_DIR=<.../g5k/results> \
  Rscript campanha-2026-10/artigo_novos_dados/build_figura2_strongscale_real.R
```
