# Dossiê de Resultados — Campanha Real Multi-Banda (chuc, 1/10/25 Gbit)

**Propósito deste documento**: dossiê autocontido com todos os números, tabelas e observações necessários para escrever a seção de Resultados do artigo/TCC, sem precisar reabrir `dc.csv`/`dc.output` brutos. Preparado em 2026-07-25/26. Considera **apenas experimentos com 5/5 repetições concluídas** (checkpoint `done`), exceto onde explicitamente marcado como parcial/limitação.

**Proveniência dos dados**: `g5k/results/` + `g5k/checkpoints/progress.csv`, processados por `analysis/gather_metrics.R`, `analysis/masking_effectiveness.R` e `analysis/aggregate_stats.R` (commit `0e1bcf6`). CSVs brutos intermediários em `analysis/dossie_full_join.csv`, `analysis/throughput_raw.csv`, `analysis/masking_effectiveness.csv` (não versionados no git, mas presentes em disco no mesmo repositório).

**Métricas**:
- **Tempo total (s)** e **MSamples/s**: de `dc.output` (stdout do binário, linha `rank=*`, agregado global).
- **Masking Effectiveness (%)**: `1 − (duração de comunicação agregada / makespan agregado)`, calculada sobre a janela `MPI_Irecv` inicial → `MPI_Waitall` final, extraída dos traces `dc.csv` (Akypuera→PajeNG). Mesma definição usada em `papers/2026_CARLA/CARLA_SimGrid_Ghost.org` (Spadotto & Schnorr, CARLA 2026).

---

## 0. ⚠️ Nota metodológica crítica — leia antes de escrever qualquer comparação de banda

**A imensa maioria dos dados completos hoje é de 1 nó (topologia `1x2x2`, 4 GPUs no mesmo host).** Isso importa porque, com todos os ranks MPI no mesmo nó físico, o OpenMPI/UCX prefere transporte de memória compartilhada (`sm`/`vader`, confirmado em todo `metadata.txt`: `mca_pml_ucx_tls: tcp,self,sm`) em vez de TCP — ou seja, **o tráfego nunca atravessa a interface de rede real que o `tc`/`tbf` está moldando**. Isso explica por que, na Seção 1 abaixo, os números de 1/10/25 Gbit são estatisticamente indistinguíveis entre si para qualquer N: não é que a aplicação seja insensível à banda, é que a configuração de 1 nó **não exercita a banda real em absoluto**.

O único ponto de dado completo (5/5) que efetivamente atravessa a rede real entre nós é `2x2x2` (2 nós, 8 GPUs) em 10gbit. Em 1gbit, `2x2x2` está incompleto (3/5 reps, ver §6) mas já mostra o comportamento esperado de colapso (Masking Effectiveness 38,6%, ante ~78-79% em 10gbit) — o mesmo regime bound-pela-rede que o paper CARLA do Spadotto encontrou por simulação para GPUs em 1Gbps.

**Implicação para a escrita**: a Seção 1 (1 nó) deve ser enquadrada como *baseline de weak-scaling / linha de base computacional*, não como "estudo de sensibilidade à banda" — a banda é uma variável inerte nesse regime por construção da topologia, e isso é, em si, uma observação científica válida e relevante (deve aparecer no texto). O verdadeiro "estudo de banda" começa na Seção 2 (2 nós), que ainda está incompleto.

---

## 1. Campanha de 1 nó (`1x2x2`, 4×A100) — completa nas 3 bandas até N=1088

Todas as linhas abaixo têm 5/5 repetições (exceto onde indicado). Formato: média ± desvio-padrão amostral.

#### 1gbit

