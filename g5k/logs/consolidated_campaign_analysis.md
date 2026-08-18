# Consolidação do espaço experimental da campanha — análise crítica

Sessão 2026-07-14 (cont.). Documento de CONSOLIDAÇÃO E ANÁLISE. Nenhum código ou
script de infraestrutura foi alterado. Complementa (não substitui)
`finalization_feasibility_map.md`, `benchmark_flag_proposal.md` e
`campaign_infrastructure_design.md`, já existentes nesta pasta.
Planilha associada: `g5k/logs/consolidated_campaign_matrix.csv` (105 linhas).

Rótulos herdados da convenção já em uso no projeto: **[EMP]** medido
diretamente; **[DOC]** derivado de código/config lidos; **[MODELO]** estimado
por um modelo calibrado (não é medição direta); **[HIP]** hipótese ainda não
testada.

## 0. Proveniência dos dados desta consolidação

Todas as colunas da planilha vêm de uma destas fontes, sem invenção de números:

- `g5k/csv/experimentos.csv` — as 105 linhas oficiais (Banda, Nós, GPUs,
  Topologia, N, dimensão local pior caso, VRAM estimada pelo CSV).
- `g5k/checkpoints/progress.csv` — ledger real de execução: **apenas 6 linhas
  existem nele**, cobrindo 2 células (`1gbit_1n_4g_N64`: 5/5 reps done;
  `1gbit_2n_8g_N1536`: 1 rep failed). Todo o resto da campanha nunca foi
  submetido ao orquestrador.
- `results/*` e `g5k/results/*` — 24 diretórios de execução real (campanha +
  ad hoc), com `metadata.txt`, `dc.output`, tamanhos em disco medidos via `du`.
- `oarstat -f` — walltime solicitado vs. concedido vs. usado dos jobs OAR
  2165368 (10/07) e 2167768 (14/07); ambos **esgotaram o walltime concedido**
  (não terminaram por decisão, terminaram porque a reserva expirou).
- `validation/` — estado real do pipeline de validação numérica (ver §5.4).
- `src/*.c`, `include/*.h` — fórmulas de tamanho (STENCIL=4, `include/definitions.h:4`),
  volume de gather (`worker.c:410-413`), modelo de finalização
  (`coordinator.c:183-205`), e **verificação de uma afirmação da sessão
  anterior sobre vizinhança de halo** (§4.3).
- Tese (`thesis/index.tex`) — arquitetura documentada e limite de validação
  numérica histórica (≤512³).

Fórmulas usadas na planilha (todas [DOC], verificadas contra pelo menos um
caso [EMP]):
- Arquivo de saída: `2 × N³ × 4 bytes` (campos pc+qc, cubo global de lado N).
  Verificado byte-a-byte: N=1536 → 28.991.029.248 bytes, idêntico ao tamanho
  real de `validation/predicted_1gbit_2n_8g_N1536_rep*.dc`.
- Volume do gather por worker: `Dimensao_Local_Pior_Caso` (array **completo**,
  incluindo halo — é o que `worker.c:410` de fato envia via `MPI_Send`, não
  o interior) `× 4 bytes × 2 campos (pc,qc)`. É um **limite superior**: só o
  worker que absorve o resto de cada eixo atinge exatamente esse tamanho; os
  demais são um pouco menores.
- Tempo de finalização: `T_final = GPUs × interior_local × 2 × 0.959µs/par`,
  calibrado no Teste 4 (10gbit, N=1536, `/dev/null`, 14/07). Recalculei essa
  tabela **independentemente** nesta sessão (script próprio, não copiado de
  `finalization_feasibility_map.md`) e os 35 valores batem exatamente com os
  já publicados — é uma segunda confirmação do modelo, não uma repetição cega.
- VRAM real estimada: `VRAM_CSV / 1.86` (achado [DOC] de `campaign_infrastructure_design.md`
  §4: o backend CUDA aloca 6 arrays, não os ~11 que a coluna do CSV assume).
  Continua **[EMP]-PENDENTE** — nenhum `nvidia-smi --query-gpu=memory.used`
  foi de fato coletado durante uma execução N≥1536 nesta consolidação.

## 1. Panorama quantitativo

