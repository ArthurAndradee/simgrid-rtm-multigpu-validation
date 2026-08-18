# Design da infraestrutura da campanha (PLANEJAMENTO -- nada implementado)

Sessao 2026-07-14. Cada componente segue a regra: PROJETAR -> AUDITAR -> (depois) implementar.
Rotulos: [EMP]=comprovado empiricamente nos testes; [DOC]=suportado por codigo/documentacao; [HIP]=inferido/nao validado.

## 2. Confiabilidade (pre-requisito da automacao)

### 2.1 Watchdog / timeout
Objetivo: matar run travado sem matar Finalization lenta (GPU 0% por horas e LEGITIMO).
Assinaturas:
- [EMP] Deadlock (Causa 1, Teste 2a+backtraces): GPU 0%, rx_bytes CONGELADO, write_bytes 0, log congelado, ranks R com utime CRESCENDO (busy-spin).
- [EMP] Finalization lenta (Causa 2, Testes 1/3b/4): GPU 0% mas write_bytes cresce (~4MB/s) OU contagem 'Received and wrote partition from worker N' incrementa.
DESIGN: utime NAO serve como sinal de vida (spin queima CPU sem progredir).
  Vivo = (GPU>~3%) OU (d rx+tx>0) OU (d write_bytes>0) OU (d contagem log>0).
  Sem nenhum por W>=10min -> travado -> kill+varredura+status=timeout.
Duas camadas: (1) 'timeout <teto>' do coreutils no comando (teto=min(T_est*k, walltime_restante-margem)), sobrevive se o watchdog morrer; (2) watchdog de liveness (frontend, amostra ~2min via ssh) mata cedo.
AUDITORIA:
- [HIP] Ambiguidade escrita-local-do-coordenador (~27min sem rede/log): em full-run-disco write_bytes cresce -> ok; em benchmark nao existe fase de escrita -> ok; caso perigoso (/dev/null+escrita) nao ocorre pois /dev/null so no benchmark que PULA a escrita. Neutralizado, mas a confirmar com o flag.
- [HIP] stall transitorio de NFS: W>=10min tolera; deadlock fica congelado indefinidamente.
- Defesa PRIMARIA e excluir por politica as linhas sabidamente travadas (1gbit multi-no); watchdog e SECUNDARIO p/ hangs imprevistos.

### 2.2 Limpeza de orfaos
[EMP] 2 incidentes no diario + observado nesta sessao: mpirun/prterun/prted/dc orfaos seguram GPUs.
DESIGN: antes de cada run E depois de cada kill, varrer TODOS os nos por dc/mpirun/prterun/prted -> TERM, espera, KILL -> confirmar GPU ociosa. Casar '[.]/bin/dc' (NAO substring 'bin/dc' -- [EMP] casa com sbin/dcgm, erro cometido nesta sessao).
AUDITORIA:
- [HIP] no caido trava a varredura: ConnectTimeout curto + varredura paralela por-no; no inalcancavel -> node_bad, nao bloquear.
- limpar so entre runs (orquestrador sequencial), nunca durante launch.
- [DOC] nos chuc sao exclusivos por no -> nao mata jobs de outros.

### 2.3 Recuperacao apos falha
PRESERVAR: checkpoint.sh atual e append-only e so grava terminais (done/failed) APOS o run -> crash-safe (crash no meio nao deixa linha -> re-tentado).
ADICOES: marcador volatil state/inflight.txt (apagado ao terminar limpo); na partida, se existe -> run interrompido -> varre orfaos, checa integridade do result_dir (integro->done, senao->failed), apaga. Cap de re-tentativas (3) -> failed_permanent (ALERTA, nao pula silencioso). Causas distintas: timeout/failed/oom/skipped_vram/skipped_deadlock; oom=deterministico->nao re-tentar mesma config.
AUDITORIA:
- [EMP] traco parcial nao engana: Akypuera so despeja no Finalize; run morto no meio nao tem dc.csv/dc.trace -> integridade falha -> re-tentado.
- [DOC-lacuna] para FULL run, integridade deve exigir TAMBEM .dc do tamanho esperado (checkpoint_integrity_ok atual nao checa .dc).
- cap de retry pode esconder falha real -> failed_permanent deve alertar; cap conta falhas do MESMO tipo.

## 3. Flag --skip-output (habilita modo benchmark)

PULA so 2 chamadas (ambas POS-janela-medida e POS-ultimo-halo): main.c:187 dc_send_data_to_coordinator (gather, Causa 1) e main.c:188-193 dc_receive_and_write_results (escrita O(N^3), Causa 2). INTOCADO: dc_worker_process (iteracoes+halos+msamples_per_s), MPI_Wtime, MPI_Barrier, kernels/precomp/boundary. Janela medida BYTE-IDENTICA.

OPCAO A (recomendada) -- flag runtime --skip-output:
  coordinator.h: +int skip_output (zero-init pelo {0}). main.c: +opcao argp 'b', +case parse_opt, relaxar ARGP_KEY_END (output_file==NULL so se skip_output), envolver main.c:187-193 em if(!skip_output){...}. TODAS as 5 reps usam o MESMO binario; default(off)=comportamento atual.