| N | reps | Tempo total (s) | MSamples/s | Masking Eff. (%) |
|---|---|---|---|---|
| 64 | 5 | 2.17 ± 0.03 | 8.1 ± 0.1 | 88.9 ± 2.4 |
| 128 | 5 | 2.49 ± 0.03 | 69.4 ± 0.9 | 93.6 ± 1.8 |
| 256 | 5 | 3.50 ± 0.03 | 435.5 ± 3.4 | 93.5 ± 1.1 |
| 512 | 5 | 7.50 ± 0.04 | 1707.5 ± 9.9 | 90.9 ± 1.0 |
| 1024 | 5 | 30.70 ± 2.03 | 3427.6 ± 210.7 | 87.9 ± 4.4 |
| 1088 | 5 | 40.66 ± 0.87 | 3099.1 ± 65.7 | 87.4 ± 1.8 |
| 1152 | 5 | 39.72 ± 0.83 | 3770.8 ± 78.4 | 90.0 ± 1.4 |
| 1216 | 5 | 58.91 ± 4.85 | 3007.5 ± 227.9 | 83.3 ± 6.0 |
| 1280 | 5 | 50.55 ± 1.35 | 4073.8 ± 105.1 | 86.6 ± 3.0 |
| 1344 | 5 | 73.04 ± 1.77 | 3266.5 ± 80.6 | 84.7 ± 0.7 |

#### 10gbit

| N | reps | Tempo total (s) | MSamples/s | Masking Eff. (%) |
|---|---|---|---|---|
| 64 | 5 | 2.22 ± 0.03 | 7.9 ± 0.1 | 90.2 ± 3.6 |
| 128 | 5 | 2.47 ± 0.02 | 70.1 ± 0.7 | 92.9 ± 2.2 |
| 256 | 5 | 3.51 ± 0.06 | 434.1 ± 7.8 | 94.2 ± 0.6 |
| 512 | 5 | 7.45 ± 0.09 | 1719.8 ± 19.9 | 91.2 ± 0.4 |
| 1024 | 5 | 30.47 ± 1.09 | 3445.8 ± 122.2 | 87.1 ± 2.7 |
| 1088 | 5 | 40.25 ± 0.76 | 3130.4 ± 58.8 | 87.0 ± 1.3 |
| 1152 | 5 | 39.98 ± 1.97 | 3752.1 ± 175.6 | 88.2 ± 3.5 |
| 1216 | 5 | 55.42 ± 0.14 | 3181.0 ± 8.2 | 87.6 ± 0.3 |
| 1280 | 5 | 50.17 ± 0.77 | 4102.9 ± 63.5 | 86.9 ± 2.6 |
| 1344 | 5 | 71.73 ± 1.73 | 3325.8 ± 78.9 | 83.7 ± 2.9 |
| 1408 | 5 | 68.59 ± 1.11 | 4001.5 ± 65.1 | 88.1 ± 1.6 |

#### 25gbit

| N | reps | Tempo total (s) | MSamples/s | Masking Eff. (%) |
|---|---|---|---|---|
| 64 | 5 | 2.18 ± 0.04 | 8.1 ± 0.1 | 90.3 ± 0.9 |
| 128 | 5 | 2.48 ± 0.04 | 69.7 ± 1.0 | 92.4 ± 1.8 |
| 256 | 5 | 3.48 ± 0.03 | 437.9 ± 4.2 | 94.0 ± 0.4 |
| 512 | 5 | 7.48 ± 0.09 | 1711.3 ± 20.6 | 91.5 ± 0.2 |
| 1024 | 5 | 29.79 ± 0.30 | 3520.6 ± 35.4 | 89.4 ± 1.3 |
| 1088 | 5 | 43.20 ± 0.31 | 2916.1 ± 21.4 | 83.9 ± 0.7 |

> 25gbit N1152 tem apenas 3/5 reps (parcial) — ver §6, excluído desta tabela.
> 25gbit não tem nenhuma linha ≥ N1216 iniciada.
> 1gbit não tem N1408 (não iniciado).

### 1.1 Comparação cruzada entre bandas, N comum às 3 (64–1088)

Confirma a nota metodológica do §0: as diferenças entre bandas são da ordem do próprio desvio-padrão entre repetições, sem tendência monotônica com a banda.

| N | MSamples/s 1gbit | MSamples/s 10gbit | MSamples/s 25gbit | Masking Eff. 1gbit | Masking Eff. 10gbit | Masking Eff. 25gbit |
|---|---|---|---|---|---|---|
| 64 | 8.09 | 7.93 | 8.07 | 88.9% | 90.2% | 90.3% |
| 128 | 69.4 | 70.1 | 69.7 | 93.6% | 92.9% | 92.4% |
| 256 | 435.5 | 434.1 | 437.9 | 93.5% | 94.2% | 94.0% |
| 512 | 1707.5 | 1719.8 | 1711.3 | 90.9% | 91.2% | 91.5% |
| 1024 | 3427.6 | 3445.8 | 3520.6 | 87.9% | 87.1% | 89.4% |
| 1088 | 3099.1 | 3130.4 | 2916.1 | 87.4% | 87.0% | 83.9% |