| Métrica | Valor |
|---|---|
| Linhas no grid oficial | 105 (35 configurações únicas nós×N × 3 bandas) |
| Linhas com execução oficial completa (via orquestrador) | **1** (`1gbit_1n_4g_N64`, 5/5 reps) |
| Linhas com tentativa oficial registrada e falhada | **1** (`1gbit_2n_8g_N1536`, deadlock) |
| Linhas com dado de desempenho real, mas fora do checkpoint (diagnóstico ad hoc) | **2** (N=1536 2n/8g em 10gbit e 25gbit, via `/dev/null`) |
| Linhas nunca executadas em nenhuma forma | **101 / 105 (96,2%)** |
| Linhas estruturalmente inviáveis com o código atual (Mecanismo A — deadlock 1gbit multi-nó) | 23 / 105 |
| Maior T_final estimado (1 rep) | 13,56 h (N=2944, 8 nós, 32 GPUs) |
| Maior arquivo de saída projetado | 204,1 GB (N=2944) |
| Maior volume de gather por worker projetado | 6,79 GB (pc+qc, N=2816) |
| Walltime das duas sessões já realizadas | 100% consumido em ambas (job 2165368: 4h52 concedidas, usadas; job 2167768: 6h59 concedidas, usadas) |

**Leitura honesta**: a campanha, tal como desenhada no CSV de 105 linhas, está
essencialmente **não executada**. As duas sessões de alocação já realizadas
(10/07 e 14/07) produziram, no total, **um ponto de dado científico oficial
completo** (N=64 single-node) e uma investigação de causa-raiz muito bem
documentada sobre por que o resto não estava rodando. Isso não é uma crítica —
é exatamente o tipo de trabalho de fundação que evita desperdiçar reservas
grandes rodando algo que trava — mas significa que **nenhuma alegação sobre
"o modelo SimGrid vale/não vale em escala real" pode ainda ser feita**: só
há evidência real em N=64 (trivial) e em dois pontos de N=1536 (10gbit/25gbit,
sem escrita real em disco, fora do checkpoint formal).

## 2. A planilha consolidada

Arquivo: `consolidated_campaign_matrix.csv` (a ser copiado para
`g5k/logs/consolidated_campaign_matrix.csv`), 105 linhas × 23 colunas:

`Banda_Rede, Num_Nos, Num_GPUs_Total, GPUs_por_No, Procs_MPI_por_No,
Topologia_MPI, Cluster, Tamanho_Global_N, Num_Workers,
Dimensao_Local_PiorCaso, TCP_Shaping, VRAM_GB_CSV,
VRAM_GB_Estimativa_Real_6arrays, Tempo_Fase_Computacional_s, Msamples_por_s,
Tempo_Finalizacao_Estimado_1rep_h, Tempo_Finalizacao_Estimado_5rep_h,
Tempo_Total_ComEscrita_Medido_s, Gather_por_Campo_GB_por_Worker,
Gather_Total_por_Worker_GB_pc_qc, Volume_Total_Gather_UpperBound_GB,
Tamanho_Arquivo_Saida_GB, Mecanismo_A_Deadlock_1gbit_MultiNo,
Walltime_Job_Sessao, Estado_Execucao, Observacoes`

Notas sobre colunas que **não** pude preencher com dado medido para a maioria
das linhas (deixadas como `N/D`, nunca inventadas):
- `Tempo_Fase_Computacional_s` e `Msamples_por_s`: só existem [EMP] para as 4
  linhas com execução real (§1). Para as outras 101, não há medição — extrapolar
  seria uma nova hipótese, não um fato, e o próprio objetivo desta etapa é não
  misturar as duas coisas.
- `Tempo_Total_ComEscrita_Medido_s` (com escrita **real** em disco NFS, não
  `/dev/null`): **não existe para nenhuma linha com N≥1536**. Mesmo os testes
  t4/t5 (que completaram) usaram `--output-file=/dev/null` — isolam Causa 1
  (rede) e a parte CPU-bound de Causa 2 (chamadas de syscall), mas **não**
  medem o custo real de I/O em NFS (~4MB/s, observado no Teste 1, native,
  morto antes de completar). Isso é uma lacuna real, não apenas uma
  simplificação de conveniência — ver §5.5.
- Volume total de comunicação (`Volume_Total_Gather_UpperBound_GB`) é
  deliberadamente um limite superior (todos os workers no tamanho pior-caso);
  o valor real é levemente menor pois só workers de canto absorvem o resto.