OPCAO B -- compile-time -DSKIP_OUTPUT (espelha #ifdef SIMGRID): gera bin/dc-bench; bin/dc byte-identico. 2 binarios.
Recomendacao: A (revisor prefere mesmo binario p/ os 5 reps, flag so atua fora da janela).

AUDITORIA (invariancia da metrica RECONFIRMADA):
- [DOC] total_time fecha em main.c:185 antes do gather(187) -> inalterado.
- [DOC] janela masking [1o Irecv, ultimo Waitall]; gather usa Send/Recv pos-Waitall -> fora; compare_sim_real.R:288-293 recorta por janela E filtra Operation in {Irecv,Isend,Waitall} -> gather excluido DUPLAMENTE.
- [DOC] dc_worker_free (worker.c:562-570) independe do gather; free(NULL) seguro.
CASOS DE BORDA:
1. [DOC] Consistencia entre ranks: flag guarda AMBAS as funcoes; mpirun passa argv uniforme -> seguro. Invariante: run.sh aplica flag ao mpirun inteiro, nunca por-rank.
2. [HIP] NAO resolve VRAM: OOM ocorre antes do gather -> benchmark tambem daria OOM (isso e o passo 4).
3. [HIP->EMP] Traco Akypuera em benchmark: erro aky_converter 'no send for this receive' apareceu COM gather; pular PODE limpar -- SMOKE TEST obrigatorio (traco valido + metrica identica a full da mesma celula).
4. [DOC] build SIMGRID: flag redundante mas inocuo; verificar que compila.
5. [DOC] 5 reps (1 full+4 bench) poolaveis (janela identica; processos frescos); orquestrador precisa consciencia de walltime (full=horas, bench=min).
6. [DOC] deteccao de sucesso difere por run_type: bench=trace sem .dc; full=trace+.dc tamanho esperado -> checkpoint_integrity_ok estendido precisa do run_type.
SMOKE TESTS que fecham o que o papel nao fecha: metrica bench==full (ex 2x2x2/N1536/10gbit); erro aky some ou nao; compila em cuda E simgrid.
VEREDITO: solido e minimamente invasivo; invariancia da metrica comprovada por codigo+R; riscos remanescentes operacionais/empiricos, cobertos por smoke tests. Nenhum impeditivo.

## 4. VRAM: as 4 topologias "limitadas" nao sao inviaveis (estimativa do CSV conservadora demais)

Rotulos: [EMP]=comprovado empiricamente; [DOC]=suportado por codigo; [HIP]=inferido/nao validado.

ACHADO: o backend CUDA aloca EXATAMENTE 6 arrays de device (pp,pc,qp,qc,vpz,vsv),
nao os ~11 que a coluna VRAM_GB_por_GPU do CSV assume.
- [DOC] src/device_data.cu: 6 cudaMalloc (linhas 57,59,61,63,81,83), cada um de
  total_size_bytes = local_count*4. Comentario device_data.cu:79 explicito:
  "Allocate only vpz and vsv (2 arrays instead of 10 precomp arrays)".
  (O grep mostrando "12" = 6 cudaMalloc + 6 strings de erro "cudaMalloc xxx".)
- [DOC] src/cuda_propagate.cu: 0 cudaMalloc. Nenhuma outra alocacao de device
  em src/*.cu. Halo usa cudaMemcpy/kernels sobre os arrays existentes.
- [DOC] Sem RDMA GPU (OpenMPI --without-cuda, UCX_TLS=tcp) -> UCX nao aloca no device.

CONSEQUENCIA: VRAM real CUDA = 6*local_count*4 B + contexto (~0.5 GB).
A coluna do CSV supoe ~11 arrays -> superestima ~1.86x para CUDA.
Reprojetando as 4 "infactiveis":
  2x3x4 N2624: CSV 34.49 -> real ~18.5 GB
  3x3x3 N2752: CSV 35.50 -> real ~19.0 GB
  2x3x5 N2880: CSV 36.49 -> real ~19.6 GB
  2x4x4 N2944: CSV 36.52 -> real ~19.6 GB
Maximo do CSV em toda a campanha = 37.97 (N2816) -> real ~20.4 GB << 40 GB.
=> TODAS as 105 linhas cabem em VRAM no CUDA. As linhas antes puladas por
   csv_vram_ok (N1472=36.03, N1856=36.19, etc.) sao FALSOS NEGATIVOS.

AUTOAUDITORIA (tentativas de refutacao, todas negativas): memoria UCX/MPI no
device? nao. Workspace/temp de kernel? cuda_propagate.cu tem 0 cudaMalloc.
Staging de halo? usa arrays existentes. Fragmentacao/contexto? ~0.5 GB.

STATUS: [DOC]-solido, [EMP]-PENDENTE. Nao medimos memory.used em nenhum run
(nem N1536). Job 2167768 expirou antes da medicao.
SMOKE TEST decisivo (proxima reserva): amostrar nvidia-smi
--query-gpu=memory.used DURANTE as iteracoes de N1536 -> esperado ~11 GB
(modelo de 6 arrays), NAO ~20.57 (CSV). Converte [DOC]->[EMP].

IMPLICACAO ACIONAVEL: csv_vram_ok esta mal-calibrado para CUDA e pularia
linhas factiveis. NAO remover o gate cegamente antes do [EMP]; ate la,
tratar como hipotese forte. Opcoes de correcao (pos-smoke): (a) recomputar
a coluna VRAM com modelo de 6 arrays; (b) relaxar/desligar o gate no CUDA;
(c) medir e recalibrar orcamento.

NOTA LATERAL (RAM de host, nao VRAM): o host ainda aloca ~20 arrays/rank
(4 campos + anisotropia + 10 precomp). Maior local (~8.2e8 elem) -> ~65 GB/rank
x 4 ranks ~= 260 GB/no < 512 GB [DOC:usuario] -> folgado, mas a monitorar.

## 5. Extensao do orquestrador (scripts/02-orchestrator.sh) -- DESIGN, nada implementado

Estado atual (lido do codigo 2026-07-14): banda -> linha -> 5 reps, cada rep
run FULL (escreve .dc), integrity check, checkpoint done/failed. SEM: hibrido
full/bench, consciencia de walltime, timeout, limpeza de orfaos, marcador
inflight, distincao de run_type, retencao de .dc, lock.

### 5.0 DECISAO ESTRUTURAL (requer aval do usuario) -- full nativo por topologia

DESCOBERTA [DOC-reforcado]: o resultado numerico .dc e RIGOROSAMENTE
independente da banda de rede.
- [DOC] Unica coletiva MPI em todo o codigo: MPI_Allgather em setup.c:33, e
  transfere HOSTNAMES (char), nao ponto-flutuante, e ocorre no setup, fora do
  laco. O caminho de calculo (worker.c:451-516 dc_worker_process) usa SO
  Isend/Irecv/Waitall ponto-a-ponto -> NENHUMA reducao FP dependente de
  ordem/tempo existe. Halo entrega os mesmos bytes qualquer que seja a banda.
- [EMP] determinismo ja observado (seed=0, reps numericamente identicos).
=> .dc(nativo) == .dc(1gbit) == .dc(25gbit), bit-a-bit.

INTERACAO COM O DEADLOCK: --skip-output (bench) PULA o gather -> bench NUNCA
trava, em nenhuma banda. E o full so precisa da banda para nada (o .dc nao
depende dela; o trace do full e contaminado pelo gather e nao e a fonte da
metrica de masking -- essa vem dos traces bench). Logo:
  - metrica masking (trace): vem dos reps BENCH, por (topologia x banda).
  - correcao numerica (.dc): 1 full por TOPOLOGIA, em banda NATIVA (rapida,
    sem gather-sobre-link-lento -> deadlock DESENHADO PARA FORA, nao so evitado).

Isso muda a estrutura "1 full + 4 bench por celula" (aprovada em
validation_set_topologies.csv). Duas opcoes:
  CONSERVADORA: 1 full (shaped) + 4 bench por (topo x banda) = 105 full + 420
    bench. Os full em 1gbit multi-no DEADLOCAM (Causa 1) -> exigem exclusao por
    politica ou rodar esses full em nativo como excecao. Gera 105 .dc gigantes.
  REFINADA (recomendada): 35 full NATIVOS (1/topologia) + N bench por
    (topo x banda). Remove o deadlock por construcao, elimina 70 full
    redundantes e 70 .dc gigantes, e mantem o mesmo conteudo cientifico
    (numerico coberto 1x/topologia por independencia-de-banda; timing coberto
    por banda pelos bench).

REFUTACOES tentadas contra a REFINADA (todas negativas): (1) ordem de mensagens
muda alguma reducao? nao ha reducao FP. (2) nao-determinismo de kernel CUDA?
determinismo ja [EMP]; kernel nao ve a rede. (3) --skip-output altera o .dc?
bench nao produz .dc; so o full produz. Risco remanescente = [HIP] ate o smoke
test: checksum .dc(nativo) vs .dc(shaped ja existente, ex N1536 29GB em
validation/) -> tem de ser identico. RECOMENDO REFINADA condicionada a esse
smoke test + aval do usuario (muda a estrutura aprovada).

### 5.1 Retencao de .dc + preflight de disco (constraint novo [EMP])

[EMP] .dc de N1536 = 28.99 GB (validation/predicted_..._N1536.dc). N~2944
seria ~204 GB. /home e NFS COMPARTILHADO: 14T, 84% usado, 2.3T livres; /tmp
local so 16G. Escrever 204GB em NFS e lento (e a propria Causa 2) e antissocial.
DESIGN full run: --output-file -> roda -> CompareResults.R contra referencia ->
grava veredito+checksum -> APAGA o .dc imediatamente (retencao = validar-e-
descartar, pico = 1 .dc por vez). Preflight: antes de cada full, exigir
disco_livre >= tamanho_do_.dc + margem; se nao, DEFER (aviso alto), nunca
iniciar escrita que dara ENOSPC no meio (pareceria hang).
DEPENDENCIA ABERTA (nao resolver aqui): qual e a referencia (ground_truth) por
topologia que CompareResults.R usa? Sem ela, a "validacao numerica" vira so
checagem de reprodutibilidade (trivial sob determinismo). A esclarecer com o
usuario antes de rodar full.

### 5.2 Distincao de run_type + schema do checkpoint (migracao)

[DOC] progress.csv atual tem 6 linhas (schema 5 colunas: id,rep,status,ts,dir),
status in {done,failed}. A integridade difere por tipo: FULL exige .dc do
tamanho esperado (checkpoint_integrity_ok atual NAO checa .dc); BENCH exige
trace valido e NENHUM .dc.
DESIGN: adicionar 6a coluna run_type in {full,bench}. Linhas legadas (5 col)
leem run_type vazio -> tratado como full (== comportamento real delas).
checkpoint_last_status/should_run usam posicoes 1-3 -> intactos.
checkpoint_integrity_ok ganha argumento run_type: full -> tudo o de hoje MAIS
[ -s .dc ] e tamanho == esperado; bench -> trace/csv/rastros validos E ausencia
de .dc. Uma unica funcao de politica run_type_for_rep() concentra o mapeamento
rep->tipo (evita acoplar a politica na logica de integridade).

### 5.3 Estados, retentativas e o que NAO persistir

PRESERVAR: append-only, so grava terminais APOS o run (crash-safe).
Novos estados de RESULTADO (persistidos): done, failed, timeout, oom,
failed_permanent. 
NAO persistir como estado pegajoso: skipped_vram, skipped_deadlock, deferred
(walltime). Motivo [auditoria]: sao decisoes de POLITICA recomputadas a cada
execucao a partir das condicoes atuais. Persistir skipped_vram CONGELARIA uma
decisao que o passo 4 acabou de mostrar errada; deferred deve ser reavaliado na
proxima reserva (mais walltime). Vao para diario + contadores, nao para
should_run. => should_run continua simples (so trata "done").
Retentativas: cap=3 por (id,rep) contando falhas do MESMO tipo; ao estourar ->
failed_permanent com ALERTA (diario + exit != 0), nunca pulo silencioso.
oom = deterministico -> cap=1 (nao re-tentar a mesma config). NB: passo 4 diz
que oom nao deveria ocorrer; se ocorrer, e sinal real (modelo errado) -> alto.

### 5.4 Marcador inflight + limpeza de orfaos (resume)

Antes do laco: se existe state/inflight.txt -> orquestrador anterior morreu no
meio. Ler (id,rep,run_type,result_dir); varrer orfaos em TODOS os nos; checar
integridade do result_dir (integro->done, senao->failed conforme run_type);
apagar inflight.txt.
Antes de CADA run: gravar inflight.txt; depois de terminar (qualquer desfecho):
apagar.
Varredura de orfaos antes de CADA run e depois de cada kill: em todos os nos,
casar '[.]/bin/dc' (NAO substring 'bin/dc' -- [EMP] casa sbin/dcgm) + mpirun,
prterun, prted -> TERM, espera, KILL -> confirmar GPU ociosa (nvidia-smi).
[HIP] no caido trava a varredura -> ConnectTimeout curto + por-no paralelo;
no inalcancavel -> node_bad, nao bloquear. So entre runs, nunca durante launch.
[DOC] nos chuc exclusivos por no -> varredura nao mata jobs de terceiros.

### 5.5 Consciencia de walltime + timeout (2 camadas)

Fonte de walltime: /usr/bin/oarstat -j <jobid> -f (start_time + walltime) ->
restante = start + walltime - now. [DOC] oarstat existe; parsing exato = smoke
test. (jobid via arg/estado; frontend sem env OAR fora de job.)
T_est por run: bench -> T_iter_est; full -> T_iter_est + T_final_est (modelo
tau=0.959us/par de finalization_feasibility_map.md). T_iter_est: [EMP] so para
N1536/np8; para os demais, escalar pelo volume-local do ancoradouro medido mais
proximo, com fator k conservador (superestimar). Smoke tests da 1a reserva
medem T_iter dos tamanhos-chave -> refina.
GATE (antes de iniciar rep): se walltime_restante < T_est + margem -> NAO iniciar
-> deferred (nao failed) -> proxima reserva pega. Nao comecar run que nao termina.
Camada 1 (em run.sh): envolver o mpirun em 'timeout <teto>' do coreutils,
teto = min(T_est*k, walltime_restante-margem). timeout dispara -> rc=124 ->
varredura de orfaos -> status=timeout. Sobrevive se o watchdog externo morrer.
Camada 2 (liveness, FASE 2, opcional no v1): sampler no frontend a cada ~2min;
vivo = (GPU>~3%) OU d(rx+tx)>0 OU d(write_bytes)>0 OU d(contagem-log)>0; morto
por >=10min -> kill. Com deadlock desenhado para fora (5.0) + camada 1, a
camada 2 e cinto-e-suspensorio; projeta-se agora, implementa-se depois.

### 5.6 Fases + lock (mecanica do laco)

Flag --phase full|bench|all (default all): 'full' = shape_off, RUN_NATIVE=1,
--skip-output OFF, 1 rep/topologia (fase numerica nativa); 'bench' = por banda
shape_apply, RUN_NATIVE=0, --skip-output ON, N reps/(topo x banda). Isto
transforma a escolha "largura-primeiro (cobertura numerica) vs
profundidade-primeiro" em opcao do operador SEM um escalonador complexo: cada
passada = uma fase. O guard de run.sh (recusa --native com shaping ativo) ja
protege a fase full. 'all' preserva a passada unica atual.
LOCK: state/orchestrator.lock com PID; recusar iniciar se um orquestrador vivo
o detem (evita dupla-execucao -> contencao de GPU).

### 5.7 Autoauditoria do design do orquestrador (tentativas de refutacao)

- SPOF: o proprio orquestrador no frontend. ssh cai -> morre no meio. Mitigacao:
  rodar sob tmux/nohup; inflight.txt + resume recupera; run orfao no head e
  limpo pela varredura na proxima partida (resultado perdido -> failed -> re-run).
- Walltime depende de oarstat correto; se falhar a leitura, FALHAR FECHADO
  (assumir pouco tempo -> so bench curtos) em vez de arriscar run que nao termina.
- Relogio: usar sempre date +%s do frontend (consistencia).
- Migracao de schema: 6a coluna, legado->full, posicoes 1-3 intactas -> compat.
- Retry cap escondendo falha real: failed_permanent ALERTA; cap conta por tipo.
- deferred/skipped nao pegajosos -> nunca congelam decisao superada (ex: passo 4).
- Concorrencia: lock por PID.
- [HIP] independencia-de-banda do .dc (5.0): forte por codigo, mas so vira [EMP]
  com o checksum nativo-vs-shaped -> smoke test obrigatorio antes de confiar.
- DEPENDENCIA ABERTA: ground_truth por topologia (5.1) -- externa ao orquestrador.

VEREDITO: mecanica de resiliencia solida e minimamente invasiva sobre a base
atual (checkpoint append-only preservado; libs run.sh/csv.sh reaproveitadas).
Duas coisas exigem aval/decisao do usuario ANTES de implementar: (a) adotar ou
nao a estrutura REFINADA (full nativo por topologia, 5.0); (b) definir a
referencia ground_truth por topologia (5.1). O resto e implementavel apos aval,
com smoke tests fechando os [HIP] na 1a reserva.

## 5.8 DECISAO REGISTRADA: estrutura REFINADA (usuario, 2026-07-14)

Adotada a REFINADA: 35 full NATIVOS (1/topologia, numerico) + bench por
(topo x banda, timing, --skip-output). Condicionada ao smoke test de checksum
.dc(nativo)==.dc(shaped) que converte a independencia-de-banda de [DOC] p/ [EMP].
CONSERVADORA descartada.

## 6. Auditoria sistemica do sistema completo (pre-implementacao)

Escopo: falhas EMERGENTES entre componentes, SPOFs em escopo-campanha,
hipoteses load-bearing por blast radius, cenarios operacionais. Complementa (nao
repete) os audits por-componente das secoes 2-5.

### 6.1 Pontos unicos de falha (campanha)
- [SPOF-1] experimentos.csv como fonte unica "nunca recomputada": um valor
  errado propaga silencioso. JA MATERIALIZADO: a coluna VRAM esta ~1.86x errada
  p/ CUDA (passo 4). csv_selfcheck so valida a formula de tamanho de UMA linha
  (N64), nao topo/N/VRAM. ACAO: recalibrar/desligar csv_vram_ok no CUDA;
  adicionar cross-check VRAM (modelo 6-arrays) ao selfcheck.
- [SPOF-2] progress.csv (ledger unico). Perda -> re-roda tudo (idempotente sob
  determinismo -> seguro, so custa horas). Fica em NFS (sobrevive a morte de no).
  ACAO: backup por reserva.
- [SPOF-3] orquestrador no frontend (ver 5.7): tmux + inflight resume.
- [SPOF-4] SHAPING que vaza (INSIDIOSO): um run "10gbit" que na verdade roda em
  velocidade nativa parece OK e POLUI a metrica de masking sem erro visivel.
  Nao ha medicao ativa de que a banda efetiva ~ alvo (so se o qdisc tc existe).
  ACAO (lacuna real): sonda de banda barata por-banda (transferencia cronometrada
  ou iperf) ANTES de cada batch, logada; abortar se desviar do alvo.

### 6.2 Hipoteses load-bearing (por blast radius)
- [H1 ALTO] independencia-de-banda do .dc (5.0). Blast: TODA a REFINADA. Barato
  de testar. Smoke test #1 obrigatorio ANTES de confiar.
- [H2 CONCEITUAL-ALTO] existencia de ground_truth por topologia (5.1). Blast: se
  nao existe referencia real, a fase full vira so reprodutibilidade (trivial sob
  determinismo) -> questiona a fase full inteira. DEPENDE do usuario, nao de
  smoke test.
- [H3 MEDIO] modelo VRAM 6-arrays (passo 4). Blast: quais linhas rodam +
  csv_vram_ok. Falha e DETERMINISTICA (OOM) e auto-revelavel; cap=1 + alerta.
  Smoke test #2 (memory.used).
- [H4 MEDIO] pml_ucx_tls estavel acima de np=8. [EMP] so ate 2n/8g. Blast: runs
  shaped falhando ao iniciar em np alto (ate 16). Smoke test #4 (max np cedo).
- [H5 BAIXO se conservador] extrapolacao de T_iter p/ tamanhos nao medidos. Blast:
  precisao do gate de walltime. Subestimar -> overrun -> timeout -> re-roda. O
  design ja manda SUPERESTIMAR (falha-seguro).
- [H6 REDUZIDO pela REFINADA] watchdog distinguir finalizacao-lenta de deadlock:
  REFINADA remove o deadlock -> so importa p/ hangs imprevistos -> camada 2 vira
  fase 2 com tranquilidade.

### 6.3 Cenarios operacionais nao considerados antes
- [O1] MORTE DE NO durante a campanha (3/8 up; hardware instavel). AVAIL e
  calculado SO na partida. Se um no cai no meio, linhas de N-nos maior deveriam
  passar a DEFER e hostfiles serem reconstruidos. LACUNA: re-censo entre
  experimentos (ou on-failure) e ajuste de AVAIL. ACAO: re-census + rebuild.
- [O2] RESERVA menor que 1 full do maior N (~204GB write + finalizacao). Gate
  faz defer; mas se NENHUMA reserva for longa o bastante, as maiores topologias
  nunca ganham full. ACAO: recomendar walltime >= max T_est_full (feasibility
  map da o numero) OU aceitar as maiores como bench-only e declarar na
  metodologia.
- [O3] DISCO enche no meio. Full: preflight + validar-e-descartar (pico 1 .dc).
  MAS os traces bench (rastro/dc.csv/dc.trace) sao o PRODUTO cientifico e
  ACUMULAM por centenas de reps. LACUNA: orcamento de disco dos TRACES na
  campanha inteira nao estimado. ACAO: estimar tamanho de trace x N x reps;
  comprimir/arquivar; preflight tambem p/ traces.
- [O4] BUFFER Akypuera (RST_BUFFER_SIZE=1GB) x runs longos/grandes: se o volume
  de trace de um run exceder 1GB, pode haver flush no meio/perda -> metrica de
  masking truncada sem erro obvio. LACUNA: volume de trace dos maiores configs
  nao estimado vs 1GB. ACAO: estimar; aumentar buffer ou validar contagem de
  eventos por rank pos-run.
- [O5] TRANSICAO DE FASE bench(shaped)->full(nativo) sem shape_off: o guard de
  run.sh aborta (correto), mas ruidoso. ACAO: toda transicao de fase faz
  shape_off explicito primeiro.
- [O6] Dupla execucao de frontends distintos: lock por PID deve gravar host+PID
  e checar liveness host-aware (NFS compartilhado).

### 6.4 Plano de smoke tests da 1a reserva (cai da auditoria; piggyback p/ caber curto)
Ordem por blast radius / dependencia:
  #1 [gate REFINADA]  checksum .dc(nativo N1536) vs .dc(shaped N1536 ja existe) -> identico.
  #2 [gate VRAM]      nvidia-smi memory.used durante iteracoes N1536 -> ~11GB (nao ~20.6).  (piggyback no #1)
  #3 [gate skip-output] masking(bench) == masking(full) em 1 celula (2x2x2/N1536/10gbit) E erro aky some.
  #4 [gate np alto]   pml_ucx_tls em np=16 (4n x 4g) inicia e completa.
  #5 [gate timing]    sonda de banda: banda efetiva ~ alvo em 1gbit/10gbit/25gbit.
  #6 [gate walltime]  parsing de oarstat -j <jobid> -f -> restante correto.
Tudo cabe em uma reserva pequena: #1+#2 num run N1536; #3 num run bench; #4 num
run max-np; #5/#6 baratos. Objetivo: converter H1-H4 de [DOC/HIP] p/ [EMP] ANTES
de gastar reserva grande com a campanha.

### 6.5 Veredito sistemico
A base (checkpoint append-only, run.sh/csv.sh/shape.sh validados) e solida e a
REFINADA remove o maior risco operacional (deadlock) por construcao. Restam:
- 3 LACUNAS de design a fechar antes de implementar: sonda de shaping (SPOF-4),
  re-censo de nos on-failure (O1), orcamento de disco/trace + buffer Akypuera
  (O3/O4). Nenhuma e impeditiva; todas sao adicoes localizadas.
- 1 DEPENDENCIA externa (ground_truth, H2) que o usuario precisa esclarecer.
- H1-H4 fecham nos smoke tests #1-#4 da 1a reserva.
Recomendacao: incorporar as 3 lacunas ao design, obter o ground_truth, e so
entao implementar (com os smoke tests como primeiro uso da reserva).

## 5.1-bis. Investigacao do ground_truth (reconstrucao por evidencia, nao por memoria)

Motivada pela dependencia aberta da secao 5.1. Metodo: git log/show em todo o
historico (nao so o HEAD), leitura de thesis/index.tex e thesis/references.bib.
Nada implementado; achados abaixo, todos com commit/linha citavel.

### Linha do tempo reconstruida [DOC] (datas/hashes exatos)

1. e5a52bb "Initial commit" (2026-06-29 no fork local; historia do upstream
   comeca antes) + README.md: o repo NASCEU como "Distributed cube average"
   -- "a simple average of a distributed cube... as a proof of concept for
   distributed computing". SEM relacao com RTM/Fletcher.
2. 19b6ff6 "Improved compare script" (ultimo toque em validation/validate.sh):
   validate.sh + CompareResults.R sao DESSA fase. validate.sh chama
   ../bin/distributed-cube-average (CLI POSICIONAL: CUBE_SIZE_X/Y/Z,
   NUM_ITERATIONS, STENCIL_SIZE, output) -- INCOMPATIVEL com a CLI argp atual
   do Fletcher (--size-x=, --absorption=, --dx=, etc.). ground_truth.dc ali =
   mpirun -np 1 do MESMO binario simples de cube-average.
   72717f9 "Add and communicate pp, pc, qp, qc arrays" (campos do Fletcher)
   veio DEPOIS -- confirma que validate.sh/CompareResults.R sao pre-Fletcher,
   nunca adaptados, e NAO RODAM no ./bin/dc atual (CLI incompativel).
3. ec89290 "Fix: Restore truncated run-dc-comparison script" (2026-01-13):
   nix/scripts.nix ganha run-dc-comparison, a UNICA validacao numerica
   automatizada do FLETCHER (nao do toy) jamais commitada:
   - ground_truth.dc = mpirun -np 1, backend OpenMP (dc-omp-mpip), tamanho
     UNICO --size-x/y/z=52 absorption=2 (-> N global=64, o MESMO valor
     hardcoded em g5k/lib/csv.sh:csv_selfcheck)
   - openmp_predicted.dc = mpirun -np 6, mesmo backend/tamanho ->
     CompareResults.R 0 (tolerancia ZERO, match exato exigido)
   - predicted.dc (CUDA) = mpirun -np 1, backend CUDA (dc-cuda-mpip), MESMO
     tamanho -> CompareResults.R 1e-3 (tolerancia 1e-3)
   Isto e um teste de AUTOCONSISTENCIA (np=1 vs np=N do MESMO codigo-fonte,
   MESMO kernel/stencil) -- valida decomposicao+halo, NAO valida a fisica
   contra uma implementacao independente (um bug presente no kernel
   compartilhado por np=1 e np=N nao seria pego).
4. e5f0152 "Included C++ Simgrid platform" (2026-02-11, ~1 mes depois):
   run-dc-comparison e REMOVIDO (substituido pelo trabalho de plataforma
   SimGrid C++), SEM SUCESSOR jamais commitado. Confirmado por pickaxe
   (git log -S) em toda a historia: nenhum commit depois deste reintroduz
   validacao numerica automatizada.
5. 70d8d4b "Included Fletcher base derivation" (2026-03-12, ~1 mes depois):
   fletcher-base.nix adicionado -- empacota via Nix um repositorio EXTERNO
   INDEPENDENTE: github.com/gabrielfrtg/fletcher-base, commit fixo
   55ea0803f5d2afe58be8e6cff8bd9108cae30b43, single-process/single-GPU CUDA
   (env.sh + make all backend=CUDA -> ModelagemFletcher.exe). Este SIM bate
   com a "reference implementation" descrita qualitativamente na tese
   (thesis/index.tex:962-996): blocos de thread 32x16 fixos (vs 16x16 deste
   projeto), variaveis de device globais/estaticas (vs por-processo aqui),
   10 vetores de coeficientes de anisotropia explicitos (vs constantes de
   compilacao aqui) -- tracos de um CODIGO REALMENTE DIFERENTE, nao apenas
   "np=1 deste projeto". PORÉM: fletcher-base.nix nunca foi importado por
   flake.nix nem referenciado por NENHUM script, em NENHUM commit, jamais
   (confirmado por grep no HEAD e git log -S"ModelagemFletcher"/-S"fletcher-cuda"
   em toda a historia -- so aparece no commit que o introduziu). Nunca foi
   construido neste ambiente (nada em /nix/store).
6. fc7e2a6 "More thesis, baby, lesgoooo" (2026-05-08, ~2 meses depois de (5)
   e ~3 meses depois de (4)): thesis/index.tex ganha a secao "Numerical
   validation" (linhas 998-1042) descrevendo:
   - comparacao por CHECKSUM SHA-256 (nao o diff-com-tolerancia que
     CompareResults.R realmente implementa)
   - OpenMP: tabela com workers={1..6} x tamanhos={32,64,128,256,512}^3 x
     10 iteracoes = 30 cenarios, TODOS com checksum identico
   - CUDA: tolerancia $10^{-15}$ (NAO os 1e-3 hardcoded no script deletado)
   - texto liga isso a "the reference implementation"/"base program"
     (linhas 994-996), na secao imediatamente anterior que descreve os
     tracos de codigo do fletcher-base EXTERNO (item 5).
7. 4bd74bb "swr-weak-scalability-new" (2026-05-20): ultimo commit do repo.

### Auditoria da linha do tempo (tentativa de reconciliar, nao apenas listar)

[DOC-conflito, nao resolvido por evidencia] Ha DUAS narrativas mutuamente
inconsistentes sobre "como a validacao numerica foi feita", e nenhuma
evidencia no repositorio resolve qual efetivamente gerou os numeros da tese:
  (a) O UNICO script de comparacao numerica jamais commitado (item 3): so
      testa autoconsistencia do PROPRIO codigo (np1 OpenMP como referencia),
      SO no tamanho N=64, tolerancias 0/1e-3, SEM SHA-256, SEM fletcher-base.
  (b) O texto da tese (item 6), escrito ~3 meses DEPOIS do script em (a) ter
      sido deletado (item 4) e ~2 meses depois do fletcher-base ter sido
      adicionado (item 5): descreve SHA-256, tamanhos ate 512^3, 30 cenarios,
      tolerancia 1e-15, e alinha isso com o fletcher-base EXTERNO.
  `sha256sum` NAO aparece em NENHUM commit de toda a historia (git log -S
  vazio). fletcher-base/ModelagemFletcher NAO e invocado em NENHUM script
  em NENHUM commit alem do que o introduziu. Este e um clone read-only
  (github.com/Dannful/distributed-cube-average, branch unica, sem tags;
  reflog so mostra o clone) -- nao ha historico local adicional a recuperar
  aqui.
  INFERENCIA (marcada como tal, NAO fato): o mais provavel e que a validacao
  mais ampla (SHA-256, ate 512^3, contra o fletcher-base) foi executada
  manualmente/interativamente pelo autor original em algum momento entre
  03/2026 e 05/2026, e o script formal NUNCA foi commitado -- so o artefato
  (fletcher-base.nix) e o relato em prosa (a tese) sobrevivem. Isto e [HIP],
  nao [DOC]: nao ha prova de que essa execucao mais ampla de fato ocorreu
  como descrita, nem de que os numeros/tolerancias citados na tese (SHA-256,
  1e-15) sejam precisos vs. aproximados/reconstruidos de memoria.

### Fatos duros, independente de qual narrativa se acredita

- [DOC] Em NENHUMA das duas narrativas o tamanho validado passa de 512^3.
  A MENOR topologia da campanha atual e N=1536 (global). Ou seja: NENHUMA
  validacao numerica historica (documentada ou commitada) jamais tocou
  a escala da campanha atual -- e uma extrapolacao de 3+ ordens de grandeza
  em volume (512^3 = 1.3e8 elementos; 1536^3 = 3.6e9; a maior, 2944^3 = 2.6e10).
- [DOC-calculado] Ground truth via np=1 SINGLE-PROCESS (seja fletcher-base,
  seja o proprio dc) EM QUALQUER BACKEND CUDA e IMPOSSIVEL em qualquer
  topologia da campanha atual: precisa reter o dominio GLOBAL inteiro (np=1
  -> local=global), 6 arrays x 4B (modelo do passo 4) => N=1536 already
  precisa de 87GB > 40GB de uma A100. Todas as 6 topologias-amostra
  calculadas (1536..2944) excedem 40GB (87 a 612 GB).
- [DOC-calculado] Ground truth via np=1 OpenMP (host RAM, ~20 arrays x 4B):
  N=1536 caberia (~290GB de 512GB, com margem apertada, e SO SE nada mais
  rodar no no); TODAS as topologias maiores (N>=1856) excedem 512GB.
- CONSEQUENCIA DIRETA para o design da secao 5 (fase full/REFINADA): mesmo
  que fosse decidido usar np=1 (proprio codigo OU fletcher-base) como ground
  truth, isso e VIAVEL NO MAXIMO para N~1536, e SO em CPU/OpenMP -- nao em
  CUDA, e nao para nenhuma topologia maior. A fase "full numerico" da
  REFINADA precisa ser redefinida: ela NAO PODE ser "validacao contra ground
  truth independente" para a maioria das 35 topologias: so pode, na melhor
  das hipoteses, cobrir 1 (a menor) com ground truth externo/np=1, e as
  demais 34 ficam **sem ground truth possivel em escala** -- restando
  reprodutibilidade determinista (auto-consistencia entre reps, ja
  estabelecida) como unica evidencia numerica disponivel para elas.

### Implicacoes praticas (3 caminhos, nao mutuamente exclusivos, DECISAO do usuario)

CAMINHO A -- ressuscitar autoconsistencia (item 3), adaptada: hoje
dc-omp-mpip/dc-cuda-mpip NAO EXISTEM MAIS (mpiP foi removido do projeto,
commit "14aed58 Removed mpiP from the project"); usar dc-omp-aky/dc-cuda-aky
atuais ou o bin/dc do g5k. Testa SO decomposicao/halo (mesmo kernel em ambos
os lados) -- nao pega bug de fisica presente nos dois. Viavel so ate N~1123
(CUDA) ou N~1759 (OpenMP/CPU) por VRAM/RAM -- ou seja, PEQUENO em relacao
as 35 topologias da campanha (menor delas ja e N=1536).
CAMINHO B -- buscar fletcher-base (item 5) e comparar contra ele: validacao
mais forte (codigo independente, pegaria bug de fisica) MAS: (i) precisa
confirmar que o repo/commit ainda existe no GitHub (nao verificado nesta
sessao); (ii) precisa adaptar parametros (dx/dy/dz/dt/absorption) -- formato
de CLI/saida do fletcher-base e DESCONHECIDO, precisa inspecionar o repo
externo; (iii) MESMO teto de VRAM/RAM do CAMINHO A (single-process); (iv)
zero uso historico comprovado no repo -- seria trabalho NOVO, nao uma
ressurreicao.
CAMINHO C -- aceitar a limitacao: numerico independente so na(s) menor(es)
topologia(s) que couber(em) em np=1 (A ou B); nas demais, a evidencia
numerica disponivel e SOMENTE reprodutibilidade entre reps (determinismo ja
[EMP]) -- o que prova ESTABILIDADE, nao CORRECAO da fisica. Isso precisa
virar uma limitacao EXPLICITA na secao de Ameaças a Validade/Metodologia,
nao um fato escondido.

NENHUM caminho e "implementar" ainda -- e todos requerem decisao do usuario
sobre o que a fase "full" da REFINADA (secao 5.0) realmente deve validar,
dado que "1 full por topologia" nao pode mais significar uniformemente
"comparado a um ground truth independente" para as topologias grandes.

VEREDITO DESTA INVESTIGACAO: a pergunta original ("qual e o ground truth")
NAO TEM resposta unica e resolvida no repositorio -- ha uma metodologia
NARROW mas 100% reproduzivel (autoconsistencia np1, so N=64, so tolerancia
0/1e-3) e uma metodologia BROAD mas NAO reproduzivel a partir do repo
(SHA-256 vs fletcher-base, ate 512^3, tolerancia 1e-15, so em prosa). Nenhuma
das duas cobre a escala da campanha atual, e a fisica (VRAM/RAM) impede
QUALQUER metodo np=1 de cobrir a campanha inteira. Isto e uma limitacao
estrutural, nao um problema de engenharia a corrigir.

## 5.1-ter. DECISAO REGISTRADA: Caminho C (usuario, 2026-07-14)

Aceita a limitacao estrutural. Consequencias no design:

### Ajuste a fase "full" da REFINADA (5.0/5.1)
A fase full deixa de ser uniforme. Passa a ter DOIS papeis distintos por
topologia, e o orquestrador/checkpoint precisam saber diferenciar:

- **N=1536 (a unica que cabe em np=1):** full COM ground truth independente.
  Adicionar 1 run extra `np=1, backend OpenMP (dc-omp-aky ou bin/dc atual),
  mesmo tamanho`, comparado ao full np=N via CompareResults.R (adaptar:
  script le paths fixos validation/ground_truth.dc e validation/predicted.dc
  -- precisa parametrizar por experiment_id ou copiar/renomear por execucao).
  Runtime pequeno (CPU, sem GPU, sem rede) -- cabe folgado em qualquer
  reserva. Papel: unico ponto da campanha que valida FISICA (nao so
  decomposicao) contra uma execucao independente.
- **As demais 34 topologias (N>=1856):** full SEM ground truth possivel
  (fisicamente, per calculo VRAM/RAM da secao 5.1-bis). O run full ainda
  roda (native, 1x/topologia, produz .dc), mas seu UNICO papel de evidencia
  numerica passa a ser reprodutibilidade determinista entre reps -- que ja
  e EMP (seed=0, reps identicos). O .dc dessas topologias NAO tem contra o
  que ser comparado; validar-e-descartar (5.1) ainda se aplica, mas o
  "validar" vira "confirmar reprodutibilidade" (comparar .dc entre 2 reps
  da MESMA topologia, nao contra ground truth), nao "confirmar correcao
  fisica".

IMPLICACAO para checkpoint_integrity_ok (5.2): run_type=full precisa de um
sub-campo ou metadado "tem_ground_truth" (true so p/ N=1536) para o relatorio
final saber distinguir as duas evidencias -- caso contrario um leitor da
tese poderia inferir (erradamente) que todas as 35 topologias foram
numericamente validadas contra referencia independente.

### Ajuste a auditoria sistemica (secao 6, H2)
H2 estava "CONCEITUAL-ALTO, depende do usuario". RESOLVIDO: adotado Caminho
C. Novo risco residual, ja neutralizado por design: relatar corretamente
QUAL evidencia numerica cada topologia tem (ground-truth real em N=1536;
reprodutibilidade-apenas nas demais 34) e declarar isso como AMEACA A
VALIDADE explicita na metodologia/discussao da pesquisa -- nao e um risco
de implementacao, e uma obrigacao de redacao cientifica. Registrar como
[AMEACA-A-VALIDADE, aceita e documentada] em vez de [risco pendente].

### Texto sugerido para a secao de Ameacas a Validade (rascunho, para o
usuario adaptar na redacao final -- NAO e a redacao definitiva):
"A validacao numerica contra uma referencia independente (execucao np=1)
so foi possivel na menor topologia da campanha (N=1536), devido a limite
fisico de memoria (VRAM/RAM) de execucao single-process nas topologias
maiores. Para as demais topologias, a evidencia de correcao numerica e a
reprodutibilidade determinista entre repeticoes (mesma semente, resultados
bit-identicos), que atesta estabilidade mas nao equivale a validacao contra
referencia externa. Este e um limite estrutural do problema (volume de
memoria cresce com N^3), nao uma lacuna de metodologia corrigivel dentro do
escopo deste trabalho."

STATUS: secao 5 (orquestrador) e secao 6 (auditoria sistemica) ATUALIZADAS
e RECONCILIADAS com esta decisao. Passos 4 e 5 (VRAM + orquestrador) e a
auditoria sistemica estao completos. Dependencia externa (ground_truth)
FECHADA por decisao do usuario. Resta, antes de implementar: fechar as 3
lacunas de design apontadas na secao 6.5 (sonda de shaping, re-censo de nos
on-failure, orcamento disco/trace+buffer Akypuera) -- ainda nao desenhadas
em detalhe, so identificadas como lacunas.

## 5.0-quater. PREMISSA FINAL DA CAMPANHA (fixada pelo usuario, 2026-07-14) -- SUPERSEDE 5.0/5.1/5.1-ter

Reconstruida a partir do CSV real (g5k/csv/experimentos.csv): NAO sao 35
topologias independentes, sao **10 decomposicoes MPI distintas**, cada uma
testada numa faixa de N crescente (varredura de weak-scaling -- bate com o
ultimo commit do historico do Fletcher, "swr-weak-scalability-new"):

  Topologia   N testados (CLI global)              n_linhas(x3 bandas)
  1x2x2       64,128,256,512,1024,1088..1472 (12)   36
  2x2x2       1536,1600,1664,1728,1792,1856 (6)      18
  2x2x3       1920,1984,2048,2112 (4)                12
  2x2x4       2176,2240,2304,2368 (4)                12
  2x2x5       2432,2496 (2)                           6
  2x2x6       2560,2688 (2)                           6
  3x3x3       2752,2816 (2)                           6
  2x3x4       2624 (1)                                3
  2x3x5       2880 (1)                                3
  2x4x4       2944 (1)                                3
  TOTAL: 35 (topologia,N) unicos x 3 bandas = 105 linhas.

PREMISSA FIXADA: 1 execucao FULL por topologia (nao por linha), sempre no
MENOR N daquela topologia -- assumindo que esse representante e suficiente
para validar a corretude da decomposicao/topologia. TODAS as demais
combinacoes (topologia,N,banda) e TODAS as repeticoes (inclusive as do
proprio representante) rodam em modo BENCHMARK (--skip-output), coletando
so metricas de desempenho (media, desvio padrao).

CONSEQUENCIA NUMERICA (recalculo, substitui os numeros de 5.0/5.1-ter):
  FULL: 10 execucoes totais (nao 35, nao 105). NATIVE (sem shaping -- full
    e so p/ corretude, banda e irrelevante para o resultado numerico, per
    5.0). Custo desprezivel de tempo/disco comparado ao design anterior.
  BENCH: 105 linhas x REPS_PER_EXPERIMENT(5) = 525 execucoes, shaped por
    linha, --skip-output (sem gather/escrita, sem risco de deadlock em
    NENHUMA banda, inclusive 1gbit multi-no).

GROUND TRUTH por topologia-representante, recalculado (formula/orcamento
da secao 5.1-bis, agora aplicado aos 10 N reais, nao a 6 amostras):

  Topologia  N(rep)  ranks  VRAM np1 CUDA(GB)  cabe 40GB?  RAM np1 OMP(GB)  cabe 512GB?
  1x2x2         64     4        0.0      SIM          0.0      SIM
  2x2x2       1536     8       87.0      NAO        289.9      SIM
  2x2x3       1920    12      169.9      NAO        566.2      NAO
  2x2x4       2176    16      247.3      NAO        824.3      NAO
  2x2x5       2432    20      345.2      NAO       1150.7      NAO
  2x2x6       2560    24      402.7      NAO       1342.2      NAO
  2x3x4       2624    24      433.6      NAO       1445.4      NAO
  3x3x3       2752    27      500.2      NAO       1667.4      NAO
  2x3x5       2880    30      573.3      NAO       1911.0      NAO
  2x4x4       2944    32      612.4      NAO       2041.3      NAO

  => SOMENTE 2 das 10 topologias podem ter ground truth real via np=1:
     1x2x2 (N=64, cabe em CUDA E OpenMP -- trivial, reusa o padrao historico
     de run-dc-comparison/CompareResults.R, secao 5.1-bis item 3, so que
     hoje com dc-omp-aky/dc-cuda-aky em vez das variantes mpiP removidas)
     e 2x2x2 (N=1536, cabe SO em OpenMP/RAM-host, marginal: 290 de 512GB).
     As OUTRAS 8 topologias-representante: full roda (native, produz .dc),
     mas SEM ground truth possivel -- unica evidencia numerica e
     reprodutibilidade determinista entre reps (ja EMP). Ver Caminho C
     (5.1-ter) -- agora aplicado a 8 de 10 topologias, nao a 34 de 35 linhas
     (mesma limitacao estrutural, escopo menor e mais preciso).

DISCO -- recalculo com os N reais (nao amostras):
  Tamanho .dc por topologia-representante (N^3 x 2 campos x 4 bytes):
    1x2x2/N64: ~0 GB | 2x2x2/N1536: 28.99 GB | 2x2x3/N1920: 56.62 GB |
    2x2x4/N2176: 82.43 GB | 2x2x5/N2432: 115.07 GB | 2x2x6/N2560: 134.22 GB |
    2x3x4/N2624: 144.54 GB | 3x3x3/N2752: 166.74 GB | 2x3x5/N2880: 191.10 GB |
    2x4x4/N2944: 204.13 GB (PICO transiente maximo).
  Formula [DOC, de coordinator.c:183-205] = N^3*2*4 bytes; [EMP] confirmada:
  1536^3*2*4 = 28.991.029.248 bytes = bate EXATO com o predicted_..._N1536.dc
  ja observado (28.99GB) nesta sessao.
  Soma se os 10 fossem guardados simultaneamente: 1.123,8 GB -- NAO e o
  plano; validar-e-descartar (5.1) mantem no maximo 1 .dc por vez.
  BENCH (525 execucoes, so trace, SEM .dc): estimado ~415 MB no total da
  CAMPANHA INTEIRA (modelo abaixo, secao de lacuna 3) -- desprezivel.

ESTADO: esta e agora a premissa fixa do projeto (per instrucao do usuario).
Superseding qualquer numero de "35 full" ou "1 full+4 bench por celula" em
secoes anteriores deste documento.

---

## 7. Lacuna 1 -- Sonda de banda efetiva (fecha SPOF-4 da auditoria sistemica)

### Problema
validate_before_batch (g5k/lib/validate.sh:126-138) hoje SO confirma que um
qdisc tbf EXISTE na interface (`tc qdisc show | grep tbf`) -- uma checagem
ESTRUTURAL, nao FUNCIONAL. Um run "10gbit" que na verdade trafega em
velocidade nativa (interface errada, tc falhou silenciosamente, kavlan
renomeado entre reservas, etc.) passaria por essa checagem sem erro, e
CONTAMINARIA a metrica de masking daquele lote inteiro sem sinal visivel.

### Design proposto
Nova funcao `validate_bandwidth_effective <expected_rate_bps>`, chamada de
dentro de validate_before_batch logo apos a checagem de qdisc existente:
  1. Escolhe 2 nos: head_node() e o proximo em nodes() (se so 1 no
     disponivel, PULA -- trafego intra-no nunca cruza a NIC shaped, shaping
     e irrelevante).
  2. Usa os IPs do kavlan ja capturados (kavlan_ips.txt, ja existe no
     STATE_DIR desta sessao) -- forca o bind na interface shaped
     especificamente (nao qualquer IP), fechando a possibilidade de medir
     por um caminho diferente do usado pela campanha.
  3. `iperf3 -s -1 -B <ip_no2>` (servidor one-shot) em background no no2;
     `iperf3 -c <ip_no2> -B <ip_no1> -t 3 -J` no no1; parse do bits_per_second
     do JSON.
  4. Compara taxa alcancada vs expected_rate_bps com tolerancia (banda
     assimetrica: piso ~50% -- TCP slow-start/buffer pequeno em teste curto
     pode subestimar --, teto ~130% -- exceder de forma relevante e a
     assinatura do vazamento).
  5. Fora da tolerancia -> `die()` com diagnostico completo (taxa medida,
     taxa esperada, `tc qdisc show` de ambos os nos, par de nos usado) --
     ABORTA O LOTE inteiro, nao segue silenciosamente (silenciar e
     exatamente o risco que se fecha aqui).

Roda 1x por lote de banda (3x por execucao de campanha) -- custo de ~10-30s
total, desprezivel frente a campanha de horas.

### Ferramenta: iperf3 vs sonda via MPI
iperf3 [EMP: presente no frontend, `which iperf3` -> /usr/bin/iperf3] --
[HIP, a confirmar em smoke test: presenca no MESMO no de computo/imagem de
deploy debiannvopen11-big; mitigacao: fallback para iperf3 via Nix
(pkgs.iperf3), reduzindo dependencia da imagem base].
Alternativa descartada: medir banda via o proprio dc/MPI (2 ranks, poucas
iteracoes, ler Start/End do dc.csv) -- mais fiel ao caminho exato
(UCX/OpenMPI/pml_ucx_tls), mas mais caro/lento (precisa subir todo o
ambiente CUDA/MPI so para medir banda) e redundante: tbf hoje e
INTERFACE-WIDE (shape.sh usa `tc qdisc add ... root ... tbf`, nao
`htb`/classes por-fluxo) -- ou seja, qualquer trafego saindo da interface,
seja iperf3 seja MPI, sofre o MESMO enforcement. iperf3 e suficiente
ENQUANTO o mecanismo de shaping permanecer interface-wide; se um dia virar
per-flow/per-porta, essa equivalencia quebra e a sonda precisaria ser
refeita com trafego MPI real -- ANOTAR essa premissa explicitamente como
[HIP condicional ao design atual do shape.sh].

### Auditoria critica (tentativas de refutacao)
- [HIP] iperf3 mede fluxo TCP BULK e SUSTENTADO; o trafego real do halo e
  PEQUENO e EM RAJADAS (troca de ghost cells por iteracao, nao um stream
  continuo). O parametro burst do tbf (bps/8/500, ~2ms de bytes) foi
  dimensionado pensando em rajadas, mas NUNCA foi validado empiricamente
  contra o padrao real de mensagens pequenas do Fletcher -- e possivel que
  bursts pequenos e frequentes "escapem" do enforcement de um jeito que um
  teste de iperf3 sustentado nao revelaria (ou o inverso: o iperf3 pode ser
  mais facilmente limitado que trafego em rajadas curtas, dando um FALSO
  ALARME). Isto e uma LACUNA METODOLOGICA RESIDUAL, aceita conscientemente:
  a sonda pega vazamento GROSSEIRO (shaping ausente/interface errada/taxa
  muito diferente), NAO valida a equivalencia fina rajada-vs-sustentado.
  Se o rigor exigir isso, precisaria de uma sonda baseada no proprio padrao
  de trafego do dc -- fora de escopo deste v1; registrar como possivel
  Ameaca a Validade se for relevante para a tese.
- [EMP-pendente] A tolerancia (50%-130%) e um CHUTE, nao calibrada. O
  PRIMEIRO smoke test em cada banda (1/10/25gbit) deve registrar a taxa
  medida real e ajustar a tolerancia com base em dado, nao suposicao a
  priori.
- Falha de iperf3 em si (nao instalado, porta bloqueada) deve FALHAR
  FECHADO (abortar o lote), nunca ser tratada como "sonda inconclusiva,
  segue assim mesmo" -- selecionar fail-closed e deliberado (o custo de um
  falso-abort e uma reexecucao; o custo de um falso-pass e um lote inteiro
  de dados contaminados sem deteccao).

### Integracao com o orquestrador existente
So estende validate_before_batch (ja chamada 1x por banda no loop principal
de 02-orchestrator.sh); nao toca run.sh, csv.sh, checkpoint.sh. Nao precisa
de novos pacotes alem de iperf3 (com fallback Nix). Trade-off: ~10-30s x 3
por execucao de orquestrador, por uma reducao real do risco de contaminar
silenciosamente uma banda inteira de medicoes -- payoff assimetrico,
compensa.

---

## 8. Lacuna 2 -- Re-censo de nos on-failure (fecha O1 da auditoria sistemica)

### Problema
`nodes()` (g5k/lib/core.sh:55) le direto de $NODES_FILE, um arquivo ESTATICO
escrito 1x no bootstrap. `AVAIL=$(node_count)` (02-orchestrator.sh:39) e
calculado 1x, no INICIO da execucao do orquestrador. Se um no morre no MEIO
da campanha (documentadamente plausivel: 3/8 nos up no inicio desta sessao,
hardware chuc descrito como instavel), nada detecta ou reage -- toda
experiencia que precisar do numero ORIGINAL de nos vai falhar repetidamente
contra um no morto, ate estourar o cap de retentativas (failed_permanent),
mesmo que experiencias com MENOS nos pudessem prosseguir perfeitamente bem.

### Design proposto
Deteccao REATIVA (nao periodica -- evita custo de SSH em toda experiencia
quando nada esta errado):
  Gatilhos: (a) checkpoint_should_run decide re-rodar uma rep apos ela ter
  sido marcada `failed`; (b) run_experino retorna != 0 E o orphan-sweep
  (5.4) reporta no inalcancavel; (c) dc.output contem assinatura de falha
  de conectividade ("Connection refused", "No route to host", timeout de
  ssh nos logs do mpirun).
  Ao disparar: nova funcao `nodes_liveness_probe()` (setup.sh), DISTINTA de
  gpu_census (que hoje da die() em qualquer falha de ssh -- inadequada para
  reuso reativo): para cada host em NODES_FILE, `ssh_root $h true` com
  ConnectTimeout curto (~5s), EM PARALELO (background+wait, nao serial --
  evita travar a varredura toda por 1 no lento, mesmo problema ja resolvido
  para a varredura de orfaos na secao 5.4). Classifica vivo/morto; escreve
  $STATE_DIR/nodes_alive.txt (derivado, NUNCA sobrescreve NODES_FILE
  original -- preserva o registro da alocacao original para auditoria).

### Reacao
Mudanca MINIMA e LOCALIZADA em core.sh: `nodes()` passa a preferir
nodes_alive.txt quando ele existir, com fallback para NODES_FILE:
  nodes() { local f="${STATE_DIR}/nodes_alive.txt";
            [ -s "$f" ] && cat "$f" || grep -v '^[[:space:]]*$' "$NODES_FILE"; }
Como node_count()/head_node()/csv_build_experiment_hostfile() JA derivam
todos de nodes(), essa e a UNICA mudanca estrutural necessaria -- o
mecanismo de "linhas compativeis" do csv.sh (csv_each_compatible_row, ja
existente) automaticamente passa a excluir linhas que exigem mais nos que o
AVAIL atualizado, na PROXIMA chamada do loop -- sem precisar de um estado
"deferred" persistido (coerente com a decisao da secao 5.3: deferred/
skipped sao recomputados, nao gravados). Uma reserva futura maior
(bootstrap novo) naturalmente reescreve NODES_FILE e apaga/recria
nodes_alive.txt, resgatando as linhas que ficaram para tras.

### Auditoria critica
- [HIP] no trava a resposta em vez de recusar rapido: ConnectTimeout curto
  + paralelismo (mesma mitigacao ja usada na varredura de orfaos, 5.4).
- [HIP] no "flapping" (volta rapido depois de marcado morto): deteccao
  reativa-apenas significa que NAO re-testamos um no ja marcado morto ate
  o proximo bootstrap -- aceitavel: correcao da campanha nao depende de
  usar TODO no possivel, so de nao travar nos que sumiram; recuperar um no
  que voltou e OTIMIZACAO, nao correcao -- DELIBERADAMENTE fora de escopo
  do v1 (evita over-engineering para um caso raro).
- [DOC] nos chuc sao exclusivos por alocacao -- um no "morto" e falha real
  de hardware/deploy, nao contencao com terceiros.
- Risco de NAO implementar: sem isso, 1 no morto poderia bloquear (via
  retentativas ate failed_permanent) uma fatia GRANDE das linhas restantes
  da campanha que exigem o numero original de nos -- mesmo que menos-nos
  pudesse prosseguir. Este design converte uma falha "trava a campanha" em
  uma falha "degrada graciosamente, linhas voltam na proxima reserva" -- por
  um custo de implementacao pequeno e localizado (1 funcao nova em setup.sh,
  1 mudanca de poucas linhas em core.sh, 2-3 pontos de gatilho no
  fluxo de retentativa).

### Integracao com o orquestrador existente
Toca core.sh (nodes()), setup.sh (nova nodes_liveness_probe()), e o ponto
de retentativa do orquestrador/run.sh (dispara a sonda antes de re-tentar
uma rep cuja tentativa anterior tem assinatura de conectividade). NAO muda
a logica de filtragem de csv.sh (ja correta, so precisa de AVAIL fresco).

---

## 9. Lacuna 3 -- Orcamento de disco/trace + buffer Akypuera (fecha O3/O4)

### Evidencia nova que revisa a severidade do risco
[EMP, nesta sessao] `iterations = ceil(time_max/dt) = ceil(1e-4/1e-6) = 100`
(src/coordinator.c:36) -- FIXO, independente de N (parametros fisicos
"UNCHANGED from every validated run so far", defaults.conf). rastro-*.rst
reais observados (g5k/results/1gbit_1n_4g_N64/rep1, np=4): ~65-66 KB por
rank. Akypuera grava METADADOS de evento (tipo de chamada MPI + timestamps
+ campo de valor pequeno), NAO o payload transferido -- portanto o tamanho
do trace por rank escala com (iteracoes x mensagens-por-iteracao), NAO com
N^3. Extrapolando para a MAIOR topologia (2x4x4, 32 ranks, MESMAS 100
iteracoes): ainda ~65KB/rank esperado, ~2MB no total daquele rep.
RST_BUFFER_SIZE=1GB tem entao margem de ~16.000x por rank -- a preocupacao
original (O4 da auditoria sistemica) era caucao [HIP] razoavel a priori,
mas a evidencia disponivel REBAIXA esse risco para desprezivel. [HIP
residual, nao fechado]: essa proporcionalidade (tamanho~ranks x iteracoes,
independente de N) pressupoe que libaky (dependencia EXTERNA, fora deste
repo, codigo nao inspecionado) sempre grava registro de tamanho fixo por
evento -- inferido do UNICO ponto de dado disponivel (N=64/np=4), nao
confirmado para N grande. RECOMENDACAO: o smoke test do full nativo N=1536
(que vai rodar de qualquer forma, per premissa desta secao) deve registrar
o tamanho de rastro-*.rst obtido e confirmar que continua ~65KB/rank -- 
fecha [HIP]->[EMP] de graca, sem custo extra de reserva.

### O risco real: disco para os .dc dos FULL runs (nao os traces do bench)
Sob a premissa final (10 full, 525 bench-so-trace): os TRACES do bench
somam, para a CAMPANHA INTEIRA (105 linhas x 5 reps x tamanho de rastro por
topologia): estimativa ~415 MB total -- desprezivel frente aos 2.3TB livres
em /home (NFS). O risco real e OS 10 ARQUIVOS .dc DOS FULL RUNS, que vao de
~0 a 204.13 GB (2x4x4/N2944, o PICO transiente). A politica
"validar-e-descartar" (secao 5.1) ja cobre isso EM PRINCIPIO, mas o preflight
de disco hoje (`validate_disk_space`, g5k/lib/validate.sh:94-101) usa um
PISO GENERICO (20GB/10GB) -- insuficiente por MUITO para os full grandes: um
run de 204GB passaria o preflight de 20GB e falharia por ENOSPC NO MEIO DA
ESCRITA, o que (per auditoria sistemica O3) PARECERIA UM HANG, desperdicando
tempo de parede ate ser diagnosticado.

### Design proposto
1. Nova funcao pura (csv.sh ou checkpoint.sh): `csv_expected_dc_bytes <N>` =
   N^3 * 2 * 4 (campos pc+qc, 4 bytes cada -- formula de coordinator.c:183-205,
   [EMP] confirmada: 1536^3*2*4 = 28.991.029.248 bytes bate EXATO com o
   predicted_..._N1536.dc ja observado nesta sessao, 28,99GB). Reusada em
   DOIS lugares: (a) preflight de disco antes de cada full; (b) extensao do
   checkpoint_integrity_ok para full (secao 5.2: "exige .dc do tamanho
   esperado") -- uma unica formula, sem duplicacao.
2. `validate_disk_space_for_full <N>`: antes de CADA um dos 10 full runs
   (nao antes dos bench, cujo footprint e desprezivel), exige
   free_space >= csv_expected_dc_bytes(N) * 1.10 (margem de 10%) -- se
   nao houver espaco, `die()`/DEFER (nao FAIL) com mensagem clara: quanto
   precisa, quanto ha, e que o full sera retomado quando houver espaco
   (analogo ao gate de walltime da secao 5.5).
3. Chamado especificamente na fase full (--phase full|all, secao 5.6),
   nao na fase bench.

### Auditoria critica
- [DOC] formula de tamanho -- derivada do codigo (coordinator.c), nao
  suposta.
- [EMP] formula validada contra arquivo real (N=1536, 28.99GB exato).
- [HIP residual] proporcionalidade do trace independente de N -- fecha
  via smoke test do full N=1536 (de graca, ja vai rodar).
- Risco de NAO implementar o preflight parametrizado: um ENOSPC no meio da
  escrita do maior full (204GB) e indistinguivel de um hang (write trava,
  sem crescer) ate alguem investigar manualmente -- desperdica walltime
  numa reserva cara. O preflight parametrizado elimina essa classe de
  falha por completo (falha ANTES de comecar, com diagnostico claro, em vez
  de no meio, silenciosa).
- NFS e QUOTA COMPARTILHADA (2.3TB livre de 14TB, 84% ja usado por OUTROS
  dados) -- um terceiro pode consumir o espaco entre o preflight e a
  escrita real (TOCTOU classico) -- mitigacao: a escrita real, se falhar
  por ENOSPC mesmo apos o preflight passar, deve ser tratada como uma
  categoria de falha DISTINTA (nao "hang", nao "oom") no checkpoint, para
  diagnostico rapido caso ocorra (residual [HIP], aceito, fora do nosso
  controle direto).
- Trade-off: custo de implementacao pequeno (1 funcao pura + 1 chamada de
  validacao + 1 chamada de `df` por full, 10x no total da campanha) por
  eliminar o unico cenario de disco real e quantificavel (o outro, os
  traces do bench, ja se mostrou desprezivel pela evidencia).

### Integracao com o orquestrador existente
Estende validate.sh (nova validate_disk_space_for_full, ao lado da
validate_disk_space generica ja existente) e reusa a formula em
checkpoint.sh (integrity check do full, secao 5.2) -- nenhuma mudanca em
run.sh; chamada adicionada no ponto onde --phase full decide iniciar cada
um dos 10 full runs.

---

## 10. Conclusao do planejamento da campanha (fechamento solicitado pelo usuario)

Com a premissa final fixada (secao 5.0-quater) e as 3 lacunas desenhadas
(secoes 7-9), o planejamento da infraestrutura de campanha esta
COMPLETO em nivel de design/auditoria. Resumo do que falta e SO
implementacao (nenhuma decisao metodologica em aberto):
  - run_type (full/bench) + tem_ground_truth no checkpoint (5.2/5.1-ter)
  - retencao validar-e-descartar + preflight de disco parametrizado (9)
  - inflight.txt + varredura de orfaos + re-censo de nos (5.4, 8)
  - walltime/timeout em 2 camadas (5.5)
  - sonda de banda efetiva (7)
  - flag --phase full|bench|all + lock por PID (5.6)
  - --skip-output no binario dc (secao 3, ja desenhado antes)
Smoke tests da 1a reserva (secao 6.4) permanecem o unico portao entre
design e confianca operacional plena -- nenhum deles bloqueia o INICIO da
implementacao, todos fecham [HIP]->[EMP] DURANTE a propria alocacao de
smoke test.