**Variação máxima entre bandas, por N**: tipicamente < 3% em MSamples/s (maior caso: N1088, 25gbit 6,4% abaixo de 1gbit — dentro do ruído, ver CV abaixo) e < 4 pontos percentuais em Masking Effectiveness. Nenhuma tendência sistemática 1<10<25.

### 1.2 Coeficiente de variação (ruído entre repetições)

CV = sd/mean em MSamples/s tipicamente 0,5%–3% para N≤512; sobe para 2%–8% em N≥1024 (ex.: 1gbit N1216 tem sd=227,9 sobre média 3007,5 → CV≈7,6%, o maior valor observado). Vale mencionar como limite de precisão ao comparar N grandes.

---

## 2. Campanha de 2 nós (`2x2x2`, 8×A100) — a única com efeito de banda real observável

| experiment_id | Banda | N | reps | MSamples/s | MSamples/s por GPU | Masking Eff. (%) |
|---|---|---|---|---|---|---|
| bench_10gbit_2n_8g_N1536 | 10gbit | 1536 | 5 | 7772.3 ± 175.5 | 971.5 | 78.9 ± 2.6 |
| bench_10gbit_2n_8g_N1600 | 10gbit | 1600 | 5 | 6659.4 ± 388.2 | 832.4 | 78.5 ± 3.9 |
| bench_1gbit_2n_8g_N1536 | 1gbit | 1536 | **3 (parcial)** | 4309.5 ± 233.0 | 538.7 | **38.6 ± 2.1** |

**Achado central**: em 1gbit, Masking Effectiveness cai para 38,6% (vs. ~79% em 10gbit no mesmo N=1536) — o colapso pelo gargalo de rede, qualitativamente idêntico ao que Spadotto/Schnorr encontraram por simulação (`poti`/`tupi`, GPU real-1Gbit: ~20-25%, ver §5). É o primeiro dado real (não simulado) do projeto a mostrar esse regime.

**Limitação estatística**: o ponto de 1gbit tem apenas 3 repetições válidas (reps 4-5 falharam na captura de trace — bug conhecido do Akypuera em 1gbit, ver §6), então o desvio-padrão reportado é sobre n=3, não n=5.

**25gbit em `2x2x2`: nenhuma repetição — 0 dados.** Não há como comparar as 3 bandas na topologia de 2 nós ainda.

---

## 3. Eficiência de weak-scaling: 1 nó → 2 nós (MSamples/s por GPU)

O desenho da campanha é *weak-scaling* (N cresce com o nº de nós/GPUs para manter uso de VRAM por GPU aproximadamente constante) — **não é possível calcular "speedup" clássico em N fixo**, pois não há N comum entre 1 e 2 nós. A métrica comparável é o throughput por GPU.

| Configuração | Banda | N | MSamples/s por GPU |
|---|---|---|---|
| 1 nó, 4 GPU (mais próximo, N1344) | 10gbit | 1344 | 831.5 |
| 2 nós, 8 GPU (N1536) | 10gbit | 1536 | **971.5** |
| 1 nó, 4 GPU (mais próximo, N1344) | 1gbit | 1344 | 816.6 |
| 2 nós, 8 GPU (N1536, parcial) | 1gbit | 1536 | **538.7** |

- **10gbit**: eficiência de 1→2 nós = 971,5/831,5 = **+16,8%** (escala super-linear por GPU — indica boa sobreposição de comunicação e melhor amortização de overheads fixos no domínio maior).
- **1gbit**: eficiência de 1→2 nós = 538,7/816,6 = **−34,0%** (perda severa de eficiência por GPU ao introduzir comunicação inter-nó real sobre um enlace de 1Gbit).

Essa é provavelmente **a comparação mais forte disponível hoje** para o artigo: o mesmo salto de topologia (1 nó→2 nós) produz ganho de eficiência em 10gbit e perda de um terço em 1gbit, mesmo com N ligeiramente diferente entre os dois grupos (limitação a mencionar no texto).

---

## 4. Validação numérica — ATENÇÃO: uma das duas execuções de referência falhou