- Não incluí uma coluna de "armazenamento gerado (trace+csv+output+rst)" por
  linha do CSV oficial porque **não há modelo calibrado para o tamanho do
  traço Akypuera** em função de N/reps — isso é uma lacuna já apontada em
  `campaign_infrastructure_design.md` (O4, buffer de 1GB) e seria inventar um
  número. Os tamanhos medidos das 24 execuções reais (2.5MB a 5.7MB de trace
  para os `.rst`, dominado por N pequeno) estão nas observações da planilha,
  mas não escalam de forma conhecida para N grande.

## 3. Estrutura experimental: dois eixos ortogonais + um terceiro de confundimento

A campanha não é uma varredura arbitrária de 105 pontos — tem uma estrutura
de desenho de experimento (DoE) clara, e vale nomeá-la explicitamente antes
de julgar qualquer célula individual.

### 3.1 Eixo A — weak scaling (nós × N crescendo juntos): a espinha dorsal das 35 configurações

Dentro de cada patamar de número de nós, N cresce até o próximo patamar
"herdar" o maior tamanho local. O tamanho de partição por worker (pior caso)
fica **aproximadamente estável** entre patamares — isto é desenho de *weak
scaling* clássico (mais recursos, problema proporcionalmente maior, carga por
worker ~constante), e é o eixo que responde diretamente à pergunta central do
projeto ("o padrão previsto continua quando aumentamos a escala do problema
E da infraestrutura junto").

| Nós | GPUs | Topologia(s) | N (min–max do patamar) | Dim. local pior caso (min–max) | T_final 1 rep (min–max) |
|---:|---:|:---|---:|:---|:---|
| 1 | 4 | 1x2x2 | 64 – 1472 | 64³ – 1472×740×740 | 0 s – 1,67 h |
| 2 | 8 | 2x2x2 | 1536 – 1856 | 772³ – 932³ | 1,90 h – 3,36 h |
| 3 | 12 | 2x2x3 | 1920 – 2112 | 964×964×648 – 1060×1060×712 | 3,74 h – 4,98 h |
| 4 | 16 | 2x2x4 | 2176 – 2368 | 1092×1092×552 – 1188×1188×600 | 5,45 h – 7,03 h |
| 5 | 20 | 2x2x5 | 2432 – 2496 | 1220×1220×495 – 1252×1252×508 | 7,62 h – 8,25 h |
| 6 | 24 | 2x2x6 / 2x3x4 | 2560 – 2688 | 1284×1284×435 – 1348×1348×456 (+2x3x4 à parte) | 8,89 h – 10,29 h |
| 7 | 27 | 3x3x3 | 2752 – 2816 | 926³ – 947³ | 11,13 h – 11,91 h |
| 8 | 30 / 32 | 2x3x5 / 2x4x4 | 2880 / 2944 | 1444×968×584 / 1476×744×744 | 12,69 h / 13,56 h |

**Interesse científico**: é o único eixo que testa simultaneamente as duas
metades da pergunta de pesquisa ("tamanho do problema" e "tamanho da
infraestrutura"). Um SimGrid calibrado em escalas pequenas que continue
prevendo corretamente o comportamento real ao longo *desta* coluna é a
evidência mais forte possível do domínio de validade do modelo.
**Hipótese que valida/refuta**: "o erro relativo real-vs-SimGrid permanece
dentro do envelope de calibração conforme nós e N crescem juntos" — se o erro
crescer sistematicamente com o patamar, é evidência de fronteira de validade;
se permanecer estável, é evidência de robustez.
**Não há redundância** entre patamares — cada um usa um número de GPUs
diferente e testa uma topologia MPI distinta.
**Lacuna evidente**: hoje só o patamar de 1 nó (N≤1472) foi de fato usado
como âncora histórica de validação numérica (tese, ≤512³, um subconjunto
ainda menor). **Nenhum patamar multi-nó tem um único rep completo até o
fim com escrita real.**

### 3.2 Eixo B — sweep de N a recursos fixos (dentro de cada patamar): masking effectiveness

Dentro de cada patamar (ex.: 1 nó, N=64→1472 em 12 passos), o número de
GPUs e a topologia MPI são **fixos**; só N cresce. Isso não é weak nem
strong scaling — é uma varredura da razão computação/comunicação a recursos
constantes, que é exatamente o eixo que o artigo CARLA (`papers/2026_CARLA`,
"Communication Masking Progression") já explorou **em simulação**. O
propósito científico aqui é validar se a curva de "masking effectiveness"
(fração da comunicação escondida atrás da computação) prevista pelo SimGrid
continua válida em hardware real conforme as mensagens de halo crescem.

**Interesse científico**: mensagens pequenas (N=64) tendem a cair em protocolo
eager (UCX) e não saturar a rede; mensagens grandes (N=1472) entram em
rendezvous e mudam de regime. Esse é o tipo de efeito de baixo nível que o
SimGrid pode ou não capturar corretamente — é o teste mais direto de "a
janela de comunicação medida bate com a prevista".
**Redundância potencial**: os 12 pontos de N dentro do patamar de 1 nó são
finos (passo de 64), o que é ótimo para uma curva suave mas caro em número de
execuções; **redução de amostragem é uma opção real** de simplificação sem
perda de poder de resposta à pergunta central (ver §5.2).

### 3.3 Eixo C — banda de rede (1/10/25gbit): terceiro eixo, mas CONFUNDIDO por um mecanismo de falha

Diferente dos eixos A e B, este eixo **não é limpo**: em 23 das 105 linhas
(todas multi-nó em 1gbit), o próprio mecanismo que se queria estudar
(sensibilidade do modelo à banda) é **impedido de ser observado** porque o
processo trava antes de produzir dado (Mecanismo A). Isso significa que, com
o código atual, o eixo de banda só pode ser estudado honestamente em:
(a) configurações single-nó (onde o gather nunca cruza a rede shaped — usa
`sm`/`self` intra-nó), ou (b) multi-nó em 10gbit/25gbit apenas.
**Não há, hoje, nenhuma forma de comparar 1gbit vs 10gbit vs 25gbit numa
mesma topologia multi-nó**, porque um dos três pontos da comparação nunca
termina. Isso é uma **ameaça direta à validade** de qualquer conclusão sobre
"sensibilidade à banda" tirada da campanha tal como está desenhada — ver §5.5.

## 4. Casos notáveis

### 4.1 N=1536 / 2 nós / 2x2x2 — a âncora mais bem caracterizada da campanha

Já teve dedicação de duas sessões inteiras (10/07, 14/07). É o **menor caso
multi-nó** de toda a campanha (piso de mensagem ~1,8GB/campo/worker) — por
isso, qualquer coisa que já dê errado aqui (deadlock 1gbit) é garantidamente
pior em todas as 22 outras linhas 1gbit multi-nó, e qualquer coisa que já
funcione aqui (10gbit/25gbit) é o ponto de partida mais barato para estender
a validação para N maior. Dado real: 10gbit completo (7512,76 Msamples/s
agregado, fase computacional 47,49s, ~1h55min parede-a-parede via `/dev/null`,
validando o modelo T_final com erro <1%); 25gbit completo (7728,13 Msamples/s,
46,16s de fase computacional) — **achado desta sessão, não do diário
original**: o teste de 25gbit (t5) que o diário registrou como "só o primeiro
worker confirmado" na verdade **terminou sozinho** com os 8 workers, conferido
agora no `dc.output`. **Ganho científico por custo**: altíssimo — é o ponto
mais barato (~2h de reserva) que já cobre a transição single-nó→multi-nó.
**Custo remanescente**: falta medir a mesma célula com escrita real em NFS
(não `/dev/null`), o que é o próximo passo natural e barato antes de qualquer
célula maior.

### 4.2 2x3x4 (N=2624) vs. 2x2x6 (N=2560/2688) — mesmo nº de nós/GPUs, topologia diferente

Ambas usam 6 nós / 24 GPUs, mas `2x3x4` é a **única topologia de toda a
campanha com três fatores distintos** (2, 3 e 4), gerando partições
heterogêneas nos três eixos simultaneamente, contra `2x2x6` que só quebra um
eixo. **Não é redundante** com `2x2x6`: é um teste de forma de topologia a
recursos fixos — importante porque o padrão de vizinhança Moore 3D (ver §4.3)
faz com que o número de vizinhos ativos por worker dependa da forma da grade,
não só do total de GPUs. Se o SimGrid modela bem o volume mas mal a
*topologia de comunicação*, é aqui que isso apareceria primeiro.

### 4.3 3x3x3 (N=2752/2816) — verificação de uma afirmação herdada, CONFIRMADA

`validation_set_topologies.csv` (sessão anterior) afirma que 3x3x3 é
interessante por ter "máximo de adjacências diagonais (26 vizinhos)". Não
aceitei essa afirmação sem checar — fui ao código: `include/definitions.h:5`
define `NEIGHBOURHOOD 27` e `worker.c:184-190,285-292` itera as 27 direções
(dx,dy,dz ∈ {-1,0,1}³, incluindo a própria célula) para trocar halo,
confirmando que **a aplicação de fato faz troca de halo com vizinhança de
Moore completa (faces + arestas + cantos), não só as 6 faces**. A afirmação
herdada está **[EMP]-CONFIRMADA**, e isso reforça por que 3x3x3 é
especial: é a única topologia do conjunto onde todo worker interior tem
os 26 vizinhos simultaneamente ativos (em topologias como `1x2x2`, o eixo
não dividido faz a maioria das 26 direções ser `MPI_PROC_NULL`). Isso também
implica que o **número de mensagens concorrentes por worker varia muito
entre topologias** mesmo a volume de dado comparável — algo que vale
verificar se o SimGrid modela corretamente (contenção de NIC por número de
fluxos concorrentes, não só por volume total).

### 4.4 Heterogeneidade de hardware: chuc-7 (3 GPUs, não 4)

`diario_de_bordo.md` (16:02:15) já registrou isso como "CONHECIDO". Nenhuma
linha do CSV oficial modela nós heterogêneos — todas assumem
`EXPECTED_GPUS_PER_NODE=4` (`defaults.conf`) uniformemente. Se `chuc-7` for
alocado em qualquer execução de 7+ nós, `validate.sh`/`lib/validate.sh`
(comportamento não conferido nesta sessão) precisa decidir entre abortar a
campanha inteira ou degradar silenciosamente — **isso é uma lacuna
operacional real para os patamares de 7-8 nós**, não hipotética: a config de
7 nós/27 GPUs pressupõe 27=7×~3,86, ou seja, **nem todas as configurações de
7-8 nós são sequer fisicamente possíveis** com 4 GPUs/nó uniformes — description
implícita no próprio CSV de topologias como `3x3x3` (27 GPUs) e `2x3x5` (30
GPUs) já assume alguma heterogeneidade ou nós com menos GPUs ativas.

### 4.5 N=2944 / 8 nós / 32 GPUs — o teto da campanha

Maior configuração: 13,56h de finalização estimada só para 1 rep (67,8h para
5 reps), 204GB de arquivo de saída. **Nunca foi alocado** (máximo empírico de
nós já usado: 3, job 2167768). Mesmo que o deadlock de banda não se aplique
(10gbit/25gbit), a inviabilidade aqui é **inteiramente do Mecanismo B**
(escrita serial), não de rede — ver §5.

## 5. Revisão da campanha à luz do objetivo científico central

> Validar experimentalmente, em hardware real, se os comportamentos previstos
> pelo modelo SimGrid permanecem válidos e se os padrões observados continuam
> existindo quando aumentamos significativamente o tamanho do problema.

### 5.1 Experimentos indispensáveis

1. **Completar N=1536/2nós em 10gbit e 25gbit com escrita real** (não
   `/dev/null`) — barato (~2h), fecha a lacuna do §4.1, e é pré-requisito
   para confiar no modelo T_final antes de extrapolá-lo para N maior.
2. **Ao menos 1 rep completo por patamar de nós (os 8 "âncoras" de
   `validation_set_topologies.csv`)**, banda nativa ou 10gbit — é o mínimo
   para observar se o padrão previsto sobrevive à transição de escala em
   *cada* salto de infraestrutura, não só no primeiro.
3. **A métrica científica (`total_time`/masking effectiveness) para o maior N
   possível dentro do orçamento de reserva disponível**, mesmo sem escrita —
   já demonstrado (§ VERIFICACAO em `benchmark_flag_proposal.md`) que a
   métrica não muda com/sem gather+escrita. Isso é o que realmente responde
   "o padrão continua existindo quando aumentamos o tamanho".

### 5.2 Experimentos opcionais

- A granularidade fina de N dentro de cada patamar (passo de 64 no patamar
  de 1 nó) é valiosa para uma curva de masking suave, mas **não é
  indispensável** para a pergunta central — um subconjunto de 4-5 pontos por
  patamar (extremos + 2-3 intermediários) provavelmente já captura a forma
  da curva com uma fração do custo.
- Todas as 3 bandas para topologias single-nó: cientificamente correto (não
  há deadlock aqui), mas de baixo ganho marginal — o gather single-nó não
  atravessa a rede shaped (`sm`/`self`), então o comportamento entre 1/10/25gbit
  tende a ser quase idêntico nessas linhas por construção.

### 5.3 Experimentos redundantes

- **As 23 linhas 1gbit multi-nó, tal como estão no CSV, são redundantes entre
  si na informação que produzem**: todas testemunham o mesmo Mecanismo A
  (deadlock), já caracterizado uma vez na escala real (N=1536). Rodar as
  outras 22 sem alterar a infraestrutura **não produz dado novo**, só
  confirma repetidamente uma causa raiz já estabelecida — a menos que se
  decida testar se existe uma fronteira de tamanho de mensagem onde o
  deadlock também aparece em 10/25gbit (ainda não descartado além de
  ~1,8GB, ver ressalva em `diario_de_bordo.md` 02:47:15).
- As 3 réplicas de banda nos 12 pontos single-nó (`1x2x2`) — dado que o
  gather não usa a rede shaped nessas linhas — têm alta chance de serem
  estatisticamente indistinguíveis entre si; vale confirmar isso com 1-2
  células antes de assumir e cortar as outras.

### 5.4 Lacunas metodológicas

1. **`ground_truth.dc` não existe.** `validation/validate.sh` referencia
   `validation/ground_truth.dc`, que **não está presente no diretório**
   (`ls` confirma). Pior: `validate.sh` usa uma interface de linha de comando
   antiga (`$CUBE_SIZE_X $CUBE_SIZE_Y $CUBE_SIZE_Z $NUM_ITERATIONS
   $STENCIL_SIZE ./predicted.dc`, argumentos posicionais) **incompatível com
   o `main.c` atual**, que usa `argp` com flags (`--size-x`, `--absorption`,
   etc.). Ou seja: **a validação numérica automatizada está atualmente
   quebrada**, não apenas "indefinida". Isso não estava tão explícito nos
   documentos da sessão anterior (que tratavam `ground_truth` como uma
   "dependência externa a esclarecer") — é, na prática, um script morto que
   precisa ser reescrito antes de qualquer validação numérica real acima de
   512³ (o limite já coberto pela tese).
2. **Path de saída compartilhado em testes ad hoc** (`./validation/predicted.dc`
   reutilizado por múltiplos smoke tests de datas/tamanhos diferentes em
   09/07) — qualquer um desses arquivos pode ter sido sobrescrito por uma
   execução posterior; a proveniência do conteúdo atual de `predicted.dc`
   não é rastreável com confiança. Risco de reprodutibilidade, baixo impacto
   (são só smoke tests), mas vale adotar nomes com timestamp também para
   saída de diagnóstico, como já se faz para os `results/` com timestamp.
3. **Nenhuma medição real de escrita em NFS para N≥1536** (§2) — todas as
   execuções bem-sucedidas em N=1536 usaram `/dev/null`. O modelo T_final é
   validado contra o comportamento **CPU-bound** da escrita (syscall
   overhead), não contra o comportamento **I/O-bound** real em NFS
   compartilhado (~4MB/s observado, mas nunca até completar).
4. **`np` acima de 8 nunca testado** (H4 de `campaign_infrastructure_design.md`,
   ainda [HIP]) — todos os patamares de 3+ nós (np=12 até np=32) dependem de
   `pml_ucx_tls` continuar estável, o que só foi validado empiricamente até
   np=8.
5. **VRAM real (modelo de 6 arrays) nunca medida** (§0) — permanece [DOC],
   não [EMP]. Sem isso, não se sabe com certeza se as 4 topologias "grandes"
   (2x3x4/N2624, 3x3x3/N2752, 2x3x5/N2880, 2x4x4/N2944) realmente cabem em
   VRAM.
6. **Sonda de banda ausente** (SPOF-4 de `campaign_infrastructure_design.md`)
   — nada confirma ativamente que um run "10gbit" está de fato limitado a
   10gbit e não vazando para a banda nativa, o que poderia contaminar
   silenciosamente a comparação de sensibilidade a banda (§3.3).

### 5.5 Ameaças à validade

- **Ameaça de cobertura**: com 96% da campanha não executada, qualquer
  conclusão sobre "o modelo permanece válido em escala" hoje se apoiaria em
  N=1536 apenas — um único degrau de 8 no eixo weak-scaling. Generalizar daí
  para N=2944 seria extrapolação, não validação.
- **Ameaça de confundimento (banda × deadlock)**: como notado em §3.3, o
  eixo de banda está estruturalmente incompleto para todo caso multi-nó — não
  é possível hoje comparar as 3 bandas na mesma topologia grande.
  Qualquer afirmação "o comportamento não muda com a banda" só pode ser feita
  para 10gbit-vs-25gbit, nunca incluindo 1gbit nas configurações multi-nó.
- **Ameaça de instrumentação (`/dev/null`)**: os únicos dados reais em N=1536
  usam `/dev/null`. Se a pergunta científica incluir "o comportamento de I/O
  real também bate com o previsto" (o SimGrid nem modela isso, então
  provavelmente não é parte da pergunta central — mas vale deixar explícito
  na metodologia do artigo/tese que a fase de finalização real em disco fica
  fora do escopo comparado).
- **Ameaça de correção numérica em N grande**: a tese valida numericamente só
  até 512³. A campanha pretende medir desempenho em N até 2944 sem que a
  corretude numérica nessa faixa tenha sido estabelecida — mesmo que o
  desempenho medido seja fidedigno, ele é o desempenho de "uma computação",
  não necessariamente "a computação correta do Fletcher", nessas escalas.
  Isso já era um ponto identificado antes da pausa e continua sem solução:
  o mecanismo para produzir `ground_truth` está quebrado (§5.4.1).

### 5.6 Riscos de interpretação dos resultados

- Tratar as 23 linhas 1gbit multi-nó "inviáveis" como se fossem "o modelo
  falhou em 1gbit" seria um erro de interpretação: o que falha é a
  *implementação do Fletcher* (gather bloqueante da fase de finalização, que
  o próprio SimGrid nunca modela), não o fenômeno físico que o SimGrid tenta
  prever (masking effectiveness durante as iterações). É crucial manter essa
  distinção explícita no artigo/tese para não confundir "limite operacional
  de coleta" com "limite de validade do modelo".
- O ganho de Msamples/s observado entre 1gbit/10gbit/25gbit nos poucos pontos
  medidos (ex.: N=512 np=2: 790→1281→1237 Msamples/s) **não usa a topologia
  oficial da campanha** (np=2/rpn=1 vs. a célula oficial 1n/4g) — não deve
  ser citado como dado da campanha sem re-executar na topologia certa.

### 5.7 Oportunidades de fortalecer a contribuição científica

- A comparação `2x2x6` vs `2x3x4` a recursos fixos (§4.2) é uma oportunidade
  barata (mesmo custo de reserva que qualquer outra célula de 6 nós) de
  testar uma dimensão que o CSV original não enfatiza: forma da topologia,
  não só volume/escala — pode virar uma seção extra no artigo se o SimGrid
  divergir aqui.
- O achado independente desta sessão (§4.1, teste de 25gbit realmente
  completou) mostra que vale reconferir sistematicamente `dc.output` de
  execuções "deixadas rodando em segundo plano" antes de assumir que
  falharam ou ficaram incompletas — pode haver mais dado já coletado e não
  registrado do que o diário sugere.
- Uma vez resolvido `ground_truth` (§5.4.1), a estrutura já aprovada (35 full
  nativos + bench por banda) permite reportar **tanto** desempenho (via bench)
  **quanto** corretude (via full) com o mesmo desenho — sem isso, o artigo só
  pode reivindicar desempenho, deixando a corretude em N grande como ameaça
  à validade não mitigada.

## 6. O que isto muda nas pendências já abertas

Esta consolidação não decide nada sozinha, mas dá contexto quantitativo às
duas pendências que a sessão de 14/07 deixou em aberto:

- **As 3 lacunas de design** (sonda de shaping, re-censo de nós on-failure,
  orçamento de disco/trace) — confirmadas como reais aqui também (§5.4.6,
  e a lacuna de armazenamento de traço em §2 permanece sem modelo).
- **`ground_truth`** — deixa de ser uma "dependência externa a esclarecer" e
  passa a ser um **script quebrado a corrigir** (§5.4.1), o que muda a
  natureza da próxima ação: não é só "decidir o que é a referência", é
  também "consertar o mecanismo que a gera".

Pronto para retomar a discussão dessas pendências — e agora também das novas
lacunas listadas em §5.4-5.6 — uma a uma, como combinado.