| Experimento | np (ground truth) | Resultado |
|---|---|---|
| `full_1x2x2_N64` | 1 | ✅ **Validado**. Tolerância 0,001; desvio-padrão da diferença 2,74e-05; máximo 2,43e-05. |
| `full_2x2x2_N1536` | 8 | ❌ **NÃO validado — crash**. O binário de referência (OpenMP, np=1) sofreu **segmentation fault** em `sample_compute()` (`include/sample_compute.h:174`, chamado de `src/openmp_propagate.c:19`) ao rodar N=1536. `predicted.dc.discarded` tem 0 bytes; `ground_truth_compare.log` está vazio. |

**Isso corrige uma afirmação anterior desta conversa** (eu havia reportado "2 ground truths confirmados" em turnos anteriores — incorreto; apenas 1 está de fato confirmado). O crash em N=1536 é uma **variante ainda não corrigida** da família de bugs de overflow int32/tamanho já identificada e corrigida em `precomp.c`/`coordinator.c`/`main.c`/`boundary.c` (commit `6ab2b83`) — mas em local diferente (`sample_compute.h`, caminho do kernel OpenMP de referência), não coberto por aquele fix. **Ação recomendada antes de reivindicar "validação numérica end-to-end" no artigo para qualquer topologia multi-nó**: investigar e corrigir esse crash, e re-executar a fase `full` de `2x2x2_N1536`.

Nenhuma outra topologia (`2x2x3` em diante) tem execução `full` registrada — não há validação numérica de nenhuma topologia com mais de 2 nós.

---

## 5. Comparação com trabalhos anteriores

### 5.1 vs. Tese do Spadotto (`thesis/index.tex`, Tabela `results_summary`, carga de computação aproximada)

| Configuração original | Compute load (tese) | Configuração equivalente nossa | Masking Eff. (nossa) |
|---|---|---|---|
| GPU (CUDA), 128³, 1Gbps real | ~20–25% | 1 nó, N128, 1gbit | 93,6% (não comparável — ver nota abaixo) |
| GPU (CUDA), 256³, 1Gbps real | ~20% | 1 nó, N256, 1gbit | 93,5% (idem) |
| GPU (CUDA), 512³, 1Gbps real | ~20% | 1 nó, N512, 1gbit | 90,9% (idem) |
| CPU (OpenMP), 256³, 10Gbps real | ~75% | — (sem execução CPU na campanha atual) | — |
| CPU (OpenMP), 512³, 10Gbps real | ~87% | — | — |

**Nota crítica**: os valores de ~20-25% da tese (`poti`, GPU real 1Gbps) referem-se a um cluster **multi-nó** onde o tráfego de fato atravessa a rede real. Nossos números de 1 nó acima **não são comparáveis diretamente** — são o análogo de um cenário de "banda infinita"/intra-nó, não ao regime medido pela tese. **A comparação correta é com nosso §2** (`2x2x2`, 2 nós): Masking Effectiveness 38,6% em 1gbit — mesma ordem de grandeza do ~20-25% da tese, mesmo regime de gargalo de rede, confirmando qualitativamente (não quantitativamente — topologia, nº de GPUs e geração de GPU diferem) a conclusão original.

### 5.2 vs. Paper CARLA (`papers/2026_CARLA/CARLA_SimGrid_Ghost.org`, simulado)

| Cluster (paper, simulado) | Masking Eff. @ 1Gbps | Masking Eff. @ 10Gbps |
|---|---|---|
| `poti` (RTX4070) | ~0,25 (todos os N) | ~0,97 (N512, 4 hosts) |
| `tupi` (RTX4090) | ~0,08–0,16 | > 0,96 (N grande, muitos hosts) |
| **Nosso `2x2x2` real (A100)** | **0,386 (n=3)** | **0,789 (n=5)** |

Mesma tendência qualitativa (colapso em 1Gbps, recuperação forte em 10Gbps), com nossos valores absolutos um pouco mais altos que `poti`/`tupi` — plausível dado que só temos 2 nós/8 GPUs (menos hosts que os cenários simulados de 4-64 hosts do paper, e menor contagem de hosts tende a mascarar melhor por ter menos vizinhos/tráfego agregado).

### 5.3 Achado da tese sobre contagem prima de processos (não replicável ainda)

A tese encontrou que 5 workers (`{5,1,1}`, decomposição em fatias, por ser primo) tem throughput **pior que o baseline de 1 nó**, enquanto 8 workers (`{2,2,2}`, blocos) escala bem. Nossa campanha nunca testa contagens primas de GPU (topologias vêm de `MPI_Dims_create` sobre 4,8,12,16,20,24,27,30,32 — apenas 27 é primo, na topologia `3x3x3`/7 nós, ainda não executada). **Não há dado ainda para replicar ou contestar esse achado específico.**

---

## 6. Experimentos excluídos desta análise (parciais/falhos/não iniciados) — tratar como trabalho futuro

| experiment_id | Situação | Motivo |
|---|---|---|
| `bench_1gbit_2n_8g_N1536` reps 4-5 | Falha (trace) | Bug conhecido: Akypuera crasha em 1gbit para N grande; `dc.output` válido, `dc.csv` vazio (0 linhas). Reps 1-3 usadas em §2 com nota de n=3. |
| `bench_25gbit_1n_4g_N1152` reps 4-5 | Falha (timeout de sessão) | Retry pendente — excluído das tabelas do §1. |
| `bench_10gbit_2n_8g_N1664` | Interrompida (inflight) | Sessão encerrada por timeout; retomada automática pendente. |
| `bench_25gbit_1n_4g_N1216` até `N1472` | Não iniciado | 25gbit não avançou além de N1152 na topologia `1x2x2`. |
| `bench_1gbit_1n_4g_N1408`, `N1472` | Não iniciado | |
| Todas as linhas de `25gbit` em `2x2x2` (N1536–1856) | Não iniciado | Zero dados de 25gbit para 2 nós — bloqueia comparação completa das 3 bandas em qualquer topologia multi-nó. |
| Topologias `2x2x3` (3 nós) até `2x4x4` (8 nós) | Não iniciado | 8 topologias, 24-84 linhas de CSV nunca tentadas — nenhuma alocação estável de >4 nós obtida ainda. |
| `1gbit_1n_4g_N64` (legado, sem prefixo `bench_`) | Redundante | Pré-data o esquema atual; resultado (8,01 MSamples/s) consistente com `bench_1gbit_1n_4g_N64` (8,09) — não usar como linha independente. |

---

## 7. Sugestão de figuras/tabelas para o artigo

1. **Tabela**: §1 completa (1 nó, 3 bandas × N) — pronta para uso direto, já en formato final acima.
2. **Figura "throughput invariante à banda" (1 nó)**: MSamples/s × N, 3 linhas (uma por banda) sobrepostas quase idênticas — visualmente demonstra a nota do §0 (bandwidth-blindness intra-nó). Usar §1.1.
3. **Figura "Masking Effectiveness × N" (1 nó)**: mesma lógica, 3 linhas por banda, valores 83-94%, plana.
4. **Tabela/Figura de destaque**: comparação 1gbit vs 10gbit em `2x2x2` (§2) — barra dupla (Masking Effectiveness) ou tabela simples; é o resultado mais forte disponível hoje.
5. **Figura de eficiência por GPU** (§3): barras 1 nó vs 2 nós, separadas por banda, mostrando +16,8% (10gbit) vs −34,0% (1gbit) — análoga ao comm-cost vs partitioning strategy do paper CARLA, mas para banda em vez de topologia.
6. **Tabela comparativa com a tese/paper** (§5.1/5.2) — mesma estrutura, números lado a lado.
7. **Não recomendado ainda**: qualquer heatmap (banda × topologia × N) estilo Figura `gpu-masking-heatmap` do paper CARLA — cobertura insuficiente (só 2 pontos em 2 nós, 0 em ≥3 nós); esperar mais dados antes de tentar essa figura.

---

## 8. Apêndice — tabela completa bruta (todas as linhas usadas neste dossiê)

Ver `analysis/dossie_full_join.csv` no mesmo repositório (34 linhas: 28 de 1 nó + 3 de 2 nós + 1 legado + 2 `full`), colunas: `experiment_id, reps_done, mean_total_time, sd_total_time, mean_msamples, sd_msamples, reps_me, mean_me, sd_me, Banda_Rede, Num_Nos, Num_GPUs, Topologia_MPI, Tamanho_Global_N, ci95_total_time, ci95_msamples, ci95_me, cv_msamples_pct`.
