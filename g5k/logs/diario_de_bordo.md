# Diário de bordo — campanha experimental

- **2026-07-10 16:17:32** — Deploy iniciado em 2 nós: chuc-4.lille.grid5000.fr,chuc-6.lille.grid5000.fr (env=debiannvopen11-big)
- **2026-07-10 16:21:29** — Deploy concluído. IPs kavlan: chuc-4.lille.grid5000.fr 10.8.9.104/18,chuc-6.lille.grid5000.fr 10.8.9.106/18
- **2026-07-10 16:27:58** — Deploy iniciado em 2 nós: chuc-4.lille.grid5000.fr,chuc-6.lille.grid5000.fr (env=debiannvopen11-big)
- **2026-07-10 16:33:48** — Deploy concluído. IPs kavlan: chuc-4.lille.grid5000.fr 10.8.9.104/18,chuc-6.lille.grid5000.fr 10.8.9.106/18
- **2026-07-10 16:42:59** — Setup concluído. Censo de GPU: chuc-4.lille.grid5000.fr 4,chuc-6.lille.grid5000.fr 4
- **2026-07-10 16:43:04** — Build OK (BACKEND=cuda PROFILE=akypuera ARCH=sm_80), commit=4bd74bb
- **2026-07-10 16:50:34** — Pre-flight de campanha: OK. sha256(bin/dc)=e0c1e6afdb55e2fed62c1d86ae473b548d165169c86b57df1c4ddda03aa25ca3
- **2026-07-10 16:51:24** — Versões de toolchain capturadas em /home/aandrade/ic/io-research/distributed-cube-average/g5k/logs/versions.txt
- **2026-07-10 16:51:43** — Orquestrador iniciado. 2 nós disponíveis, 54/105 linhas compatíveis. dry_run=1 only_id=<todos>
- **2026-07-10 16:51:43** — Pulado 1gbit_1n_4g_N1472: VRAM 36.03GB > orçamento seguro.
- **2026-07-10 16:51:43** — Pulado 1gbit_2n_8g_N1856: VRAM 36.19GB > orçamento seguro.
- **2026-07-10 16:51:43** — Pulado 10gbit_1n_4g_N1472: VRAM 36.03GB > orçamento seguro.
- **2026-07-10 16:51:43** — Pulado 10gbit_2n_8g_N1856: VRAM 36.19GB > orçamento seguro.
- **2026-07-10 16:51:43** — Pulado 25gbit_1n_4g_N1472: VRAM 36.03GB > orçamento seguro.
- **2026-07-10 16:51:43** — Pulado 25gbit_2n_8g_N1856: VRAM 36.19GB > orçamento seguro.
- **2026-07-10 16:51:43** — Execução do orquestrador finalizada: OK=0 FAILED=0 SKIPPED_DONE=0 SKIPPED_VRAM=6
- **2026-07-10 16:52:30** — Pre-flight de campanha: OK. sha256(bin/dc)=e0c1e6afdb55e2fed62c1d86ae473b548d165169c86b57df1c4ddda03aa25ca3
- **2026-07-10 16:52:30** — Orquestrador iniciado. 2 nós disponíveis, 54/105 linhas compatíveis. dry_run=0 only_id=1gbit_1n_4g_N64
- **2026-07-10 16:52:41** — Experimento 1gbit_1n_4g_N64 rep1 -> done (10s)
- **2026-07-10 16:52:53** — Experimento 1gbit_1n_4g_N64 rep2 -> done (11s)
- **2026-07-10 16:53:04** — Experimento 1gbit_1n_4g_N64 rep3 -> done (11s)
- **2026-07-10 16:53:15** — Experimento 1gbit_1n_4g_N64 rep4 -> done (11s)
- **2026-07-10 16:53:26** — Experimento 1gbit_1n_4g_N64 rep5 -> done (10s)
- **2026-07-10 16:53:28** — Execução do orquestrador finalizada: OK=5 FAILED=0 SKIPPED_DONE=0 SKIPPED_VRAM=0
- **2026-07-10 16:55:27** — Pre-flight de campanha: OK. sha256(bin/dc)=e0c1e6afdb55e2fed62c1d86ae473b548d165169c86b57df1c4ddda03aa25ca3
- **2026-07-10 16:55:27** — Orquestrador iniciado. 2 nós disponíveis, 54/105 linhas compatíveis. dry_run=0 only_id=1gbit_1n_4g_N64
- **2026-07-10 16:55:28** — Execução do orquestrador finalizada: OK=0 FAILED=0 SKIPPED_DONE=5 SKIPPED_VRAM=0
- **2026-07-10 17:28:31** — Deploy iniciado em 1 nós: chifflot-5.lille.grid5000.fr (env=debiannvopen11-big)
- **2026-07-10 17:29:54** — INCIDENTE: tentativa de rodar 01-bootstrap.sh (incluindo deploy_run) neste shell (job 2166398, chifflot-5) sobrescreveu state/nodes.txt com o nó errado antes de falhar no kadeploy3 (binário não existe em nó de compute). Corrigido manualmente restaurando chuc-4/chuc-6 (job 2165368, confirmado via oarstat assigned_hostnames). Nenhuma ação destrutiva chegou a atingir chuc-4/chuc-6 — kadeploy3 nunca executou. Lição: scripts que chamam deploy_run() (kadeploy) só podem rodar a partir do frontend dentro do job de deploy correto, nunca deste shell interativo separado.
- **2026-07-10 17:30:12** — Setup concluído. Censo de GPU: chuc-4.lille.grid5000.fr 4,chuc-6.lille.grid5000.fr 4
- **2026-07-10 17:30:16** — Build OK (BACKEND=cuda PROFILE=akypuera ARCH=sm_80), commit=4bd74bb
- **2026-07-10 17:30:22** — Pre-flight de campanha: OK. sha256(bin/dc)=dcae929338429153f8ff9ace0374a78fcc850ef19a203315aa5fb93c865e4201
- **2026-07-10 17:30:22** — Versões de toolchain capturadas em /home/aandrade/ic/io-research/distributed-cube-average/g5k/logs/versions.txt
- **2026-07-10 17:30:22** — Revalidacao (sem redeploy) na alocacao job 2165368: setup+build+preflight+versions OK, nodes.txt restaurado.
- **2026-07-10 17:31:13** — Pre-flight de campanha: OK. sha256(bin/dc)=dcae929338429153f8ff9ace0374a78fcc850ef19a203315aa5fb93c865e4201
- **2026-07-10 17:31:13** — Orquestrador iniciado. 2 nós disponíveis, 54/105 linhas compatíveis. dry_run=0 only_id=1gbit_2n_8g_N1536
- **2026-07-10 17:31:48** — Experimento 1gbit_2n_8g_N1536 rep1 -> failed (32s)
- **2026-07-10 18:14:39** — INCIDENTE: sessão do agente foi reiniciada durante a execução de 1gbit_2n_8g_N1536 rep2, deixando mpirun/prterun órfãos rodando em chuc-4/chuc-6 por ~40min sem progresso real (GPUs em 0% utilização, ~75-85W = ocioso — processo travado, provavelmente deadlock de comunicação após o kill -9 do rep1 anterior ter deixado sockets/estado UCX inconsistente). Processos eliminados manualmente, diretório rep2 incompleto removido. rep1 permanece corretamente marcado 'failed' no checkpoint (nunca produziu dc.csv/dc.trace válidos) — é exatamente o cenário de teste de robustez pedido: falha detectada corretamente, resultado parcial não aceito como válido.
- **2026-07-10 18:18:04** — Pre-flight de campanha: OK. sha256(bin/dc)=dcae929338429153f8ff9ace0374a78fcc850ef19a203315aa5fb93c865e4201
- **2026-07-10 18:18:04** — Orquestrador iniciado. 2 nós disponíveis, 54/105 linhas compatíveis. dry_run=0 only_id=1gbit_2n_8g_N1536
- **2026-07-10 18:39:26** — Alocação (job 2165368) próxima do fim (~6min restantes às 18:39). Segunda ocorrência do mesmo travamento em 1gbit_2n_8g_N1536 (0% GPU por vários minutos após breve atividade inicial) — padrão reproduzível, não foi acaso da sessão anterior. HIPÓTESE a investigar na próxima alocação: possível deadlock de comunicação MPI/UCX especificamente em N=1536 (8 ranks, 2x2x2, 1gbit shaped) — pode estar relacionado a starvation de banda no tc tbf com burst insuficiente para o tamanho de mensagem de halo desse N, ou a um problema de ordenação de sends/recvs que só se manifesta com N grande o suficiente. N=64 (1 nó) sempre funcionou perfeitamente (10/10 reps OK). NÃO investigado further por falta de tempo nesta sessão. Sessão encerrada com job quase expirando; nenhum dado inválido foi salvo (checkpoint/integridade funcionaram corretamente em ambas as tentativas de travamento, marcando 'failed' ou nunca marcando 'done').
- **2026-07-14 01:27:09** — SESSAO NOVA (host local, ssh.exe->grid->lille): investigacao do INCIDENTE de 2026-07-10 (hang reproduzivel em 1gbit_2n_8g_N1536). Alocacao atual: job 2167768, chuc-3/chuc-4/chuc-8 (deploy+setup+build OK, commit 4bd74bb).
- **2026-07-14 01:27:09** — TESTE 1 (native, sem shaping, N=1536 size_cli=1524, np=8, chuc-3+chuc-4): as 100 iteracoes completam normalmente (GPUs 75-95% util, halo exchange OK). GPU cai a 0%% apos ~30s, mas NAO e hang: e a fase pos-iteracao (dc_send_data_to_coordinator + dc_receive_and_write_results). Output .dc chega a 28991029248 bytes (tamanho correto) rapido (pre-alocacao via fseek+fwrite no fim do arquivo), mas write_bytes real do coordenador cresce so ~4MB/s (D state intermitente) -> ~2h para 29GB reais. Matei o processo (nao esperei os 2h), sem interesse cientifico em completar a escrita.
- **2026-07-14 01:27:09** — TESTE 2a (shaped 1gbit, mesmo N=1536/np=8): reproduziu o hang do incidente ORIGINAL, mas em estado limpo (sem contaminacao de kill -9 anterior) -- ou seja, e um comportamento INTRINSECO, nao residuo de sessao anterior como a hipotese do diario de 2026-07-10 sugeria. Instrumentacao (GPU util + rx_bytes kavlan + write_bytes coordenador) mostrou: t=0-105s progresso normal das 100 iteracoes (GPU ativa 60-99%%, rede 100-126MB/s = quase taxa de linha do link 1gbit); a partir de t~120s STALL DURO: GPU 0%%, rx_bytes PARADO (zero trafego, nao apenas lento), coord_write=0, por >3min sem nenhum progresso.
- **2026-07-14 01:27:09** — CAUSA RAIZ identificada via gdb -p <pid> -batch -ex bt em ranks travados: NAO e deadlock na troca de halos (Isend/Irecv+Waitall em worker.c esta correto, recvs pre-postados antes dos sends). O stall e na FASE DE COLETA DE RESULTADOS: coordenador (rank0) preso em MPI_Recv dentro de dc_receive_and_write_results (coordinator.c:197), TODOS os 8 workers presos em MPI_Send bloqueante dentro de dc_send_data_to_coordinator (worker.c:410-414, envia sizes+pc+qc, ~1.8GB cada um de pc/qc por worker em N=1536). Rendezvous MPI de mensagens de ~1.8GB via UCX/TCP (uct_tcp, forcado pelo shaping) trava; via UCX/RDMA nativo (Teste 1) o gather completa (lento mas sem stall).
- **2026-07-14 01:27:09** — SEGUNDA causa contribuinte (independente do shaping): coordinator.c:183-205 (dc_receive_and_write_results) escreve o resultado com fseek+fwrite de 1 FLOAT (4 bytes) por voxel, dentro de um loop triplo x/y/z -- ou seja O(N^3) chamadas fseek+fwrite por worker (para N=1536: ~446M voxels/worker x 8 workers x 2 campos pc/qc = ~7.1 bilhoes de pares fseek+fwrite). Confirmado com TESTE 2b (native, --output-file=/dev/null, remove I/O real de disco): mesmo sem I/O real, o loop continua CPU-bound por varios minutos so pelo overhead de chamada de funcao/libc -- ou seja o padrao de escrita e o gargalo dominante, nao (so) o NFS. Indexacao confirmada em include/indexing.h: x e a dimensao contigua (index = x + y*size_x + z*size_x*size_y), entao o loop interno em x mapeia uma faixa contigua da origem (pc/qc) para uma faixa contigua no arquivo -- FIX proposto (nao aplicado ainda): substituir os fwrite(1 float) por UM fwrite por linha x contigua (worker_sizes[0]-2*STENCIL floats), reduzindo O(N^3) para O(N^2) syscalls (~764x menos chamadas p/ N=1536).
- **2026-07-14 01:27:09** — CONCLUSAO: o incidente de 2026-07-10 (1gbit_2n_8g_N1536 rep1 failed, rep2 travado ~40min a 0%% GPU) NAO foi deadlock de ordenacao MPI nem estado UCX residual de kill -9 anterior (como hipotetizado no diario original) -- foi a fase de coleta+escrita de resultados, que sob shaping 1gbit trava (gather bloqueante de arrays ~1.8GB via TCP) e mesmo sem shaping e dominada por um padrao de escrita O(N^3) extremamente ineficiente (~horas para N=1536). Para a campanha atual (experimentos.csv, todos rodam SHAPED por design -- ver scripts/02-orchestrator.sh RUN_NATIVE=0 fixo), qualquer linha com N>=768 provavelmente vai travar/estourar walltime na fase de escrita, independente de correcao de rede. PROXIMO PASSO recomendado: corrigir coordinator.c para usar fwrite em bloco (O(N^2)) antes de tentar novamente experimentos N grande; considerar tambem se o gather de pc/qc completo (nao apenas a fatia que sera escrita) e necessario ou pode ser evitado/paralelizado (escrita paralela via MPI-IO, cada worker escreve sua fatia diretamente).
- **2026-07-14 02:47:15** — CARACTERIZACAO DA CAUSA 1 POR BANDA (1gbit/10gbit/25gbit): reexecutei o gather bloqueante (dc_send_data_to_coordinator/dc_receive_and_write_results) sob 10gbit e 25gbit. Teste direto em N=1536/np=8 sob 10gbit ficou preso por >4min apenas na escrita LOCAL do coordenador (Causa 2, sem rede) antes de sequer alcancar o primeiro worker remoto -- inviavel esperar pelo caminho natural (extrapolando do ritmo observado, dezenas de minutos so para a fase local). Por decisao explicita do usuario, troquei para um teste DIAGNOSTICO fora da campanha (nao e uma celula do experimentos.csv): mesma topologia 2x2x2/8 ranks/chuc-3+chuc-4, porem com problema menor (--size-x/y/z=596, absorption=2 -> particao local ~300^3, mensagem de gather ~200-500MB por campo por worker -- ainda old suficiente para nao cair em protocolo eager, mas com custo de escrita O(N^3) tratavel em minutos).
- **2026-07-14 02:47:15** — RESULTADO 10gbit (diagnostico N=596): gather COMPLETOU integralmente -- os 7 workers remotos foram recebidos e escritos sequencialmente (confirmado via grep do log "Received and wrote partition from worker N", contagem 0->1->2...->7) e o processo alcancou MPI_Finalize ("done. Results in ..."). Backtraces (gdb -p <pid> -batch -ex bt) tirados durante a espera SEMPRE mostraram os ranks em fseek()/dc_receive_and_write_results (Causa 2, escrita), NUNCA em MPI_Send/MPI_Recv bloqueado (Causa 1) -- ou seja, a rede nunca travou, so a escrita e que e inerentemente lenta (~30-50s por worker nesta escala menor).
- **2026-07-14 02:47:15** — RESULTADO 25gbit (diagnostico N=596, identico ao de 10gbit): mesmo resultado -- gather completou integralmente, 7/7 workers recebidos, processo chegou a MPI_Finalize, sem qualquer sinal de trava de rede em nenhum momento.
- **2026-07-14 02:47:15** — CONCLUSAO da caracterizacao por banda: a CAUSA 1 (deadlock do gather sob TCP-shaped) parece ESPECIFICA (ou ao menos MUITO mais severa) em 1gbit -- reproduzida de forma limpa e repetida nesta e na sessao anterior. Em 10gbit e 25gbit, o MESMO mecanismo de gather bloqueante NAO trava, para uma mensagem de ordem de grandeza ~200-500MB por worker. RESSALVA IMPORTANTE (nao totalmente resolvida): o teste diagnostico usou uma particao MENOR (~300^3, ~200-500MB/worker) do que a celula original que travou (N=1536, particao 772^3, ~1.8GB/worker) para viabilizar o teste em tempo habil -- ou seja, confirmamos que 10gbit/25gbit toleram gather de ~200-500MB, mas NAO testamos diretamente se 10gbit/25gbit tambem toleram o gather de ~1.8GB (N=1536) especificamente, que e o tamanho real de toda a faixa multi-no do experimentos.csv (772^3 e o MENOR caso multi-no da campanha; sobe ate ~1.48Mx744x744 em 8 nos). Extrapolar de 200-500MB->OK para 1.8GB->OK e plausivel dado que o gargalo parece ser relacionado a taxa de linha efetiva sob severo throttling (1gbit), nao a um limite fixo de tamanho de mensagem, mas isso e HIPOTESE, nao fato estabelecido para o tamanho real da celula N=1536.
- **2026-07-14 02:47:15** — AVALIACAO DA ESTRATEGIA DE MONITORAMENTO EXTERNO (GPU util + rx/tx bytes da interface kavlan) como canal de recuperacao para celulas onde o gather trava: viavel como recuperacao de ULTIMA INSTANCIA (quando Akypuera nao produz traco por o processo nunca alcancar MPI_Finalize), com resolucao temporal limitada ao intervalo de amostragem (~10-15s neste estudo, erro relativo tipicamente <15% sobre janelas de dezenas a centenas de segundos). NAO substitui o traco Akypuera para a metrica de masking effectiveness reportada no artigo (que exige granularidade por operacao MPI individual). Risco de confusao de fase identificado NA PRATICA nesta sessao: GPU a 0%% + rede parada pode significar tanto "gather travado" (Causa 1) quanto "escrevendo particao LOCAL do coordenador sem necessidade de rede" (Causa 2) -- distinguivel so cruzando com os logs da aplicacao (contagem de "Received and wrote partition from worker N"), nao pelas metricas externas isoladas.
- **2026-07-14 05:40:28** — TESTE REAL N=1536/np=8 SOB 10gbit (escala real do menor caso multi-no do CSV, particao 772^3, mensagem de gather ~1.8GB/worker): CONCLUIDO INTEGRALMENTE ate MPI_Finalize em ~1h55min (03:07:44 -> 05:02:46). Todos os 7 workers remotos recebidos e escritos, SEM qualquer stall de rede (nunca observado MPI_Send/MPI_Recv bloqueado em nenhum backtrace). Linha de performance real obtida: rank,total_time,msamples_per_s -- total_time por rank entre 37.2s e 47.5s, agregado global 7512.76 Msamples/s. Este e um PONTO DE DADO CIENTIFICO VALIDO (nao diagnostico) para a celula 10gbit_2n_8g_N1536.
- **2026-07-14 05:40:28** — TESTE REAL N=1536/np=8 SOB 25gbit (mesma escala real): confirmado que o PRIMEIRO worker remoto real (~1.8GB) foi recebido e escrito com sucesso (log Received and wrote partition from worker N, contagem=1) em ~28min de execucao, sem qualquer sinal de stall de rede em nenhum momento (rx_bytes sempre com atividade normal ou em fase de escrita local sem rede, nunca zero-persistente-com-processo-em-MPI_Send/Recv como ocorreu em 1gbit). Dado o aperto de walltime da alocacao (job 2167768 expira ~07:04, restavam ~1h40min neste ponto), decidido por orientacao explicita do usuario NAO esperar os 8 workers completos (que historicamente levam 2h+ de Finalization) -- o processo foi deixado rodando em segundo plano no cluster (nao foi morto), podendo completar sozinho dentro do walltime restante; se completar, o resultado sera coletado a posteriori, mas a pergunta cientifica (Causa 1 nao ocorre em 25gbit na escala real) ja esta respondida com o primeiro worker.
- **2026-07-14 05:40:28** — CONCLUSAO FINAL sobre o dominio de validade da campanha completa (experimentos_parametrizados_completo.csv, 105 linhas): (1) A CAUSA 1 (deadlock do gather bloqueante sob TCP-shaped) e ESPECIFICA da banda 1gbit -- confirmado empiricamente na ESCALA REAL (N=1536, ~1.8GB/worker, o MENOR caso multi-no e portanto o piso de mensagem de toda a faixa multi-no do CSV) que 10gbit e 25gbit NAO travam essa fase, com um ponto de dado completo (10gbit) e um ponto parcial mas decisivo (25gbit, 1o worker real confirmado). NAO ficou estabelecida uma nova fronteira de tamanho de mensagem alem da ja conhecida (1gbit falha, 10/25gbit toleram ate pelo menos 1.8GB) -- nao ha evidencia de degradacao adicional em mensagens maiores (linhas com ate ~3.2GB/worker no topo do CSV) alem do que ja se sabe: quanto MAIOR a mensagem, mais tempo o gather LEVA (mesmo sem travar), entao o risco pratico em N muito grande passa a ser mais о tempo total de execucao (Causa 2 dominando) do que um novo travamento de rede (Causa 1).
- **2026-07-14 05:40:28** — (2) A CAUSA 2 (escrita serial O(N) por voxel em coordinator.c) tem um modelo mecanistico validado e medido (~1.8us por par fseek+fwrite, independente de banda/no de nos) que PIORA, nao melhora, com mais maquinas nesta campanha especifica: como Dimensao_Local_Pior_Caso CRESCE junto com Num_Nos no CSV (772 em 2 nos ate 1476x744x744 em 8 nos) e a Finalization e estritamente SERIAL (um rank so, um worker por vez), o tempo total de Finalization escala com (numero de workers) x (voxels por worker), tornando linhas de N grande (especialmente >=6-8 nos) provavelmente inviaveis de completar em tempo habil de sessao/alocacao tipica, INDEPENDENTE da banda de rede. Isso e uma limitacao de INFRAESTRUTURA DE COLETA (Finalization), nao do algoritmo de propagacao medido nem do modelo SimGrid.
- **2026-07-14 05:40:28** — (3) EXPERIMENTOS QUE AINDA RESPONDEM A PERGUNTA CIENTIFICA (validade do modelo SimGrid vs. real): TODAS as linhas do CSV, pois a metrica medida (total_time/msamples_per_s, janela MPI_Irecv->MPI_Waitall) e calculada e impressa ANTES da Finalization comecar (main.c:183-186) e a Causa 1 nao afeta 10/25gbit em nenhuma escala testada. A UNICA limitacao real e OPERACIONAL: para linhas onde a Finalization sozinha levaria horas (N grande, muitos nos), o PROCESSO pode nao chegar a imprimir a linha rank,total_time,msamples_per_s dentro do tempo de alocacao disponivel, mesmo que a grandeza medida ja tenha sido calculada internamente (variavel total_time em main.c:186) -- ou seja, o DADO existe no processo em memoria, mas pode nunca ser IMPRESSO/COLETADO se o job expirar antes de MPI_Finalize. Isso e uma limitacao de COLETA (harness), a documentar nas Ameacas a Validade, nao um problema do algoritmo medido nem evidencia contra a hipotese central.
- **2026-07-14 06:27:08** — MAPA DE VIABILIDADE gerado em g5k/logs/finalization_feasibility_map.md (modelo T_final=Num_GPUs*interior_local*2*0.959us, calibrado no Teste 4). Coletabilidade por walltime/rep: 2h->13/35 configs (single-no todos + 2no N<=1536); 4h->19/35 (+2no ate 1856, 3no 1920); 6h->24/35 (+3no ate 2112, 4no 2240); 12h->33/35 (falta so 8 nos); 24h->35/35. DOIS MECANISMOS DISTINTOS de inviabilidade: (A) DEADLOCK gather 1gbit = 23 linhas multi-no 1gbit INVIAVEIS em qualquer walltime; (B) Finalization O(voxels) serial = 46 linhas multi-no 10/25gbit viaveis conforme walltime, piora com mais nos (1.9h@2no ate 13.6h@8no/rep). Single-no (36 linhas) sempre coletaveis (<=1.67h/rep), sem deadlock em nenhuma banda.
- **2026-07-14 06:42:36** — PLANO DE RESERVAS (codigo atual) + PROPOSTA de flag --benchmark/--skip-output registrados em g5k/logs/benchmark_flag_proposal.md. Resumo: codigo atual coleta 82/105 linhas em ~65 dias de walltime (23 linhas 1gbit multi-no INVIAVEIS por deadlock); proposta de pular gather+write (replicando o caminho #ifdef SIMGRID que a referencia calibrada JA usa) tornaria 105/105 coletaveis em ~1 dia. Metrica total_time (main.c:186) e janela masking (Irecv->Waitall) NAO mudam (gather roda depois, em main.c:187+). Habilitador: metrica so existe se alcancar MPI_Finalize (Akypuera flush), impossivel hoje p/ 1gbit-multino(deadlock) e N grande(walltime). DECISAO PENDENTE de auditoria critica + verificacao no compare_sim_real.R do clipping da janela. Nenhum codigo alterado ainda.
- **2026-07-14 06:43:58** — VERIFICACAO compare_sim_real.R:281-293: a metrica recorta a janela Irecv->Waitall E filtra so Irecv/Isend/Waitall -> o gather (Send/Recv, pos-Waitall) e excluido DUPLAMENTE. Confirma que modo benchmark daria metrica IDENTICA ao modo completo. Principal risco metodologico da proposta ELIMINADO.
- **2026-07-14 15:42:58** — PLANILHA de validacao por topologia gerada em g5k/logs/validation_set_topologies.csv. Com 512GB RAM na chuc, a referencia single-node OpenMP cabe em memoria para TODAS as 10 topologias (max N=2944 -> 408GB < 512GB) -> todas validaveis (limitacao de memoria da analise anterior REMOVIDA; resta o custo de compute da referencia). Estrategia: 1 execucao COMPLETA (com escrita) por topologia p/ integridade numerica (menor N/topologia, 10gbit, banda-independente) + 4 reps SEM escrita (benchmark) por linha. Custos: validacao 10 full runs = 74.6h (dominado pelas 5 grandes); 4 reps benchmark x105 linhas = 21h; HIBRIDA total ~95.6h (~4 dias) vs (A) 5x full ~1561h+23 deadlock vs (B) 5x benchmark ~26h sem validacao.
- **2026-07-14 16:02:15** — AUDITORIA DE CONFIABILIDADE OPERACIONAL (pre-automacao). VALIDADO empiricamente: build cuda+akypuera (4bd74bb); pipeline deploy 01-04; MPI+CUDA real np=8 em 2 nos (fix pml_ucx_tls); deadlock 1gbit-multino; finalization lenta. NAO validado (hipotese): np>=12 (mapeamento MPI_Dims_create p/ 12/16/20/24/27/30/32 nunca rodado); alocacao de 4-8 nos (max empirico=3); VRAM >20.6GB (nunca rodado acima de N=1536); homogeneidade de nos nunca usados (chuc-1,2,5); saude de GPU (censo pega contagem, nao ECC). CONHECIDO: chuc-7 tem 3 GPUs (quebra suposicao 4/no). ACHADO CRITICO DE VRAM: 4 topologias (2x3x4/N2624=34.49GB, 3x3x3/N2752=35.5, 2x3x5/N2880=36.49, 2x4x4/N2944=36.52) NAO tem nenhum N sob o orcamento seguro (34GB=40x0.85) -> csv_vram_ok as pularia inteiras. Sao tambem as topologias de 6-8 nos (raramente alocaveis). Topo da campanha bloqueado por 3 eixos: VRAM + disponibilidade de nos + tempo de finalization.
- **2026-07-14 16:02:15** — DECISAO: estrategia incremental de confiabilidade antes de aumentar automacao. Ordem: (1) watchdog/timeout + limpeza de orfaos + politica de recuperacao; (2) flag --skip-output (validar que nao muda a janela medida/comparabilidade SimGrid); (3) teste empirico de VRAM das 4 topologias grandes (nao assumir inviaveis sem medir); (4) so entao estender o orquestrador existente (scripts/02-orchestrator.sh, que JA faz checkpoint/resume/adapta a nos disponiveis) com full/benchmark + consciencia de walltime. Nao automatizar antes de (1): sem watchdog, o orquestrador penduraria na 1a linha 1gbit-multino (deadlock) e queimaria a alocacao com orfaos (incidente ja vivido). Nenhum codigo alterado; planejamento/auditoria em curso.

---
## 2026-07-14 (cont.) -- Passos 4 e 5 registrados (DESIGN, nada implementado)

PASSO 4 (VRAM): backend CUDA aloca 6 arrays de device (nao ~11 do CSV) ->
device_data.cu 6 cudaMalloc + cuda_propagate.cu 0. VRAM real ~= 6*local*4 B
+ ~0.5GB contexto; coluna do CSV ~1.86x conservadora. TODAS as 105 linhas
cabem em 40GB (max real ~20.4 GB). As 4 "infactiveis" (N2624..2944) ficam
~18.5-19.6 GB. csv_vram_ok mal-calibrado -> falsos negativos. [DOC]-solido,
[EMP]-PENDENTE (job 2167768 expirou; smoke test: nvidia-smi memory.used
~11GB em N1536). Detalhe em campaign_infrastructure_design.md secao 4.

PASSO 5 (orquestrador): design da extensao registrado (secao 5). Pontos:
- DESCOBERTA [DOC]: .dc e independente da banda (unica coletiva = MPI_Allgather
  de hostnames em setup.c:33; caminho de calculo so ponto-a-ponto). => proposta
  REFINADA: 35 full NATIVOS (1/topologia) + bench por (topo x banda). Remove o
  deadlock por construcao e 70 .dc redundantes. MUDA a estrutura aprovada
  "1 full + 4 bench por celula" -> REQUER AVAL do usuario + smoke test
  (checksum .dc nativo vs shaped).
- Constraint novo [EMP]: .dc de N1536 = 28.99 GB; N2944 ~204 GB; /home NFS so
  2.3T livres, /tmp 16G. => retencao validar-e-descartar + preflight de disco.
- run_type (full/bench) como 6a coluna do progress.csv (legado->full);
  integridade full exige .dc, bench proibe .dc.
- estados persistidos so terminais (done/failed/timeout/oom/failed_permanent);
  skipped_vram/skipped_deadlock/deferred NAO persistidos (recomputados) para
  nao congelar decisoes superadas (ex passo 4).
- inflight.txt + varredura de orfaos ([.]/bin/dc) para resume; lock por PID.
- walltime via oarstat; gate defer se nao couber; timeout coreutils (camada 1)
  + liveness watchdog (camada 2, fase 2).
- flag --phase full|bench|all para largura-vs-profundidade sem escalonador.

DEPENDENCIA ABERTA: ground_truth por topologia usado por CompareResults.R.

PROXIMO: aguardando aval do usuario em (a) estrutura REFINADA e (b) ground_truth,
antes da auditoria sistemica final e da implementacao.

[2026-07-14T16:39:37+02:00] REFINADA adotada (usuario). Auditoria sistemica final registrada (secao 6): 3 lacunas (sonda de shaping, re-censo de nos on-failure, orcamento disco/trace+buffer aky), 1 dependencia externa (ground_truth), H1-H4 fecham nos smoke tests #1-4 da 1a reserva. Aguardando: aval das 3 lacunas + ground_truth antes de implementar.

---
## 2026-07-14 (cont. 2) -- Consolidação completa do espaço experimental (CSV + análise crítica), antes de qualquer implementação

[2026-07-14T20:55:48+02:00] Por pedido explícito do usuário, pausada a discussão
das pendências (3 lacunas de design + ground_truth) para primeiro consolidar
TODO o espaço experimental: as 105 linhas de  cruzadas com
tudo que já foi de fato executado (checkpoint oficial, resultados ad hoc/
diagnósticos, tamanhos em disco reais, walltime OAR real). Gerados:
 (105 linhas x 23 colunas) e
 (análise crítica por
configuração/topologia + revisão metodológica à luz do objetivo central).

ACHADOS NOVOS desta consolidação (além do que já estava registrado):
1. Recalculado independentemente (script próprio) o modelo T_final para as
   35 configurações -- bate exatamente com finalization_feasibility_map.md
   (segunda confirmação do modelo, não repetição cega).
2. Teste t5 (25gbit, N=1536, real) que o diário de 05:40 registrava como
   só o 1o worker confirmado na verdade TERMINOU sozinho os 8 workers
   (dc.output confirma: 7728.13 Msamples/s agregado, MPI_Finalize alcançado).
   Diário anterior estava desatualizado nesse ponto.
3.  NÃO EXISTE no diretório (só predicted*.dc).
    usa interface de CLI posicional antiga
   ( ...  ./predicted.dc), INCOMPATÍVEL com o
   main.c atual (argp com --size-x etc.). A dependência externa a

---
## 2026-07-14 (cont. 2) -- Consolidação completa do espaço experimental (CSV + análise crítica), antes de qualquer implementação

[2026-07-14T20:55:48+02:00] Por pedido explícito do usuário, pausada a discussão
das pendências (3 lacunas de design + ground_truth) para primeiro consolidar
TODO o espaço experimental: as 105 linhas de experimentos.csv cruzadas com
tudo que já foi de fato executado (checkpoint oficial, resultados ad hoc/
diagnósticos, tamanhos em disco reais, walltime OAR real). Gerados:
g5k/logs/consolidated_campaign_matrix.csv (105 linhas x 23 colunas) e
g5k/logs/consolidated_campaign_analysis.md (análise crítica por
configuração/topologia + revisão metodológica à luz do objetivo central).

ACHADOS NOVOS desta consolidação (além do que já estava registrado):
1. Recalculado independentemente (script próprio) o modelo T_final para as
   35 configurações -- bate exatamente com finalization_feasibility_map.md
   (segunda confirmação do modelo, não repetição cega).
2. Teste t5 (25gbit, N=1536, real) que o diário de 05:40 registrava como
   "só o 1o worker confirmado" na verdade TERMINOU sozinho os 8 workers
   (dc.output confirma: 7728.13 Msamples/s agregado, MPI_Finalize alcançado).
   Diário anterior estava desatualizado nesse ponto.
3. validation/ground_truth.dc NÃO EXISTE no diretório (só predicted*.dc).
   validation/validate.sh usa interface de CLI posicional antiga
   (CUBE_SIZE_X ... STENCIL_SIZE ./predicted.dc, argumentos posicionais),
   INCOMPATÍVEL com o main.c atual (argp com --size-x etc.). A "dependência
   externa a esclarecer" (ground_truth) é na verdade um script quebrado a
   consertar, não só uma decisão pendente.
4. Verificada no código (não aceita de graça) a afirmação de
   validation_set_topologies.csv sobre 3x3x3 ter "26 vizinhos diagonais":
   CONFIRMADA -- include/definitions.h linha 5 define NEIGHBOURHOOD=27, e
   worker.c faz troca de halo em vizinhança de Moore completa (27 direções
   dx,dy,dz em {-1,0,1}, não só as 6 faces).
5. predicted_1gbit_2n_8g_N1536_rep1.dc e rep2.dc (do incidente de 10/07) são
   sparse files: tamanho aparente 27GB mas uso real em disco 4.7GB (rep1) e
   9.1GB (rep2) -- confirma escrita truncada pelos kills, consistente com o
   diagnóstico já registrado.
6. Apenas 1/105 linhas do CSV oficial tem execução 100% completa via
   orquestrador (1gbit_1n_4g_N64, 5/5 reps); 1/105 tem tentativa oficial
   falhada registrada (1gbit_2n_8g_N1536); 101/105 (96%) nunca foram
   executadas em nenhuma forma. Os testes t1-t5/diagnósticos de 14/07 são
   TODOS fora do checkpoint oficial (ad hoc, não custam linha do CSV).
7. Ambas as sessões de alocação já realizadas (jobs 2165368 e 2167768)
   consumiram 100% do walltime concedido -- nenhuma terminou por decisão,
   ambas por expiração da reserva.

DECISÃO: nenhuma implementação (flag --skip-output, orquestrador, etc.) será
discutida antes de revisitar as pendências anteriores à luz desta
consolidação. Próximo passo: retomar as pendências (3 lacunas + ground_truth)
uma a uma, agora informadas por este mapeamento completo.

[2026-07-15T01:19:08+02:00] Investigacao do ground_truth concluida (reconstrucao por evidencia, secao 5.1-bis). Achado central: DUAS narrativas conflitantes no historico git -- (1) unico script commitado (run-dc-comparison, ec89290..e5f0152, jan-fev/2026) testava so autoconsistencia np1-vs-npN do PROPRIO codigo, so N=64, tolerancia 0(OpenMP)/1e-3(CUDA); deletado sem sucessor; (2) tese (05/2026) descreve SHA-256 vs fletcher-base (repo EXTERNO github.com/gabrielfrtg/fletcher-base, empacotado em fletcher-base.nix mas NUNCA invocado por nenhum script commitado), tamanhos ate 512^3, tolerancia 1e-15 -- nenhuma prova commitada de que essa segunda validacao realmente ocorreu como descrito. NENHUMA das duas cobre a escala da campanha (menor topologia = N1536; validacoes historicas nunca passaram de 512^3). Calculo novo: ground truth via np=1 (qualquer backend, proprio codigo OU fletcher-base) e IMPOSSIVEL em CUDA para qualquer topologia da campanha (N1536 precisa 87GB VRAM > 40GB); em OpenMP/RAM-host so a menor topologia (N1536, ~290GB de 512GB) caberia, nenhuma maior. Aguardando decisao do usuario entre 3 caminhos (A: ressuscitar autoconsistencia adaptada, alcance limitado a N~1123-1759; B: buscar fletcher-base externo, mesma limitacao fisica, trabalho novo nao testado; C: aceitar limitacao estrutural e declarar como ameaca a validade -- numerico independente so na(s) menor(es) topologia(s), demais so com reprodutibilidade/determinismo).

[2026-07-15T01:23:03+02:00] Decisao: Caminho C (aceitar limitacao estrutural do ground truth). Fase full passa a ter 2 papeis: N=1536 ganha 1 run np=1 OpenMP extra como ground truth real (unico ponto da campanha com validacao fisica independente); as demais 34 topologias tem full sem ground truth possivel (limite VRAM/RAM np=1), evidencia numerica = reprodutibilidade determinista entre reps. checkpoint precisa de metadado tem_ground_truth para nao confundir as duas evidencias no relatorio final. Ameaca a validade correspondente redigida (rascunho) para a metodologia da tese. H2 da auditoria sistemica (secao 6) fechado. Pendente antes de implementar: as 3 lacunas da secao 6.5 (sonda de shaping, re-censo de nos, orcamento disco/trace+buffer aky) ainda precisam de design detalhado.

---
## 2026-07-14 (cont.) -- Premissa final da campanha fixada + 3 lacunas desenhadas (DESIGN, nada implementado)

PREMISSA FIXADA (usuario): 1 full por TOPOLOGIA MPI (nao por linha do CSV),
sempre no menor N daquela decomposicao; demais N/bandas/reps da mesma
topologia rodam em benchmark (--skip-output). Reconstrucao do CSV real
(g5k/csv/experimentos.csv) mostrou 10 topologias distintas (nao 35
independentes) numa varredura de weak-scaling. Numeros recalculados:
  FULL: 10 execucoes (nao 35/105). NATIVE, sem shaping.
  BENCH: 105 linhas x 5 reps = 525 execucoes, shaped, skip-output.
Ground truth (np=1) so cabe em 2 das 10 topologias: 1x2x2/N64 (CUDA+OpenMP,
trivial) e 2x2x2/N1536 (so OpenMP/RAM, 290 de 512GB). As outras 8
topologias-representante (N1920..2944): full roda mas sem ground truth
possivel (limite fisico VRAM/RAM np=1, formula N^3x6x4B CUDA / N^3x20x4B
OpenMP) -- evidencia numerica = reprodutibilidade entre reps (Caminho C,
ja aceito). Planilha g5k/logs/validation_set_topologies_v2.csv registra os
10 representantes com dc_gb e metodo_ground_truth exatos.

LACUNA 1 (sonda de banda efetiva): validate_bandwidth_effective() via
iperf3 bind na interface kavlan, chamada de validate_before_batch antes de
cada lote de banda (3x/campanha). Fecha SPOF-4 (shaping que vaza sem erro
visivel). Residual [HIP] aceito: iperf3 mede fluxo sustentado, halo real e
rajadas pequenas -- tbf e interface-wide (shape.sh usa root/tbf, nao
htb/per-fluxo) entao a equivalencia vale ENQUANTO o mecanismo nao mudar.

LACUNA 2 (re-censo de nos on-failure): nodes_liveness_probe() reativa
(dispara so em retry/falha de conectividade, nao periodica), grava
state/nodes_alive.txt; nodes() em core.sh passa a preferir esse arquivo
(fallback NODES_FILE original, preservado para auditoria). node_count/
head_node/csv_build_experiment_hostfile ja derivam de nodes() -- unica
mudanca estrutural necessaria. Fecha O1 (no morto no meio da campanha nao
trava mais as linhas menores).

LACUNA 3 (disco/trace + buffer Akypuera) -- REVISADA PARA BAIXO com
evidencia nova: iterations=ceil(1e-4/1e-6)=100 fixo (independente de N);
rastro-*.rst reais (N64/np4) ~65KB/rank -- Akypuera grava metadado de
evento, nao payload, entao trace NAO escala com N^3. RST_BUFFER_SIZE=1GB
tem ~16.000x de margem por rank. Traces do bench inteiro (525 runs):
~415MB estimado, desprezivel. O RISCO REAL sao os .dc dos 10 full (0 a
204.13GB, formula N^3*2*4 bytes de coordinator.c, EMP-validada contra o
predicted_..._N1536.dc real=28.99GB). Design: csv_expected_dc_bytes(N) +
validate_disk_space_for_full(N) com margem 10%, chamada antes de CADA full
(nao antes do bench, cujo footprit e desprezivel) -- fecha risco de ENOSPC
no meio da escrita (que pareceria hang).

STATUS: planejamento da infraestrutura de campanha esta COMPLETO em nivel
de design/auditoria (secao 10 do doc). Nenhuma decisao metodologica em
aberto. Falta so implementacao + smoke tests da 1a reserva (secao 6.4,
nenhum bloqueia o inicio da implementacao).
- **2026-07-15 03:29:35** — Orquestrador iniciado. 8 nós disponíveis, 105/105 linhas compatíveis. phase=full dry_run=1 only_id=<todos>
- **2026-07-15 03:29:36** — Execução do orquestrador finalizada (fase=full): OK=0 FAILED=0 SKIPPED_DONE=0 SKIPPED_VRAM=0 SKIPPED_DEFER=0
- **2026-07-15 03:30:00** — Orquestrador iniciado. 8 nós disponíveis, 105/105 linhas compatíveis. phase=bench dry_run=1 only_id=bench_1gbit_2n_8g_N1536
- **2026-07-15 03:30:00** — Execução do orquestrador finalizada (fase=bench): OK=0 FAILED=0 SKIPPED_DONE=0 SKIPPED_VRAM=0 SKIPPED_DEFER=0
- **2026-07-15 03:30:38** — Orquestrador iniciado. 3 nós disponíveis, 66/105 linhas compatíveis. phase=full dry_run=1 only_id=full_1x2x2_N64
- **2026-07-15 03:30:38** — Execução do orquestrador finalizada (fase=full): OK=0 FAILED=0 SKIPPED_DONE=0 SKIPPED_VRAM=0 SKIPPED_DEFER=0

---
## 2026-07-15 -- Implementacao da infraestrutura de campanha CONCLUIDA (design ja fechado nas sessoes anteriores)

Todas as 7 etapas planejadas foram implementadas e testadas (sem hardware
chuc real -- reserva de 3 CHUCs agendada para 2026-07-15 19:05, job
2168438). Resumo por etapa (arquivos + testes):

1. --skip-output no binario dc: include/coordinator.h (+skip_output),
   src/main.c (+opcao argp -b, ARGP_KEY_END relaxado, guarda em torno do
   gather+escrita). Testado (build OpenMP real, 3 cenarios: erro sem
   output-file, roda sem .dc com --skip-output, regressao com .dc gerado
   normalmente e tamanho exato = formula N^3*2*4).

2. csv.sh: csv_topology_representatives(), csv_is_topology_representative(),
   csv_expected_dc_bytes(), csv_ground_truth_backends() (formula generica,
   nao tabela fixa). defaults.conf: DC_OUTPUT_FIELDS/DC_FLOAT_BYTES,
   DC_NP1_CUDA_ARRAYS/DC_NP1_OPENMP_ARRAYS/HOST_RAM_GB/RAM_SAFETY_MARGIN.
   Testado: todos os 10 representantes corretos, formula de bytes exata
   contra 2 arquivos reais, ground_truth_backends bate com a tabela do
   design (64->cuda+openmp, 1536->openmp, demais->vazio).

3. checkpoint.sh: schema 6a coluna run_type (legado->full), 
   checkpoint_last_run_type, checkpoint_mark exige run_type, 
   checkpoint_integrity_ok estendido (full: .dc exato OU marcador
   .discarded; bench: proibe .dc; veredito de ground truth opcional),
   checkpoint_should_run detecta mismatch de run_type. Testado: 9 casos.

4. validate.sh: validate_disk_space_for_full (NAO usa die(), retorna 1
   para o chamador tratar como DEFER -- diferente do resto do arquivo, de
   proposito), validate_bandwidth_effective (iperf3+jq, integrado a
   validate_before_batch). Testado: 4 mocks incluindo o cenario de
   vazamento de shaping (aborta corretamente).

5. lib/resilience.sh (novo arquivo): nodes_liveness_probe (reativa,
   paralela, timeout curto), orphan_cleanup ([.]/bin/dc, nao substring),
   inflight_mark/clear/resume. core.sh: nodes() prefere nodes_alive.txt.
   Testado: preferencia de nodes(), paralelismo real (5s p/ 5 nos mortos,
   nao 25-35s), recriacao do bug historico ./bin/dc vs sbin/dcgm, ciclo
   completo de inflight.

6. run.sh: RUN_TIMEOUT_S opcional (timeout --signal=TERM --kill-after=30
   envolvendo TODO o nix develop, nao so o mpirun interno). core.sh:
   oar_walltime_remaining_s (convencao OAR_JOB_ID exportado manualmente,
   igual a deploy.sh). Testado CONTRA JOB REAL (chifflot-4, 2168649): 175min
   restantes bateu com o esperado (~176min). Timeout testado (rc=124) e
   renderizacao do heredoc confirmada.

7. scripts/02-orchestrator.sh: reescrito -- --phase full|bench|all, lock
   por PID, fase full (10 execucoes via csv_topology_representatives,
   nativo, run_ground_truth_check onde aplicavel), fase bench (105 linhas
   x 5 reps, shaped, --skip-output), handle_run_failure, gates de
   disco/walltime, inflight_resume no startup. validation/CompareResults.R:
   ACHADO REAL -- pacote R 'here' nao instalado neste ambiente (script
   quebraria na primeira linha); removido here+digest (digest nunca foi
   usado -- vestigio de versao anterior, reforca o achado da investigacao
   de ground truth), parametrizado paths de entrada, adicionados codigos
   de saida (0/1/2). 100% compativel com invocacao legada.
   Testado: dry-run fase full (10 representantes corretos com anotacoes
   de ground truth exatas), dry-run fase bench com --only-id, lock (PID
   morto removido, PID vivo recusado), CompareResults.R (6 casos
   sinteticos), Makefile BUILDDIR=bin_openmp_gt isola build sem tocar
   bin/dc (confirmado).

8. Verificacao final: bash -n limpo em todos os arquivos alterados
   (shellcheck indisponivel neste ambiente -- nem instalado nem via nix,
   que tambem nao esta no PATH do frontend).

INCIDENTE: job interativo da chifflot-4 (2168649) terminou inesperadamente
(estado -> Terminated) durante um teste pesado (comparacao real de 2
arquivos .dc de 29GB via R) -- conexao SSH caiu, job morreu antes do
walltime de 4h esgotar. Sem acesso a chifflot-4 desde entao. Decisao do
usuario: prosseguir sem nova alocacao; o teste com dados .dc reais em
escala fica para os smoke tests da reserva de chuc (19:05), que ja
gerariam esses dados de qualquer forma.

ESTADO: infraestrutura de campanha 100% implementada conforme o design
fechado nas sessoes anteriores. Nenhuma decisao metodologica alterada
durante a implementacao. Unico ajuste tecnico descoberto e corrigido:
dependencias R ausentes em CompareResults.R (nao e mudanca de metodologia,
so remocao de imports desnecessarios/quebrados). Pronta para os smoke
tests da secao 6.4 quando a reserva de 3 CHUCs iniciar (2026-07-15 19:05).
- **2026-07-15 20:23:24** — Deploy iniciado em 3 nós: chuc-3.lille.grid5000.fr,chuc-4.lille.grid5000.fr chuc-8.lille.grid5000.fr (env=debiannvopen11-big)
- **2026-07-15 20:27:39** — Deploy concluído. IPs kavlan: chuc-3.lille.grid5000.fr 10.8.9.103/18,chuc-4.lille.grid5000.fr 10.8.9.104/18 chuc-8.lille.grid5000.fr 10.8.9.108/18
- **2026-07-15 20:38:26** — Setup concluído. Censo de GPU: chuc-3.lille.grid5000.fr 3,chuc-4.lille.grid5000.fr 4 chuc-8.lille.grid5000.fr 4
- **2026-07-15 20:41:48** — Build OK (BACKEND=cuda PROFILE=akypuera ARCH=sm_80), commit=4bd74bb
- **2026-07-15 20:42:31** — GPU divergente em chuc-3.lille.grid5000.fr: esperado 4, encontrado 3. Linhas cuja distribuição uniforme exigir mais que 3 neste nó serão adiadas (csv_row_fits_gpu_capacity), não executadas incorretamente.
- **2026-07-15 20:42:37** — Pre-flight de campanha: OK. sha256(bin/dc)=4e378ac41f6be908e19688913991130ad4a24858828fad0571224bd87ba96da4
- **2026-07-15 20:43:17** — Orquestrador iniciado. 3 nós disponíveis, 66/105 linhas compatíveis. phase=full dry_run=1 only_id=<todos>
- **2026-07-15 20:43:17** — FULL full_2x2x3_N1920 adiado: capacidade real de GPU insuficiente em algum nó para a distribuição uniforme desta topologia.
- **2026-07-15 20:43:17** — Execução do orquestrador finalizada (fase=full): OK=0 FAILED=0 SKIPPED_DONE=0 SKIPPED_VRAM=0 SKIPPED_DEFER=8
- **2026-07-15 20:44:11** — GPU divergente em chuc-3.lille.grid5000.fr: esperado 4, encontrado 3. Linhas cuja distribuição uniforme exigir mais que 3 neste nó serão adiadas (csv_row_fits_gpu_capacity), não executadas incorretamente.
- **2026-07-15 20:44:16** — Pre-flight de campanha: OK. sha256(bin/dc)=4e378ac41f6be908e19688913991130ad4a24858828fad0571224bd87ba96da4
- **2026-07-15 20:44:16** — Orquestrador iniciado. 3 nós disponíveis, 66/105 linhas compatíveis. phase=full dry_run=0 only_id=<todos>
- **2026-07-15 20:44:45** — Ground truth 1x2x2/N=64: Min: -0.00924004521220922
Max: 2.42815985984635e-05
Standard deviation: 2.74030118639778e-05
✅ Validation successful! The files are numerically similar within a tolerance of 0.001. 
- **2026-07-15 20:44:46** — Experimento full_1x2x2_N64 rep1 -> failed (10s)
- **2026-07-15 20:44:52** — Execução do orquestrador finalizada (fase=full): OK=0 FAILED=1 SKIPPED_DONE=0 SKIPPED_VRAM=0 SKIPPED_DEFER=0
- **2026-07-15 20:48:27** — GPU divergente em chuc-3.lille.grid5000.fr: esperado 4, encontrado 3. Linhas cuja distribuição uniforme exigir mais que 3 neste nó serão adiadas (csv_row_fits_gpu_capacity), não executadas incorretamente.
- **2026-07-15 20:48:32** — Pre-flight de campanha: OK. sha256(bin/dc)=4e378ac41f6be908e19688913991130ad4a24858828fad0571224bd87ba96da4
- **2026-07-15 20:48:32** — Orquestrador iniciado. 3 nós disponíveis, 66/105 linhas compatíveis. phase=full dry_run=0 only_id=<todos>
- **2026-07-15 20:49:00** — Ground truth 1x2x2/N=64: Min: -0.00924004521220922
Max: 2.42815985984635e-05
Standard deviation: 2.74030118639778e-05
✅ Validation successful! The files are numerically similar within a tolerance of 0.001. 
- **2026-07-15 20:49:00** — Experimento full_1x2x2_N64 rep1 -> done (11s)
- **2026-07-15 20:49:00** — Execução do orquestrador finalizada (fase=full): OK=1 FAILED=0 SKIPPED_DONE=0 SKIPPED_VRAM=0 SKIPPED_DEFER=0
- **2026-07-15 20:51:35** — GPU divergente em chuc-3.lille.grid5000.fr: esperado 4, encontrado 3. Linhas cuja distribuição uniforme exigir mais que 3 neste nó serão adiadas (csv_row_fits_gpu_capacity), não executadas incorretamente.
- **2026-07-15 20:51:40** — Pre-flight de campanha: OK. sha256(bin/dc)=4e378ac41f6be908e19688913991130ad4a24858828fad0571224bd87ba96da4
- **2026-07-15 20:51:40** — Orquestrador iniciado. 3 nós disponíveis, 66/105 linhas compatíveis. phase=full dry_run=0 only_id=<todos>
- **2026-07-17 15:28:32** — Deploy iniciado em 3 nós: chuc-3.lille.grid5000.fr,chuc-4.lille.grid5000.fr chuc-8.lille.grid5000.fr (env=debiannvopen11-big)
- **2026-07-17 15:32:48** — Deploy concluído. IPs kavlan: chuc-3.lille.grid5000.fr 10.8.9.103/18,chuc-4.lille.grid5000.fr 10.8.9.104/18 chuc-8.lille.grid5000.fr 10.8.9.108/18
- **2026-07-17 15:59:34** — Setup concluído. Censo de GPU: chuc-3.lille.grid5000.fr 4,chuc-4.lille.grid5000.fr 4 chuc-8.lille.grid5000.fr 4
- **2026-07-17 15:59:39** — Build OK (BACKEND=cuda PROFILE=akypuera ARCH=sm_80), commit=4bd74bb
- **2026-07-17 15:59:46** — Pre-flight de campanha: OK. sha256(bin/dc)=20ed4ef9f81e2b5ccc2c72901d8222ea1e12134d702ea93989379fa40c5a8c70
- **2026-07-17 15:59:47** — Versões de toolchain capturadas em /home/aandrade/ic/io-research/distributed-cube-average/g5k/logs/versions.txt
- **2026-07-17 15:59:47** — Nova alocacao job 2169626 (chuc-3/4/8): deploy+setup+build+preflight OK.
- **2026-07-17 16:00:15** — Orquestrador anterior interrompido em full_2x2x2_N1536 rep1 (full). Reconciliado: órfãos varridos, marcado failed para retentativa.
- **2026-07-17 16:00:15** — Orquestrador iniciado. 3 nós disponíveis, 66/105 linhas compatíveis. phase=bench dry_run=1 only_id=bench_1gbit_2n_8g_N1536
- **2026-07-17 16:00:15** — Execução do orquestrador finalizada (fase=bench): OK=0 FAILED=0 SKIPPED_DONE=0 SKIPPED_VRAM=0 SKIPPED_DEFER=0
- **2026-07-17 16:00:50** — Pre-flight de campanha: OK. sha256(bin/dc)=20ed4ef9f81e2b5ccc2c72901d8222ea1e12134d702ea93989379fa40c5a8c70
- **2026-07-17 16:00:50** — Orquestrador iniciado. 3 nós disponíveis, 66/105 linhas compatíveis. phase=bench dry_run=0 only_id=bench_1gbit_2n_8g_N1536
- **2026-07-17 16:01:58** — ACHADO: LACUNA 1 (validate_bandwidth_effective via iperf3) bloqueou o 1o batch de banda -- iperf3 ausente na imagem debiannvopen11-big (confirma a incerteza [HIP nao confirmado] do design doc secao 7). jq ja estava presente. iperf3 instalado via apt-get nos 3 nos (chuc-3/4/8) -- rede de deploy tem acesso a internet, instalacao rapida (<10s/no). NAO e mudanca de codigo/metodologia, so dependencia de SO ausente na imagem publica do G5K; registrar em 01-bootstrap.sh como TODO para instalar automaticamente em deploys futuros (nao feito agora por falta de tempo, instalacao manual documentada aqui é suficiente para esta sessao).
- **2026-07-17 16:02:37** — GAP DE DESIGN observado: validate_bandwidth_effective (chamada de validate_before_batch, DENTRO do loop de banda, APOS shape_apply) usa die() ao falhar -- isso mata o processo sem shape_off, deixando shaping residual que bloqueia o proximo preflight nativo (mesma classe do bug ja corrigido em deploy_run em 10/07). Corrigido manualmente (shape_off) para prosseguir. NAO corrigido no codigo nesta sessao por falta de tempo -- registrar como TODO: validate_before_batch/validate_bandwidth_effective deveriam limpar shaping antes de die(), ou o orquestrador deveria ter um trap EXIT que chama shape_off sempre.
- **2026-07-17 16:02:49** — Pre-flight de campanha: OK. sha256(bin/dc)=20ed4ef9f81e2b5ccc2c72901d8222ea1e12134d702ea93989379fa40c5a8c70
- **2026-07-17 16:02:49** — Orquestrador iniciado. 3 nós disponíveis, 66/105 linhas compatíveis. phase=bench dry_run=0 only_id=bench_1gbit_2n_8g_N1536
- **2026-07-17 16:04:21** — Pre-flight de campanha: OK. sha256(bin/dc)=20ed4ef9f81e2b5ccc2c72901d8222ea1e12134d702ea93989379fa40c5a8c70
- **2026-07-17 16:04:21** — Orquestrador iniciado. 3 nós disponíveis, 66/105 linhas compatíveis. phase=bench dry_run=0 only_id=bench_1gbit_2n_8g_N1536
- **2026-07-17 16:07:20** — CAUSA REAL do bloqueio em validate_bandwidth_effective (nao era flakiness de SSH, nem iperf3 ausente): pkill -f 'iperf3 -s' AUTO-MATCH na propria linha de comando remota que o invoca via ssh_root (o comando 'pkill -f 'iperf3 -s'' contem literalmente a substring 'iperf3 -s' no proprio argumento entre aspas) -- pkill mata o shell que o executa, derrubando a sessao SSH com rc=255, sem output. Reproduzido isoladamente 9/9 vezes com o padrao sem colchetes; 0/0 falhas apos o fix. MESMA CLASSE de bug ja documentada uma vez em lib/resilience.sh (orphan_cleanup, '[.]/bin/dc' vs 'sbin/dcgm') mas nao aplicada quando validate_bandwidth_effective foi escrita em 15/07 (essa funcao so tinha sido testada com mocks, nunca em hardware real ate hoje). CORRIGIDO: lib/validate.sh linha ~219, pkill -f '[i]perf3 -s'. Ao auditar todo o codebase por esse padrao (grep 'pkill -f|pgrep -f'), encontrado um SEGUNDO caso latente (nao fatal, mas silenciosamente incorreto): lib/deploy.sh linha 33, 'pgrep -f dhclient.*$KAVLAN_IFACE' -- mesma auto-correspondencia, faz o idempotency-check sempre retornar 'ja rodando' mesmo quando dhclient NAO esta rodando, entao o fallback '|| dhclient $KAVLAN_IFACE' nunca dispararia num no que genuinamente precisasse. Mascarado ate agora porque dhclient sempre esteve de fato rodando em todas as sessoes anteriores (a verificacao de IPv4 subsequente ainda pegaria a falha real como erro duro, so nao se auto-curaria). CORRIGIDO: lib/deploy.sh linha 33, pgrep -f '[d]hclient.*$KAVLAN_IFACE'. Ambos os fixes validados isoladamente em chuc-4 (match correto + nao-match correto). Tambem instalado iperf3+confirmado jq via apt nos 3 nos (ausentes na imagem debiannvopen11-big) -- ver entrada anterior.
- **2026-07-17 16:07:40** — Pre-flight de campanha: OK. sha256(bin/dc)=20ed4ef9f81e2b5ccc2c72901d8222ea1e12134d702ea93989379fa40c5a8c70
- **2026-07-17 16:07:40** — Orquestrador iniciado. 3 nós disponíveis, 66/105 linhas compatíveis. phase=bench dry_run=0 only_id=bench_1gbit_2n_8g_N1536
- **2026-07-17 16:10:32** — Correcao refinada apos novo teste: o bug de auto-match do pkill em validate_bandwidth_effective tinha DUAS camadas, nao uma. Colchetar '[i]perf3 -s' resolveu a auto-referencia direta, mas pkill e o lancamento do iperf3 continuavam na MESMA linha de comando via ssh_root (';'-separado) -- pkill -f, ao varrer TODA a linha de comando do processo bash que o executa, ainda encontrava a ocorrencia LITERAL (sem colchetes) de 'iperf3 -s' na segunda metade da MESMA linha (o proprio lancamento). Reproduzido 5/5 falhas mesmo colchetado quando combinado numa linha; 0/3 sucessos ao separar pkill e o lancamento em duas chamadas ssh_root distintas. Adicional: 'setsid' antes de 'iperf3 -D' -- sem isso, o daemon recebia HUP da propria sessao SSH fechando antes de se desvincular (visivel no proprio log do iperf3: 'interrupt - the server has terminated'). Fix final (lib/validate.sh): 2 ssh_root separados + setsid + redirecionamento explicito de stdin/stdout/stderr. VALIDADO isoladamente: validate_bandwidth_effective(1gbit) mediu 0.94Gbit/s real (razao 0.944) entre chuc-3<->chuc-4 sob shaping tbf 1gbit -- primeira confirmacao empirica real de que o shaping tbf esta genuinamente efetivo neste hardware (LACUNA 1 do design doc agora fechada com evidencia real, nao so mock).
- **2026-07-17 16:10:44** — Pre-flight de campanha: OK. sha256(bin/dc)=20ed4ef9f81e2b5ccc2c72901d8222ea1e12134d702ea93989379fa40c5a8c70
- **2026-07-17 16:10:44** — Orquestrador iniciado. 3 nós disponíveis, 66/105 linhas compatíveis. phase=bench dry_run=0 only_id=bench_1gbit_2n_8g_N1536
- **2026-07-17 16:12:49** — Experimento bench_1gbit_2n_8g_N1536 rep1 -> done (111s)
- **2026-07-17 16:14:57** — Experimento bench_1gbit_2n_8g_N1536 rep2 -> done (120s)
- **2026-07-17 16:17:01** — Experimento bench_1gbit_2n_8g_N1536 rep3 -> done (117s)
- **2026-07-17 16:18:57** — Experimento bench_1gbit_2n_8g_N1536 rep4 -> failed (108s)
- **2026-07-17 16:23:59** — Orquestrador anterior interrompido em bench_1gbit_2n_8g_N1536 rep5 (bench). Reconciliado: órfãos varridos, marcado failed para retentativa.
- **2026-07-17 16:25:26** — Sessao do VSCode fechada acidentalmente pelo usuario derrubou o processo do orquestrador em segundo plano NO MEIO da rep5 de bench_1gbit_2n_8g_N1536 -- validacao NAO-PLANEJADA e excelente do mecanismo de crash-recovery: job OAR 2169626 continuou intacto (state=Running), inflight.txt detectou corretamente a rep5 abandonada, orphan_cleanup + retomada automatica funcionaram ao relancar o orquestrador. Corrigido de vez o gap ja conhecido de shaping residual: scripts/02-orchestrator.sh agora tem trap EXIT combinado (lock+shape_off), entao QUALQUER saida anormal (die(), sinal, sessao derrubada) limpa o shaping automaticamente -- elimina a necessidade de intervencao manual que ja ocorreu 3x nesta sessao. Tambem observado: rep4 de bench_1gbit_2n_8g_N1536 completou a aplicacao com sucesso (rc=0, todos os 8 ranks reportaram tempo/throughput) mas dc.csv saiu vazio (0 bytes) e dc.trace anormalmente pequeno (11KB vs ~2.6MB esperado) -- falha na conversao aky_converter/pj_dump, causa ainda nao investigada, checkpoint corretamente recusou como 'failed' (nao aceitou resultado parcial). A reexecucao (retry automatico da mesma rep) e o proximo teste dessa hipotese.
- **2026-07-17 16:25:39** — Pre-flight de campanha: OK. sha256(bin/dc)=20ed4ef9f81e2b5ccc2c72901d8222ea1e12134d702ea93989379fa40c5a8c70
- **2026-07-17 16:25:39** — Orquestrador iniciado. 3 nós disponíveis, 66/105 linhas compatíveis. phase=bench dry_run=0 only_id=bench_1gbit_2n_8g_N1536
- **2026-07-17 16:27:42** — Experimento bench_1gbit_2n_8g_N1536 rep4 -> failed (108s)
- **2026-07-17 16:29:58** — Experimento bench_1gbit_2n_8g_N1536 rep5 -> failed (121s)
- **2026-07-17 16:30:05** — Execução do orquestrador finalizada (fase=bench): OK=0 FAILED=2 SKIPPED_DONE=3 SKIPPED_VRAM=0 SKIPPED_DEFER=0
- **2026-07-17 16:31:10** — Pre-flight de campanha: OK. sha256(bin/dc)=20ed4ef9f81e2b5ccc2c72901d8222ea1e12134d702ea93989379fa40c5a8c70
- **2026-07-17 16:31:10** — Orquestrador iniciado. 3 nós disponíveis, 66/105 linhas compatíveis. phase=bench dry_run=0 only_id=bench_1gbit_2n_8g_N1536
- **2026-07-17 16:33:22** — Experimento bench_1gbit_2n_8g_N1536 rep4 -> failed (118s)
- **2026-07-17 16:35:37** — Experimento bench_1gbit_2n_8g_N1536 rep5 -> failed (120s)
- **2026-07-17 16:35:44** — Execução do orquestrador finalizada (fase=bench): OK=0 FAILED=2 SKIPPED_DONE=3 SKIPPED_VRAM=0 SKIPPED_DEFER=0
- **2026-07-17 17:18:51** — CAUSA RAIZ TECNICA do crash em bench_1gbit_2n_8g_N1536 rep4/rep5 (reproduzida manualmente, isolada da campanha, 100% deterministica dado o mesmo input): o crash 'terminate called after throwing std::out_of_range' NAO e do aky_converter, e do PJ_DUMP, ao processar a saida do aky_converter. Cadeia causal completa: (1) aky_converter falha em achar o 'send' correspondente a um evento ptp receive especifico (rank4 recebendo de rank0) -- mensagem propria dele: '[aky_keys] no queue, there is no key available... but no send for this receive yet, do you synchronize your input traces?'; (2) MESMO SEM achar o par, aky_converter ainda EMITE uma linha PajeEndLink malformada (falta o campo final 'Key' -- '8 0.394315004 root LINK rank4 PTP' tem 6 campos, a definicao PajeEndLink exige 7); (3) pj_dump, ao parsear essa linha malformada, faz um acesso a vetor fora dos limites (vector::_M_range_check) e crasha com SIGABRT (rc=134) em vez de reportar erro ou pular a linha -- bug real no parser do pj_dump (nao trata definicao/linha incompativel com robustez). REPRODUZIDO isoladamente 2/2 vezes rodando aky_converter+pj_dump manualmente sobre os MESMOS arquivos rastro-*.rst do rep4 (fora do pipeline da campanha, em /tmp/aky_debug) -- confirma que e determinístico DADO O MESMO INPUT (nao e race no proprio conversor), a fonte da nao-determinismo entre reps esta em UPSTREAM disso: por que o rank0 'perde' um evento de send para o rank4 em alguns reps e nao outros. Causa raiz DESSA parte (por que o proprio dado de trace as vezes tem o mismatch send/receive) NAO investigada a fundo -- exigiria depurar o codigo-fonte do Akypuera (nao disponivel localmente, so o binario compilado no Nix store, sem simbolos de origem para dpurar alem do que os proprios logs de erro do binario ja revelam) ou instrumentar main.c/worker.c para logar cada chamada MPI relevante, o que nao foi feito por ser mudanca potencialmente invasiva na aplicacao e por tempo. HIPOTESE em aberto (nao testada): correlacao com banda 1gbit especificamente (congestionamento/timing sob shaping severo) vs. independente de banda -- proximo teste planejado: repetir o mesmo experimento sob 10gbit para checar se o mesmo mismatch ocorre.
- **2026-07-17 17:19:08** — Pre-flight de campanha: OK. sha256(bin/dc)=20ed4ef9f81e2b5ccc2c72901d8222ea1e12134d702ea93989379fa40c5a8c70
- **2026-07-17 17:19:08** — Orquestrador iniciado. 3 nós disponíveis, 66/105 linhas compatíveis. phase=bench dry_run=0 only_id=bench_10gbit_2n_8g_N1536
- **2026-07-17 17:20:41** — Experimento bench_10gbit_2n_8g_N1536 rep1 -> done (79s)
- **2026-07-17 17:22:07** — Experimento bench_10gbit_2n_8g_N1536 rep2 -> done (78s)
- **2026-07-17 17:23:32** — Experimento bench_10gbit_2n_8g_N1536 rep3 -> done (77s)
- **2026-07-17 17:24:57** — Experimento bench_10gbit_2n_8g_N1536 rep4 -> done (77s)
- **2026-07-17 17:26:24** — Experimento bench_10gbit_2n_8g_N1536 rep5 -> done (79s)
- **2026-07-17 17:26:25** — Execução do orquestrador finalizada (fase=bench): OK=5 FAILED=0 SKIPPED_DONE=0 SKIPPED_VRAM=0 SKIPPED_DEFER=0
- **2026-07-17 17:26:59** — TESTE DE CARACTERIZACAO POR BANDA (bench_10gbit_2n_8g_N1536, mesma topologia/N/np exatos do experimento que falhava): 5/5 repeticoes DONE, ZERO crashes de trace, sob shaping de 10gbit real (validate_bandwidth_effective mediu 9.44Gbit/s, razao 0.944). Sob 1gbit a MESMA celula falhou 2/5 no teste anterior (rep4,rep5, mismatch send/receive determinístico dado o mesmo input). Evidencia empirica FORTE (embora nao definitiva -- amostra pequena, 5 vs 5) de correlacao entre o crash de trace e o congestionamento severo sob 1gbit, consistente com CAUSA1 original (rendezvous/timing sob TCP-shaped severo) -- porem manifestando-se de forma DIFERENTE agora: antes (sessao anterior a --skip-output) o gather bloqueante travava (deadlock duro); agora, com --skip-output eliminando o gather, o unico trafego de rede remanescente e o halo exchange da propria simulacao (Isend/Irecv), e sob 1gbit aparentemente uma mensagem ocasionalmente demora o suficiente (ou reordena) a ponto do instrumentador Akypuera (que intercepta via PMPI) perder o registro de send correspondente a um receive -- possivelmente um efeito de timeout/retry em nivel de UCX/TCP que Akypuera nao contabiliza corretamente, nao uma perda real de dado da aplicacao (dc.output sempre mostra rc=0 e metricas de tempo validas mesmo quando o trace falha).
- **2026-07-17 17:44:32** — Orquestrador iniciado. 3 nós disponíveis, 66/105 linhas compatíveis. phase=full dry_run=1 only_id=<todos>
- **2026-07-17 17:44:32** — Execução do orquestrador finalizada (fase=full): OK=0 FAILED=0 SKIPPED_DONE=0 SKIPPED_VRAM=0 SKIPPED_DEFER=7
- **2026-07-17 17:44:32** — Orquestrador iniciado. 3 nós disponíveis, 66/105 linhas compatíveis. phase=bench dry_run=1 only_id=<todos>
- **2026-07-17 17:44:32** — Pulado bench_1gbit_1n_4g_N1472: VRAM 36.03GB > orçamento seguro (gate conservador, ver design doc secao 4/6.5).
- **2026-07-17 17:44:32** — Pulado bench_1gbit_2n_8g_N1856: VRAM 36.19GB > orçamento seguro (gate conservador, ver design doc secao 4/6.5).
- **2026-07-17 17:44:32** — Pulado bench_1gbit_3n_12g_N2112: VRAM 35.76GB > orçamento seguro (gate conservador, ver design doc secao 4/6.5).
- **2026-07-17 17:44:32** — Pulado bench_10gbit_1n_4g_N1472: VRAM 36.03GB > orçamento seguro (gate conservador, ver design doc secao 4/6.5).
- **2026-07-17 17:44:32** — Pulado bench_10gbit_2n_8g_N1856: VRAM 36.19GB > orçamento seguro (gate conservador, ver design doc secao 4/6.5).
- **2026-07-17 17:44:32** — Pulado bench_10gbit_3n_12g_N2112: VRAM 35.76GB > orçamento seguro (gate conservador, ver design doc secao 4/6.5).
- **2026-07-17 17:44:32** — Pulado bench_25gbit_1n_4g_N1472: VRAM 36.03GB > orçamento seguro (gate conservador, ver design doc secao 4/6.5).
- **2026-07-17 17:44:32** — Pulado bench_25gbit_2n_8g_N1856: VRAM 36.19GB > orçamento seguro (gate conservador, ver design doc secao 4/6.5).
- **2026-07-17 17:44:32** — Pulado bench_25gbit_3n_12g_N2112: VRAM 35.76GB > orçamento seguro (gate conservador, ver design doc secao 4/6.5).
- **2026-07-17 17:44:32** — Execução do orquestrador finalizada (fase=bench): OK=0 FAILED=0 SKIPPED_DONE=0 SKIPPED_VRAM=9 SKIPPED_DEFER=0
- **2026-07-17 17:44:50** — Orquestrador iniciado. 3 nós disponíveis, 66/105 linhas compatíveis. phase=bench dry_run=1 only_id=<todos>
- **2026-07-17 17:44:50** — Pulado bench_1gbit_1n_4g_N1472: VRAM 36.03GB > orçamento seguro (gate conservador, ver design doc secao 4/6.5).
- **2026-07-17 17:44:50** — Pulado bench_1gbit_2n_8g_N1856: VRAM 36.19GB > orçamento seguro (gate conservador, ver design doc secao 4/6.5).
- **2026-07-17 17:44:50** — Pulado bench_1gbit_3n_12g_N2112: VRAM 35.76GB > orçamento seguro (gate conservador, ver design doc secao 4/6.5).
- **2026-07-17 17:44:50** — Pulado bench_10gbit_1n_4g_N1472: VRAM 36.03GB > orçamento seguro (gate conservador, ver design doc secao 4/6.5).
- **2026-07-17 17:44:51** — Pulado bench_10gbit_2n_8g_N1856: VRAM 36.19GB > orçamento seguro (gate conservador, ver design doc secao 4/6.5).
- **2026-07-17 17:44:51** — Pulado bench_10gbit_3n_12g_N2112: VRAM 35.76GB > orçamento seguro (gate conservador, ver design doc secao 4/6.5).
- **2026-07-17 17:44:51** — Pulado bench_25gbit_1n_4g_N1472: VRAM 36.03GB > orçamento seguro (gate conservador, ver design doc secao 4/6.5).
- **2026-07-17 17:44:51** — Pulado bench_25gbit_2n_8g_N1856: VRAM 36.19GB > orçamento seguro (gate conservador, ver design doc secao 4/6.5).
- **2026-07-17 17:44:51** — Pulado bench_25gbit_3n_12g_N2112: VRAM 35.76GB > orçamento seguro (gate conservador, ver design doc secao 4/6.5).
- **2026-07-17 17:44:51** — Execução do orquestrador finalizada (fase=bench): OK=0 FAILED=0 SKIPPED_DONE=0 SKIPPED_VRAM=9 SKIPPED_DEFER=0
- **2026-07-17 17:44:51** — Orquestrador iniciado. 3 nós disponíveis, 66/105 linhas compatíveis. phase=bench dry_run=1 only_id=<todos>
- **2026-07-17 17:44:51** — Pulado bench_1gbit_1n_4g_N1472: VRAM 36.03GB > orçamento seguro (gate conservador, ver design doc secao 4/6.5).
- **2026-07-17 17:44:51** — Pulado bench_1gbit_2n_8g_N1856: VRAM 36.19GB > orçamento seguro (gate conservador, ver design doc secao 4/6.5).
- **2026-07-17 17:44:51** — Pulado bench_1gbit_3n_12g_N2112: VRAM 35.76GB > orçamento seguro (gate conservador, ver design doc secao 4/6.5).
- **2026-07-17 17:44:51** — Pulado bench_10gbit_1n_4g_N1472: VRAM 36.03GB > orçamento seguro (gate conservador, ver design doc secao 4/6.5).
- **2026-07-17 17:44:51** — Pulado bench_10gbit_2n_8g_N1856: VRAM 36.19GB > orçamento seguro (gate conservador, ver design doc secao 4/6.5).
- **2026-07-17 17:44:51** — Pulado bench_10gbit_3n_12g_N2112: VRAM 35.76GB > orçamento seguro (gate conservador, ver design doc secao 4/6.5).
- **2026-07-17 17:44:51** — Pulado bench_25gbit_1n_4g_N1472: VRAM 36.03GB > orçamento seguro (gate conservador, ver design doc secao 4/6.5).
- **2026-07-17 17:44:52** — Pulado bench_25gbit_2n_8g_N1856: VRAM 36.19GB > orçamento seguro (gate conservador, ver design doc secao 4/6.5).
- **2026-07-17 17:44:52** — Pulado bench_25gbit_3n_12g_N2112: VRAM 35.76GB > orçamento seguro (gate conservador, ver design doc secao 4/6.5).
- **2026-07-17 17:44:52** — Execução do orquestrador finalizada (fase=bench): OK=0 FAILED=0 SKIPPED_DONE=0 SKIPPED_VRAM=9 SKIPPED_DEFER=0
- **2026-07-17 17:46:25** — Iniciando fase bench priorizada: nodes.txt temporariamente reduzido a 1 no (chuc-3) para escopar a execucao as 33 linhas de 1-no (rapidas, sem sensibilidade a rede/travamento), evitando gastar walltime remanescente (~45min) em linhas de 2-3 nos maiores. nodes.txt.bak3 guarda os 3 nos originais para restaurar depois.
- **2026-07-17 17:46:37** — Pre-flight de campanha: OK. sha256(bin/dc)=20ed4ef9f81e2b5ccc2c72901d8222ea1e12134d702ea93989379fa40c5a8c70
- **2026-07-17 17:46:37** — Orquestrador iniciado. 1 nós disponíveis, 36/105 linhas compatíveis. phase=bench dry_run=0 only_id=<todos>
- **2026-07-17 17:46:46** — Experimento bench_1gbit_1n_4g_N64 rep1 -> done (5s)
- **2026-07-17 17:46:55** — Experimento bench_1gbit_1n_4g_N64 rep2 -> done (5s)
- **2026-07-17 17:47:03** — Experimento bench_1gbit_1n_4g_N64 rep3 -> done (5s)
- **2026-07-17 17:47:11** — Experimento bench_1gbit_1n_4g_N64 rep4 -> done (6s)
- **2026-07-17 17:47:19** — Experimento bench_1gbit_1n_4g_N64 rep5 -> done (6s)
- **2026-07-17 17:47:28** — Experimento bench_1gbit_1n_4g_N128 rep1 -> done (6s)
- **2026-07-17 17:47:36** — Experimento bench_1gbit_1n_4g_N128 rep2 -> done (6s)
- **2026-07-17 17:47:45** — Experimento bench_1gbit_1n_4g_N128 rep3 -> done (6s)
- **2026-07-17 17:47:53** — Experimento bench_1gbit_1n_4g_N128 rep4 -> done (6s)
- **2026-07-17 17:48:02** — Experimento bench_1gbit_1n_4g_N128 rep5 -> done (5s)
- **2026-07-17 17:48:12** — Experimento bench_1gbit_1n_4g_N256 rep1 -> done (7s)
- **2026-07-17 17:48:21** — Experimento bench_1gbit_1n_4g_N256 rep2 -> done (7s)
- **2026-07-17 17:48:31** — Experimento bench_1gbit_1n_4g_N256 rep3 -> done (7s)
- **2026-07-17 17:48:41** — Experimento bench_1gbit_1n_4g_N256 rep4 -> done (7s)
- **2026-07-17 17:48:51** — Experimento bench_1gbit_1n_4g_N256 rep5 -> done (7s)
- **2026-07-17 17:49:06** — Experimento bench_1gbit_1n_4g_N512 rep1 -> done (13s)
- **2026-07-17 17:49:23** — Experimento bench_1gbit_1n_4g_N512 rep2 -> done (13s)
- **2026-07-17 17:49:38** — Experimento bench_1gbit_1n_4g_N512 rep3 -> done (13s)
- **2026-07-17 17:49:54** — Experimento bench_1gbit_1n_4g_N512 rep4 -> done (13s)
- **2026-07-17 17:50:09** — Experimento bench_1gbit_1n_4g_N512 rep5 -> done (13s)
- **2026-07-17 17:51:01** — Experimento bench_1gbit_1n_4g_N1024 rep1 -> done (49s)
- **2026-07-17 17:51:53** — Experimento bench_1gbit_1n_4g_N1024 rep2 -> done (48s)
- **2026-07-17 17:52:49** — Experimento bench_1gbit_1n_4g_N1024 rep3 -> done (53s)
- **2026-07-17 17:53:40** — Experimento bench_1gbit_1n_4g_N1024 rep4 -> done (49s)
- **2026-07-17 17:54:32** — Experimento bench_1gbit_1n_4g_N1024 rep5 -> done (48s)
- **2026-07-17 17:55:38** — Experimento bench_1gbit_1n_4g_N1088 rep1 -> done (64s)
- **2026-07-17 17:56:44** — Experimento bench_1gbit_1n_4g_N1088 rep2 -> done (62s)
- **2026-07-17 17:57:50** — Experimento bench_1gbit_1n_4g_N1088 rep3 -> done (64s)
- **2026-07-17 17:58:55** — Experimento bench_1gbit_1n_4g_N1088 rep4 -> done (62s)
- **2026-07-17 18:00:00** — Experimento bench_1gbit_1n_4g_N1088 rep5 -> done (63s)
- **2026-07-17 18:01:09** — Experimento bench_1gbit_1n_4g_N1152 rep1 -> done (66s)
- **2026-07-17 18:02:17** — Experimento bench_1gbit_1n_4g_N1152 rep2 -> done (65s)
- **2026-07-17 18:03:24** — Experimento bench_1gbit_1n_4g_N1152 rep3 -> done (65s)
- **2026-07-17 18:04:33** — Experimento bench_1gbit_1n_4g_N1152 rep4 -> done (66s)
- **2026-07-17 18:05:41** — Experimento bench_1gbit_1n_4g_N1152 rep5 -> done (65s)
- **2026-07-17 18:07:10** — Experimento bench_1gbit_1n_4g_N1216 rep1 -> done (85s)
- **2026-07-17 18:08:38** — Experimento bench_1gbit_1n_4g_N1216 rep2 -> done (86s)
- **2026-07-17 18:10:18** — Experimento bench_1gbit_1n_4g_N1216 rep3 -> done (96s)
- **2026-07-17 18:11:49** — Experimento bench_1gbit_1n_4g_N1216 rep4 -> done (89s)
- **2026-07-17 18:13:18** — Experimento bench_1gbit_1n_4g_N1216 rep5 -> done (85s)
- **2026-07-17 18:14:46** — Experimento bench_1gbit_1n_4g_N1280 rep1 -> done (85s)
- **2026-07-17 18:16:13** — Experimento bench_1gbit_1n_4g_N1280 rep2 -> done (84s)
- **2026-07-17 18:17:40** — Experimento bench_1gbit_1n_4g_N1280 rep3 -> done (84s)
- **2026-07-17 18:19:06** — Experimento bench_1gbit_1n_4g_N1280 rep4 -> done (84s)
- **2026-07-17 18:20:36** — Experimento bench_1gbit_1n_4g_N1280 rep5 -> done (87s)
- **2026-07-18 16:37:50** — FIM DA SESSAO (job 2169626 expirou ~18:30 de 2026-07-17, estado OAR->Error/terminado por walltime, comportamento esperado). Sweep de 1-no (bench 1gbit) completou 9/11 tamanhos (N64 a N1280, todos 5/5 reps, zero falhas) antes do tempo acabar; N1344 e N1408 nunca comecaram. nodes.txt restaurado para os 3 nos originais (chuc-3/4/8) para a proxima alocacao. Nenhuma acao pendente nos nos (OAR ja liberou os recursos).
- **2026-07-18 17:37:38** — LIMPEZA DE DISCO (18/07, a pedido do usuário, quota pessoal ~120GB/100GB): deletados 4 arquivos .dc órfãos em validation/, todos correspondentes a execuções com status 'failed' no checkpoint (nenhum 'done' afetado) ou não referenciados por código ativo: predicted_full_2x2x2_N1536.dc (27GB, full_2x2x2_N1536 failed), predicted_1gbit_2n_8g_N1536_rep1.dc (4.7GB real, sparse, incidente 10/07), predicted_1gbit_2n_8g_N1536_rep2.dc (9.1GB real, sparse, mesmo incidente), predicted.dc (1GB, saída de smoke-test pré-framework, não usado pelo código atual). Total liberado: ~41.8GB. validation/ agora com 28K.
- **2026-07-18 23:47:24** — CAUSA 2 CORRIGIDA (18/07, sem alocacao chuc -- feito inteiramente em chiclet-1, CPU-only, backend OpenMP): src/coordinator.c, dc_receive_and_write_results -- substituido fwrite(1 float)/fseek por voxel (loop x/y/z) por UM fwrite por linha contigua em x (loop y/z, fwrite de worker_sizes[0]-2*STENCIL floats por chamada). Correcao matematica: x e a dimensao contigua (dc_get_index_for_coordinates), confirmado que para (y,z) fixos e worker_coords[0] fixo, tanto worker_index quanto global_index avancam 1-a-1 com local_x -- logica de indexacao INALTERADA, so o agrupamento das chamadas de I/O. VALIDADO: (1) correcao bit-a-bit -- output .dc identico (mesmo md5sum) entre versao nova e original via git stash, em N=64/np=4 e N=256/np=4; (2) performance -- N=256/np=4: original 89.1s vs corrigido 4.16s (~21x mais rapido) so na fase de escrita, tempo de execucao/CUDA nao tocado (dc_receive_and_write_results roda DEPOIS da janela medida, main.c:186). NAO TESTADO em GPU real nem em N grande (1536+) -- prioridade para a proxima alocacao chuc, mas a validacao de correcao (bit-a-bit) e independente de GPU e ja da alta confianca. Combinado com --skip-output (usado no bench), esta correcao deve tornar a fase FULL viavel mesmo para topologias grandes, que antes travavam so pela escrita (Causa 2 isolada, sem nem precisar de shaping/rede).
- **2026-07-18 23:48:17** — TODO resolvido (sem alocacao chuc): lib/setup.sh ganhou setup_apt_deps() (instala iperf3+jq via apt em todos os nos, best-effort), chamada dentro de setup_run() logo apos gpu_census. Elimina a necessidade de instalacao manual documentada na sessao anterior (17/07) -- proxima alocacao ja deve ter validate_bandwidth_effective funcionando sem intervencao.
- **2026-07-18 23:58:08** — BUG REAL ENCONTRADO E CORRIGIDO (18/07, sem alocacao chuc -- reproduzido localmente em chiclet-1, comportamento de procps/regex, nao especifico de hardware): lib/resilience.sh orphan_cleanup() tinha DOIS bugs empilhados na linha de limpeza de mpirun/prterun/prted. (1) '-E' nao e flag valida deste pkill/pgrep (procps-ng) -- toda vez que essa linha rodava, falhava silenciosamente (rc=2, engolido por 2>/dev/null + ausencia de set -e + 'true' final), entao NUNCA matou nenhum mpirun/prterun/prted orfao em nenhuma sessao ate hoje -- so a linha bin/dc funcionava de verdade. (2) Ao remover o -E ingenuamente, o padrao sem colchete 'mpirun|prterun|prted' AUTO-CASA com a propria linha de comando (as duas ocorrencias, TERM e KILL, ficam na MESMA string enviada por ssh_root) -- mesma classe de bug ja corrigida em validate.sh (iperf3) e ja documentada para bin/dc no proprio resilience.sh, mas nao aplicada aqui. FIX final: '[m]pirun|[p]rterun|[p]rted' (colchete em 1 letra de cada alternativa). Validado empiricamente em 3 etapas sem chuc: (a) confirmado que -E de fato retorna 'invalid option'; (b) confirmado que -f sozinho ja suporta alternacao |; (c) confirmado que o padrao colchetado NAO se auto-mata (script completo ate o fim) E ainda mata corretamente um processo real chamado 'mpirun ...' (via 'exec -a' simulando o nome). IMPACTO: orphan_cleanup e chamado antes de TODO run_experiment e apos toda falha -- a limpeza de mpirun/prterun/prted orfaos provavelmente nunca funcionou em nenhuma sessao anterior; pode explicar parte da necessidade de limpeza manual observada em sessoes passadas.
- **2026-07-20 14:38:23** — Deploy iniciado em 2 nós: chuc-1.lille.grid5000.fr,chuc-5.lille.grid5000.fr (env=debiannvopen11-big)
- **2026-07-20 14:42:26** — Deploy concluído. IPs kavlan: chuc-1.lille.grid5000.fr 10.8.9.101/18,chuc-5.lille.grid5000.fr 10.8.9.105/18
- **2026-07-20 14:51:11** — Setup concluído. Censo de GPU: chuc-1.lille.grid5000.fr 4,chuc-5.lille.grid5000.fr 4
- **2026-07-20 14:51:15** — Build OK (BACKEND=cuda PROFILE=akypuera ARCH=sm_80), commit=4bd74bb
- **2026-07-20 14:51:22** — Pre-flight de campanha: OK. sha256(bin/dc)=2073116fbd03cee1137cef1c1ed37759867936406e9b7945f3ca32b311847a9a
- **2026-07-20 14:51:23** — Versões de toolchain capturadas em /home/aandrade/ic/io-research/distributed-cube-average/g5k/logs/versions.txt
- **2026-07-20 14:51:23** — Nova alocacao job 2171858 (chuc-1/chuc-5, apenas 2 nos -- chuc-3 teve problema e nao entrou na reserva): deploy+setup+build+preflight OK.
- **2026-07-20 14:52:01** — Orquestrador anterior interrompido em bench_1gbit_1n_4g_N1344 rep1 (bench). Reconciliado: órfãos varridos, marcado failed para retentativa.
- **2026-07-20 14:52:07** — Pre-flight de campanha: OK. sha256(bin/dc)=2073116fbd03cee1137cef1c1ed37759867936406e9b7945f3ca32b311847a9a
- **2026-07-20 14:52:07** — Orquestrador iniciado. 2 nós disponíveis, 54/105 linhas compatíveis. phase=full dry_run=0 only_id=full_2x2x2_N1536
- **2026-07-20 14:57:01** — Experimento full_2x2x2_N1536 rep1 -> done (285s)
- **2026-07-20 14:57:01** — Execução do orquestrador finalizada (fase=full): OK=1 FAILED=0 SKIPPED_DONE=0 SKIPPED_VRAM=0 SKIPPED_DEFER=0
- **2026-07-20 16:12:43** — Build OK (BACKEND=cuda PROFILE=akypuera ARCH=sm_80), commit=4bd74bb
- **2026-07-20 16:16:51** — Limpando checkpoint de full_2x2x2_N1536 (removidas entradas antigas 'failed'/'done' sem ground truth) para reexecutar com a correcao do overflow de inteiro em precomp.c aplicada -- objetivo: obter a primeira validacao numerica real (ground truth) para essa topologia.
- **2026-07-20 16:17:04** — Pre-flight de campanha: OK. sha256(bin/dc)=72fe11fcca98912212083ef60b5db3c7a7f3644365b16853b53bfa2574095c21
- **2026-07-20 16:17:04** — Orquestrador iniciado. 2 nós disponíveis, 54/105 linhas compatíveis. phase=full dry_run=0 only_id=full_2x2x2_N1536
- **2026-07-20 16:22:35** — Build OK (BACKEND=cuda PROFILE=akypuera ARCH=sm_80), commit=4bd74bb
- **2026-07-20 16:23:08** — TERCEIRO bug da familia overflow-de-inteiro encontrado por auditoria de codigo (18-20/07): src/boundary.c, randomVelocityBoundaryPartition -- 'int i = dc_get_index_for_coordinates(...)' truncava o retorno size_t ao indexar vpz[i]/vsv[i]. MAIS GRAVE que os dois de precomp.c: aqueles crashavam alto (malloc retorna NULL, mensagem de erro clara); este silenciosamente escreveria em indice errado (index truncado/possivelmente negativo) sem nenhum sinal de erro visivel -- corromperia o dado de ground truth sem avisar. Descoberto por auditoria (grep por padroes 'int .*size'/'int n =') ANTES do path ser executado ate o fim com o fix, entao nao ha evidencia direta de dado ja corrompido, mas a leitura do codigo nao deixa duvida de que teria acontecido para qualquer dominio nessa faixa de tamanho (>1290^3). Fix: 'size_t i' nos 2 pontos (linhas ~42 e ~96 do arquivo original). Root build.sh tambem teve um problema operacional a parte: 'rm -rf bin' falhou com 'Directory not empty' por causa de um arquivo .nfsXXXXXXXXX (silly-rename do NFS) -- causa raiz: um pkill manual meu (nao uma funcao do lib/) usava erroneamente '\|' escapado dentro de aspas simples ('mpirun\|prterun\|prted'), que dentro de single-quotes do shell remoto preserva o backslash literalmente -- o padrao passado ao pkill -f nao era uma alternacao valida, entao os processos antigos (do full_2x2x2_N1536 rodando ANTES do fix do boundary.c) nunca foram mortos e continuaram escrevendo/segurando bin/dc aberto. Licao: usar sempre lib/resilience.sh:orphan_cleanup() (ja corrigida e testada) em vez de pkill ad-hoc improvisado. Binarios (bin/dc e bin_openmp_gt) reconstruidos do zero com os 3 fixes completos (coordinator.c CAUSA2, precomp.c overflow, boundary.c truncamento).
- **2026-07-20 16:23:21** — Orquestrador anterior interrompido em full_2x2x2_N1536 rep1 (full). Reconciliado: órfãos varridos, marcado failed para retentativa.
- **2026-07-20 16:23:27** — Pre-flight de campanha: OK. sha256(bin/dc)=58ff2602aa027130749dc23f060cc8b6f54001d3ab8759b27598a40fba331254
- **2026-07-20 16:23:27** — Orquestrador iniciado. 2 nós disponíveis, 54/105 linhas compatíveis. phase=full dry_run=0 only_id=full_2x2x2_N1536
- **2026-07-20 16:28:51** — Build OK (BACKEND=cuda PROFILE=akypuera ARCH=sm_80), commit=4bd74bb
- **2026-07-20 16:30:44** — Build OK (BACKEND=cuda PROFILE=akypuera ARCH=sm_80), commit=4bd74bb
- **2026-07-20 16:32:35** — Experimento full_2x2x2_N1536 rep1 -> failed (307s)
- **2026-07-20 16:32:39** — Execução do orquestrador finalizada (fase=full): OK=0 FAILED=1 SKIPPED_DONE=0 SKIPPED_VRAM=0 SKIPPED_DEFER=0
- **2026-07-20 16:33:24** — Pre-flight de campanha: OK. sha256(bin/dc)=0642cf2fa0ecf42c2326dcd92e80eee344f20fa833ff4a2c40aefcb451aa6b2e
- **2026-07-20 16:33:24** — Orquestrador iniciado. 2 nós disponíveis, 54/105 linhas compatíveis. phase=full dry_run=0 only_id=full_2x2x2_N1536
- **2026-07-20 16:42:37** — Experimento full_2x2x2_N1536 rep1 -> done (310s)
- **2026-07-20 16:42:37** — Execução do orquestrador finalizada (fase=full): OK=1 FAILED=0 SKIPPED_DONE=0 SKIPPED_VRAM=0 SKIPPED_DEFER=0
- **2026-07-20 21:12:00** — Orquestrador iniciado. 2 nós disponíveis, 54/105 linhas compatíveis. phase=bench dry_run=1 only_id=<todos> bandwidths=25gbit,10gbit
- **2026-07-20 21:12:00** — Pulado bench_25gbit_1n_4g_N1472: VRAM 36.03GB > orçamento seguro (gate conservador, ver design doc secao 4/6.5).
- **2026-07-20 21:12:07** — Orquestrador iniciado. 2 nós disponíveis, 54/105 linhas compatíveis. phase=bench dry_run=1 only_id=<todos> bandwidths=25gbit,10gbit
- **2026-07-20 21:12:08** — Pulado bench_25gbit_1n_4g_N1472: VRAM 36.03GB > orçamento seguro (gate conservador, ver design doc secao 4/6.5).
- **2026-07-20 21:12:08** — Pulado bench_25gbit_2n_8g_N1856: VRAM 36.19GB > orçamento seguro (gate conservador, ver design doc secao 4/6.5).
- **2026-07-20 21:12:08** — Pulado bench_10gbit_1n_4g_N1472: VRAM 36.03GB > orçamento seguro (gate conservador, ver design doc secao 4/6.5).
- **2026-07-20 21:12:08** — Pulado bench_10gbit_2n_8g_N1856: VRAM 36.19GB > orçamento seguro (gate conservador, ver design doc secao 4/6.5).
- **2026-07-20 21:12:08** — Execução do orquestrador finalizada (fase=bench): OK=0 FAILED=0 SKIPPED_DONE=0 SKIPPED_VRAM=4 SKIPPED_DEFER=0
- **2026-07-20 21:12:14** — Orquestrador iniciado. 2 nós disponíveis, 54/105 linhas compatíveis. phase=bench dry_run=1 only_id=<todos> bandwidths=<padrão 1gbit,10gbit,25gbit>
- **2026-07-20 21:12:14** — Pulado bench_1gbit_1n_4g_N1472: VRAM 36.03GB > orçamento seguro (gate conservador, ver design doc secao 4/6.5).
- **2026-07-20 21:12:14** — Pulado bench_1gbit_2n_8g_N1856: VRAM 36.19GB > orçamento seguro (gate conservador, ver design doc secao 4/6.5).
- **2026-07-20 21:12:14** — Pulado bench_10gbit_1n_4g_N1472: VRAM 36.03GB > orçamento seguro (gate conservador, ver design doc secao 4/6.5).
- **2026-07-20 21:12:14** — Pulado bench_10gbit_2n_8g_N1856: VRAM 36.19GB > orçamento seguro (gate conservador, ver design doc secao 4/6.5).
- **2026-07-20 21:12:14** — Pulado bench_25gbit_1n_4g_N1472: VRAM 36.03GB > orçamento seguro (gate conservador, ver design doc secao 4/6.5).
- **2026-07-20 21:12:14** — Pulado bench_25gbit_2n_8g_N1856: VRAM 36.19GB > orçamento seguro (gate conservador, ver design doc secao 4/6.5).
- **2026-07-20 21:12:14** — Execução do orquestrador finalizada (fase=bench): OK=0 FAILED=0 SKIPPED_DONE=0 SKIPPED_VRAM=6 SKIPPED_DEFER=0
- **2026-07-20 21:12:25** — Adicionada flag --bandwidths (opcional) ao scripts/02-orchestrator.sh, a pedido do usuario apos auditoria completa da campanha revelar forte desbalanceamento entre bandas (1gbit: 48/175 reps done, 10gbit: 5/175, 25gbit: 0/175) -- consequencia do loop de bandas ser fixo (1gbit,10gbit,25gbit) e uma alocacao interrompida sempre deixar 1gbit mais avancado. Flag permite escolher subconjunto/ordem de bandas nesta invocacao (ex: --bandwidths 25gbit,10gbit para priorizar o que falta). Default (sem a flag) preserva exatamente o comportamento anterior. Testado: dry-run com a flag processa so as bandas pedidas na ordem pedida; dry-run sem a flag continua processando 1gbit,10gbit,25gbit como sempre.
- **2026-07-23 14:31:34** — Deploy iniciado em 4 nós: chuc-5.lille.grid5000.fr,chuc-6.lille.grid5000.fr chuc-7.lille.grid5000.fr,chuc-8.lille.grid5000.fr (env=debiannvopen11-big)
- **2026-07-23 14:35:56** — Deploy concluído. IPs kavlan: chuc-5.lille.grid5000.fr 10.8.9.105/18,chuc-6.lille.grid5000.fr 10.8.9.106/18 chuc-7.lille.grid5000.fr 10.8.9.107/18,chuc-8.lille.grid5000.fr 10.8.9.108/18
- **2026-07-23 15:12:48** — Setup concluído. Censo de GPU: chuc-5.lille.grid5000.fr 4,chuc-6.lille.grid5000.fr 4 chuc-7.lille.grid5000.fr 4,chuc-8.lille.grid5000.fr 4
- **2026-07-23 15:12:52** — Build OK (BACKEND=cuda PROFILE=akypuera ARCH=sm_80), commit=4bd74bb
- **2026-07-23 15:13:00** — Pre-flight de campanha: OK. sha256(bin/dc)=b82eb2c3400df4aa739c5c0033bcbe336f36e89a17fe7e7006180c5614601cc0
- **2026-07-23 15:13:01** — Versões de toolchain capturadas em /home/aandrade/ic/io-research/distributed-cube-average/g5k/logs/versions.txt
- **2026-07-23 15:13:01** — Nova alocacao job 2174305 (chuc-5/6/7/8, 4 nos): deploy+setup+build+preflight OK.
- **2026-07-23 15:13:40** — Pre-flight de campanha: OK. sha256(bin/dc)=b82eb2c3400df4aa739c5c0033bcbe336f36e89a17fe7e7006180c5614601cc0
- **2026-07-23 15:13:40** — Orquestrador iniciado. 4 nós disponíveis, 78/105 linhas compatíveis. phase=bench dry_run=0 only_id=bench_1gbit_1n_4g_N1344 bandwidths=<padrão 1gbit,10gbit,25gbit>
- **2026-07-23 15:15:51** — Experimento bench_1gbit_1n_4g_N1344 rep1 -> done (115s)
- **2026-07-23 15:17:54** — Experimento bench_1gbit_1n_4g_N1344 rep2 -> done (113s)
- **2026-07-23 15:19:57** — Experimento bench_1gbit_1n_4g_N1344 rep3 -> done (113s)
- **2026-07-23 15:22:01** — Experimento bench_1gbit_1n_4g_N1344 rep4 -> done (115s)
- **2026-07-23 15:24:01** — Experimento bench_1gbit_1n_4g_N1344 rep5 -> done (111s)
- **2026-07-23 15:24:01** — Execução do orquestrador finalizada (fase=bench): OK=5 FAILED=0 SKIPPED_DONE=0 SKIPPED_VRAM=0 SKIPPED_DEFER=0
- **2026-07-23 15:24:31** — Pre-flight de campanha: OK. sha256(bin/dc)=b82eb2c3400df4aa739c5c0033bcbe336f36e89a17fe7e7006180c5614601cc0
- **2026-07-23 15:24:31** — Orquestrador iniciado. 4 nós disponíveis, 78/105 linhas compatíveis. phase=bench dry_run=0 only_id=bench_1gbit_2n_8g_N1536 bandwidths=<padrão 1gbit,10gbit,25gbit>
- **2026-07-23 15:26:53** — Experimento bench_1gbit_2n_8g_N1536 rep4 -> failed (125s)
- **2026-07-23 15:29:05** — Experimento bench_1gbit_2n_8g_N1536 rep5 -> failed (113s)
- **2026-07-23 15:29:15** — Execução do orquestrador finalizada (fase=bench): OK=0 FAILED=2 SKIPPED_DONE=3 SKIPPED_VRAM=0 SKIPPED_DEFER=0
- **2026-07-23 15:30:29** — Pre-flight de campanha: OK. sha256(bin/dc)=b82eb2c3400df4aa739c5c0033bcbe336f36e89a17fe7e7006180c5614601cc0
- **2026-07-23 15:30:29** — Orquestrador iniciado. 4 nós disponíveis, 78/105 linhas compatíveis. phase=bench dry_run=0 only_id=<todos> bandwidths=25gbit,10gbit
- **2026-07-23 15:30:51** — Experimento bench_25gbit_1n_4g_N64 rep1 -> done (5s)
- **2026-07-23 15:31:06** — Experimento bench_25gbit_1n_4g_N64 rep2 -> done (6s)
- **2026-07-23 15:31:21** — Experimento bench_25gbit_1n_4g_N64 rep3 -> done (6s)
- **2026-07-23 15:31:37** — Experimento bench_25gbit_1n_4g_N64 rep4 -> done (5s)
- **2026-07-23 15:31:52** — Experimento bench_25gbit_1n_4g_N64 rep5 -> done (5s)
- **2026-07-23 15:32:07** — Experimento bench_25gbit_1n_4g_N128 rep1 -> done (6s)
- **2026-07-23 15:32:23** — Experimento bench_25gbit_1n_4g_N128 rep2 -> done (6s)
- **2026-07-23 15:32:39** — Experimento bench_25gbit_1n_4g_N128 rep3 -> done (6s)
- **2026-07-23 15:32:54** — Experimento bench_25gbit_1n_4g_N128 rep4 -> done (6s)
- **2026-07-23 15:33:10** — Experimento bench_25gbit_1n_4g_N128 rep5 -> done (5s)
- **2026-07-23 15:33:27** — Experimento bench_25gbit_1n_4g_N256 rep1 -> done (7s)
- **2026-07-23 15:33:43** — Experimento bench_25gbit_1n_4g_N256 rep2 -> done (7s)
- **2026-07-23 15:34:00** — Experimento bench_25gbit_1n_4g_N256 rep3 -> done (7s)
- **2026-07-23 15:34:17** — Experimento bench_25gbit_1n_4g_N256 rep4 -> done (7s)
- **2026-07-23 15:34:34** — Experimento bench_25gbit_1n_4g_N256 rep5 -> done (8s)
- **2026-07-23 15:34:57** — Experimento bench_25gbit_1n_4g_N512 rep1 -> done (13s)
- **2026-07-23 15:35:20** — Experimento bench_25gbit_1n_4g_N512 rep2 -> done (13s)
- **2026-07-23 15:35:42** — Experimento bench_25gbit_1n_4g_N512 rep3 -> done (13s)
- **2026-07-23 15:36:05** — Experimento bench_25gbit_1n_4g_N512 rep4 -> done (13s)
- **2026-07-23 15:36:27** — Experimento bench_25gbit_1n_4g_N512 rep5 -> done (13s)
- **2026-07-23 15:37:26** — Experimento bench_25gbit_1n_4g_N1024 rep1 -> done (49s)
- **2026-07-23 15:38:25** — Experimento bench_25gbit_1n_4g_N1024 rep2 -> done (48s)
- **2026-07-23 15:39:23** — Experimento bench_25gbit_1n_4g_N1024 rep3 -> done (49s)
- **2026-07-23 15:40:22** — Experimento bench_25gbit_1n_4g_N1024 rep4 -> done (49s)
- **2026-07-23 15:41:21** — Experimento bench_25gbit_1n_4g_N1024 rep5 -> done (49s)
- **2026-07-23 15:42:36** — Experimento bench_25gbit_1n_4g_N1088 rep1 -> done (66s)
- **2026-07-23 15:43:52** — Experimento bench_25gbit_1n_4g_N1088 rep2 -> done (65s)
- **2026-07-23 15:45:06** — Experimento bench_25gbit_1n_4g_N1088 rep3 -> done (65s)
- **2026-07-23 15:46:22** — Experimento bench_25gbit_1n_4g_N1088 rep4 -> done (65s)
- **2026-07-23 15:47:37** — Experimento bench_25gbit_1n_4g_N1088 rep5 -> done (66s)
- **2026-07-23 15:48:57** — Experimento bench_25gbit_1n_4g_N1152 rep1 -> done (70s)
- **2026-07-23 15:50:13** — Experimento bench_25gbit_1n_4g_N1152 rep2 -> done (65s)
- **2026-07-23 15:51:28** — Experimento bench_25gbit_1n_4g_N1152 rep3 -> done (65s)
- **2026-07-24 15:38:27** — Deploy iniciado em 4 nós: chuc-2.lille.grid5000.fr,chuc-3.lille.grid5000.fr chuc-4.lille.grid5000.fr,chuc-5.lille.grid5000.fr (env=debiannvopen11-big)
- **2026-07-24 15:42:27** — Deploy concluído. IPs kavlan: chuc-2.lille.grid5000.fr 10.8.9.102/18,chuc-3.lille.grid5000.fr 10.8.9.103/18 chuc-4.lille.grid5000.fr 10.8.9.104/18,chuc-5.lille.grid5000.fr 10.8.9.105/18
- **2026-07-24 16:54:05** — Setup concluído. Censo de GPU: chuc-2.lille.grid5000.fr 4,chuc-3.lille.grid5000.fr 4 chuc-4.lille.grid5000.fr 4,chuc-5.lille.grid5000.fr 4
- **2026-07-24 16:54:09** — Build OK (BACKEND=cuda PROFILE=akypuera ARCH=sm_80), commit=4bd74bb
- **2026-07-24 16:54:16** — Pre-flight de campanha: OK. sha256(bin/dc)=f94410c35d38db108fa2d9ab37f89b9d05accdf1c14a78863402e43c08452eb0
- **2026-07-24 16:54:17** — Versões de toolchain capturadas em /home/aandrade/ic/io-research/distributed-cube-average/g5k/logs/versions.txt
- **2026-07-24 16:54:17** — Nova alocacao job 2175436 (chuc-2/3/4/5, 4 nos): deploy+setup+build+preflight OK.
- **2026-07-24 16:55:06** — Orquestrador anterior interrompido em bench_25gbit_1n_4g_N1152 rep4 (bench). Reconciliado: órfãos varridos, marcado failed para retentativa.
- **2026-07-24 16:55:13** — Pre-flight de campanha: OK. sha256(bin/dc)=f94410c35d38db108fa2d9ab37f89b9d05accdf1c14a78863402e43c08452eb0
- **2026-07-24 16:55:13** — Orquestrador iniciado. 4 nós disponíveis, 78/105 linhas compatíveis. phase=bench dry_run=0 only_id=<todos> bandwidths=10gbit,25gbit,1gbit
- **2026-07-24 16:55:35** — Experimento bench_10gbit_1n_4g_N64 rep1 -> done (5s)
- **2026-07-24 16:55:50** — Experimento bench_10gbit_1n_4g_N64 rep2 -> done (6s)
- **2026-07-24 16:56:05** — Experimento bench_10gbit_1n_4g_N64 rep3 -> done (6s)
- **2026-07-24 16:56:20** — Experimento bench_10gbit_1n_4g_N64 rep4 -> done (6s)
- **2026-07-24 16:56:36** — Experimento bench_10gbit_1n_4g_N64 rep5 -> done (5s)
- **2026-07-24 16:56:51** — Experimento bench_10gbit_1n_4g_N128 rep1 -> done (6s)
- **2026-07-24 16:57:06** — Experimento bench_10gbit_1n_4g_N128 rep2 -> done (6s)
- **2026-07-24 16:57:22** — Experimento bench_10gbit_1n_4g_N128 rep3 -> done (5s)
- **2026-07-24 16:57:37** — Experimento bench_10gbit_1n_4g_N128 rep4 -> done (6s)
- **2026-07-24 16:57:53** — Experimento bench_10gbit_1n_4g_N128 rep5 -> done (6s)
- **2026-07-24 16:58:09** — Experimento bench_10gbit_1n_4g_N256 rep1 -> done (7s)
- **2026-07-24 16:58:26** — Experimento bench_10gbit_1n_4g_N256 rep2 -> done (7s)
- **2026-07-24 16:58:43** — Experimento bench_10gbit_1n_4g_N256 rep3 -> done (7s)
- **2026-07-24 16:59:00** — Experimento bench_10gbit_1n_4g_N256 rep4 -> done (7s)
- **2026-07-24 16:59:16** — Experimento bench_10gbit_1n_4g_N256 rep5 -> done (7s)
- **2026-07-24 16:59:39** — Experimento bench_10gbit_1n_4g_N512 rep1 -> done (12s)
- **2026-07-24 17:00:01** — Experimento bench_10gbit_1n_4g_N512 rep2 -> done (13s)
- **2026-07-24 17:00:24** — Experimento bench_10gbit_1n_4g_N512 rep3 -> done (13s)
- **2026-07-24 17:00:46** — Experimento bench_10gbit_1n_4g_N512 rep4 -> done (13s)
- **2026-07-24 17:01:09** — Experimento bench_10gbit_1n_4g_N512 rep5 -> done (13s)
- **2026-07-24 17:02:07** — Experimento bench_10gbit_1n_4g_N1024 rep1 -> done (49s)
- **2026-07-24 17:03:05** — Experimento bench_10gbit_1n_4g_N1024 rep2 -> done (49s)
- **2026-07-24 17:04:06** — Experimento bench_10gbit_1n_4g_N1024 rep3 -> done (51s)
- **2026-07-24 17:05:05** — Experimento bench_10gbit_1n_4g_N1024 rep4 -> done (50s)
- **2026-07-24 17:06:05** — Experimento bench_10gbit_1n_4g_N1024 rep5 -> done (51s)
- **2026-07-24 17:07:18** — Experimento bench_10gbit_1n_4g_N1088 rep1 -> done (64s)
- **2026-07-24 17:08:31** — Experimento bench_10gbit_1n_4g_N1088 rep2 -> done (64s)
- **2026-07-24 17:09:43** — Experimento bench_10gbit_1n_4g_N1088 rep3 -> done (62s)
- **2026-07-24 17:10:54** — Experimento bench_10gbit_1n_4g_N1088 rep4 -> done (62s)
- **2026-07-24 17:12:06** — Experimento bench_10gbit_1n_4g_N1088 rep5 -> done (62s)
- **2026-07-24 17:13:21** — Experimento bench_10gbit_1n_4g_N1152 rep1 -> done (66s)
- **2026-07-24 17:14:36** — Experimento bench_10gbit_1n_4g_N1152 rep2 -> done (66s)
- **2026-07-24 17:15:51** — Experimento bench_10gbit_1n_4g_N1152 rep3 -> done (64s)
- **2026-07-24 17:17:05** — Experimento bench_10gbit_1n_4g_N1152 rep4 -> done (64s)
- **2026-07-24 17:18:23** — Experimento bench_10gbit_1n_4g_N1152 rep5 -> done (69s)
- **2026-07-24 17:19:58** — Experimento bench_10gbit_1n_4g_N1216 rep1 -> done (85s)
- **2026-07-24 17:21:33** — Experimento bench_10gbit_1n_4g_N1216 rep2 -> done (85s)
- **2026-07-24 17:23:08** — Experimento bench_10gbit_1n_4g_N1216 rep3 -> done (85s)
- **2026-07-24 17:24:43** — Experimento bench_10gbit_1n_4g_N1216 rep4 -> done (86s)
- **2026-07-24 17:26:18** — Experimento bench_10gbit_1n_4g_N1216 rep5 -> done (86s)
- **2026-07-24 17:27:54** — Experimento bench_10gbit_1n_4g_N1280 rep1 -> done (87s)
- **2026-07-24 17:29:30** — Experimento bench_10gbit_1n_4g_N1280 rep2 -> done (85s)
- **2026-07-24 17:31:03** — Experimento bench_10gbit_1n_4g_N1280 rep3 -> done (84s)
- **2026-07-24 17:32:38** — Experimento bench_10gbit_1n_4g_N1280 rep4 -> done (85s)
- **2026-07-24 17:34:13** — Experimento bench_10gbit_1n_4g_N1280 rep5 -> done (86s)
- **2026-07-24 17:36:14** — Experimento bench_10gbit_1n_4g_N1344 rep1 -> done (112s)
- **2026-07-24 17:38:19** — Experimento bench_10gbit_1n_4g_N1344 rep2 -> done (115s)
- **2026-07-24 17:40:22** — Experimento bench_10gbit_1n_4g_N1344 rep3 -> done (114s)
- **2026-07-24 17:42:24** — Experimento bench_10gbit_1n_4g_N1344 rep4 -> done (111s)
- **2026-07-24 17:44:26** — Experimento bench_10gbit_1n_4g_N1344 rep5 -> done (112s)
- **2026-07-24 17:46:35** — Experimento bench_10gbit_1n_4g_N1408 rep1 -> done (119s)
- **2026-07-24 17:48:43** — Experimento bench_10gbit_1n_4g_N1408 rep2 -> done (118s)
- **2026-07-24 17:50:51** — Experimento bench_10gbit_1n_4g_N1408 rep3 -> done (119s)
- **2026-07-24 17:53:00** — Experimento bench_10gbit_1n_4g_N1408 rep4 -> done (119s)
- **2026-07-24 17:55:12** — Experimento bench_10gbit_1n_4g_N1408 rep5 -> done (121s)
- **2026-07-24 17:55:12** — Pulado bench_10gbit_1n_4g_N1472: VRAM 36.03GB > orçamento seguro (gate conservador, ver design doc secao 4/6.5).
- **2026-07-24 17:57:00** — Experimento bench_10gbit_2n_8g_N1600 rep1 -> done (98s)
- **2026-07-24 17:58:55** — Experimento bench_10gbit_2n_8g_N1600 rep2 -> done (104s)
- **2026-07-24 18:00:39** — Experimento bench_10gbit_2n_8g_N1600 rep3 -> done (94s)
- **2026-07-24 18:02:26** — Experimento bench_10gbit_2n_8g_N1600 rep4 -> done (96s)
- **2026-07-24 18:04:14** — Experimento bench_10gbit_2n_8g_N1600 rep5 -> done (98s)
- **2026-07-27 15:21:22** — Deploy iniciado em 4 nós: chuc-4.lille.grid5000.fr,chuc-5.lille.grid5000.fr chuc-7.lille.grid5000.fr,chuc-8.lille.grid5000.fr (env=debiannvopen11-big)
- **2026-07-27 15:25:42** — Deploy concluído. IPs kavlan: chuc-4.lille.grid5000.fr 10.8.9.104/18,chuc-5.lille.grid5000.fr 10.8.9.105/18 chuc-7.lille.grid5000.fr 10.8.9.107/18,chuc-8.lille.grid5000.fr 10.8.9.108/18
- **2026-07-27 15:36:43** — Setup concluído. Censo de GPU: chuc-4.lille.grid5000.fr 4,chuc-5.lille.grid5000.fr 3 chuc-7.lille.grid5000.fr 4,chuc-8.lille.grid5000.fr 4
- **2026-07-27 15:37:02** — Build OK (BACKEND=cuda PROFILE=akypuera ARCH=sm_80), commit=a17fcf2
- **2026-07-27 15:37:05** — GPU divergente em chuc-5.lille.grid5000.fr: esperado 4, encontrado 3. Linhas cuja distribuição uniforme exigir mais que 3 neste nó serão adiadas (csv_row_fits_gpu_capacity), não executadas incorretamente.
- **2026-07-27 15:37:26** — Pre-flight de campanha: OK. sha256(bin/dc)=0be619f19bc6000a2b3c4ad8aee835180c18e69f117fb318e4ef1d2fb487ac90
- **2026-07-27 15:37:42** — Versões de toolchain capturadas em /home/aandrade/ic/io-research/distributed-cube-average/g5k/logs/versions.txt
- **2026-07-27 15:37:42** — Bootstrap completo. 4 nós disponíveis. 78/105 linhas do CSV executáveis nesta alocação.
- **2026-07-27 15:39:05** — Orquestrador anterior interrompido em bench_10gbit_2n_8g_N1664 rep1 (bench). Reconciliado: órfãos varridos, marcado failed para retentativa.
- **2026-07-27 15:39:07** — GPU divergente em chuc-5.lille.grid5000.fr: esperado 4, encontrado 3. Linhas cuja distribuição uniforme exigir mais que 3 neste nó serão adiadas (csv_row_fits_gpu_capacity), não executadas incorretamente.
- **2026-07-27 15:39:27** — Pre-flight de campanha: OK. sha256(bin/dc)=0be619f19bc6000a2b3c4ad8aee835180c18e69f117fb318e4ef1d2fb487ac90
- **2026-07-27 15:39:27** — Orquestrador iniciado. 4 nós disponíveis, 78/105 linhas compatíveis. phase=bench dry_run=0 only_id=bench_25gbit_2n_8g_N1536 bandwidths=<padrão 1gbit,10gbit,25gbit>
- **2026-07-27 15:39:34** — Pulado bench_25gbit_2n_8g_N1536: capacidade real de GPU insuficiente em algum nó para a distribuição uniforme desta linha.
- **2026-07-27 15:39:34** — Execução do orquestrador finalizada (fase=bench): OK=0 FAILED=0 SKIPPED_DONE=0 SKIPPED_VRAM=0 SKIPPED_DEFER=1
- **2026-07-27 15:39:37** — GPU divergente em chuc-5.lille.grid5000.fr: esperado 4, encontrado 3. Linhas cuja distribuição uniforme exigir mais que 3 neste nó serão adiadas (csv_row_fits_gpu_capacity), não executadas incorretamente.
- **2026-07-27 15:39:57** — Pre-flight de campanha: OK. sha256(bin/dc)=0be619f19bc6000a2b3c4ad8aee835180c18e69f117fb318e4ef1d2fb487ac90
- **2026-07-27 15:39:57** — Orquestrador iniciado. 4 nós disponíveis, 78/105 linhas compatíveis. phase=bench dry_run=0 only_id=bench_25gbit_2n_8g_N1600 bandwidths=<padrão 1gbit,10gbit,25gbit>
- **2026-07-27 15:40:04** — Pulado bench_25gbit_2n_8g_N1600: capacidade real de GPU insuficiente em algum nó para a distribuição uniforme desta linha.
- **2026-07-27 15:40:04** — Execução do orquestrador finalizada (fase=bench): OK=0 FAILED=0 SKIPPED_DONE=0 SKIPPED_VRAM=0 SKIPPED_DEFER=1
- **2026-07-27 15:40:06** — GPU divergente em chuc-5.lille.grid5000.fr: esperado 4, encontrado 3. Linhas cuja distribuição uniforme exigir mais que 3 neste nó serão adiadas (csv_row_fits_gpu_capacity), não executadas incorretamente.
- **2026-07-27 15:40:27** — Pre-flight de campanha: OK. sha256(bin/dc)=0be619f19bc6000a2b3c4ad8aee835180c18e69f117fb318e4ef1d2fb487ac90
- **2026-07-27 15:40:27** — Orquestrador iniciado. 4 nós disponíveis, 78/105 linhas compatíveis. phase=bench dry_run=0 only_id=bench_25gbit_2n_8g_N1664 bandwidths=<padrão 1gbit,10gbit,25gbit>
- **2026-07-27 15:40:34** — Pulado bench_25gbit_2n_8g_N1664: capacidade real de GPU insuficiente em algum nó para a distribuição uniforme desta linha.
- **2026-07-27 15:40:34** — Execução do orquestrador finalizada (fase=bench): OK=0 FAILED=0 SKIPPED_DONE=0 SKIPPED_VRAM=0 SKIPPED_DEFER=1
- **2026-07-27 15:40:36** — GPU divergente em chuc-5.lille.grid5000.fr: esperado 4, encontrado 3. Linhas cuja distribuição uniforme exigir mais que 3 neste nó serão adiadas (csv_row_fits_gpu_capacity), não executadas incorretamente.
- **2026-07-27 15:40:56** — Pre-flight de campanha: OK. sha256(bin/dc)=0be619f19bc6000a2b3c4ad8aee835180c18e69f117fb318e4ef1d2fb487ac90
- **2026-07-27 15:40:56** — Orquestrador iniciado. 4 nós disponíveis, 78/105 linhas compatíveis. phase=bench dry_run=0 only_id=bench_25gbit_2n_8g_N1728 bandwidths=<padrão 1gbit,10gbit,25gbit>
- **2026-07-27 15:43:23** — Experimento bench_25gbit_2n_8g_N1728 rep1 -> done (130s)
- **2026-07-27 15:45:50** — Experimento bench_25gbit_2n_8g_N1728 rep2 -> done (137s)
- **2026-07-27 15:48:23** — Experimento bench_25gbit_2n_8g_N1728 rep3 -> done (142s)
- **2026-07-27 15:50:43** — Experimento bench_25gbit_2n_8g_N1728 rep4 -> done (130s)
- **2026-07-27 15:53:02** — Experimento bench_25gbit_2n_8g_N1728 rep5 -> done (129s)
- **2026-07-27 15:53:02** — Execução do orquestrador finalizada (fase=bench): OK=5 FAILED=0 SKIPPED_DONE=0 SKIPPED_VRAM=0 SKIPPED_DEFER=0
- **2026-07-27 15:53:04** — GPU divergente em chuc-5.lille.grid5000.fr: esperado 4, encontrado 3. Linhas cuja distribuição uniforme exigir mais que 3 neste nó serão adiadas (csv_row_fits_gpu_capacity), não executadas incorretamente.
- **2026-07-27 15:53:25** — Pre-flight de campanha: OK. sha256(bin/dc)=0be619f19bc6000a2b3c4ad8aee835180c18e69f117fb318e4ef1d2fb487ac90
- **2026-07-27 15:53:25** — Orquestrador iniciado. 4 nós disponíveis, 78/105 linhas compatíveis. phase=bench dry_run=0 only_id=bench_25gbit_2n_8g_N1792 bandwidths=<padrão 1gbit,10gbit,25gbit>
- **2026-07-27 15:56:10** — Experimento bench_25gbit_2n_8g_N1792 rep1 -> done (147s)
- **2026-07-27 15:58:41** — Experimento bench_25gbit_2n_8g_N1792 rep2 -> done (141s)
- **2026-07-27 16:01:14** — Experimento bench_25gbit_2n_8g_N1792 rep3 -> done (142s)
- **2026-07-27 16:03:54** — Experimento bench_25gbit_2n_8g_N1792 rep4 -> done (149s)
- **2026-07-27 16:06:33** — Experimento bench_25gbit_2n_8g_N1792 rep5 -> done (149s)
- **2026-07-27 16:06:33** — Execução do orquestrador finalizada (fase=bench): OK=5 FAILED=0 SKIPPED_DONE=0 SKIPPED_VRAM=0 SKIPPED_DEFER=0
- **2026-07-27 16:06:35** — GPU divergente em chuc-5.lille.grid5000.fr: esperado 4, encontrado 3. Linhas cuja distribuição uniforme exigir mais que 3 neste nó serão adiadas (csv_row_fits_gpu_capacity), não executadas incorretamente.
- **2026-07-27 16:06:56** — Pre-flight de campanha: OK. sha256(bin/dc)=0be619f19bc6000a2b3c4ad8aee835180c18e69f117fb318e4ef1d2fb487ac90
- **2026-07-27 16:06:56** — Orquestrador iniciado. 4 nós disponíveis, 78/105 linhas compatíveis. phase=bench dry_run=0 only_id=bench_25gbit_2n_8g_N1856 bandwidths=<padrão 1gbit,10gbit,25gbit>
- **2026-07-27 16:07:03** — Pulado bench_25gbit_2n_8g_N1856: VRAM 36.19GB > orçamento seguro (gate conservador, ver design doc secao 4/6.5).
- **2026-07-27 16:07:03** — Execução do orquestrador finalizada (fase=bench): OK=0 FAILED=0 SKIPPED_DONE=0 SKIPPED_VRAM=1 SKIPPED_DEFER=0
- **2026-07-27 16:07:05** — GPU divergente em chuc-5.lille.grid5000.fr: esperado 4, encontrado 3. Linhas cuja distribuição uniforme exigir mais que 3 neste nó serão adiadas (csv_row_fits_gpu_capacity), não executadas incorretamente.
- **2026-07-27 16:07:26** — Pre-flight de campanha: OK. sha256(bin/dc)=0be619f19bc6000a2b3c4ad8aee835180c18e69f117fb318e4ef1d2fb487ac90
- **2026-07-27 16:07:26** — Orquestrador iniciado. 4 nós disponíveis, 78/105 linhas compatíveis. phase=bench dry_run=0 only_id=bench_1gbit_2n_8g_N1536 bandwidths=<padrão 1gbit,10gbit,25gbit>
- **2026-07-27 16:09:57** — Experimento bench_1gbit_2n_8g_N1536 rep4 -> done (134s)
- **2026-07-27 16:12:29** — Experimento bench_1gbit_2n_8g_N1536 rep5 -> done (141s)
- **2026-07-27 16:12:29** — Execução do orquestrador finalizada (fase=bench): OK=2 FAILED=0 SKIPPED_DONE=3 SKIPPED_VRAM=0 SKIPPED_DEFER=0
- **2026-07-27 16:12:31** — GPU divergente em chuc-5.lille.grid5000.fr: esperado 4, encontrado 3. Linhas cuja distribuição uniforme exigir mais que 3 neste nó serão adiadas (csv_row_fits_gpu_capacity), não executadas incorretamente.
- **2026-07-27 16:12:52** — Pre-flight de campanha: OK. sha256(bin/dc)=0be619f19bc6000a2b3c4ad8aee835180c18e69f117fb318e4ef1d2fb487ac90
- **2026-07-27 16:12:52** — Orquestrador iniciado. 4 nós disponíveis, 78/105 linhas compatíveis. phase=bench dry_run=0 only_id=bench_1gbit_3n_12g_N1920 bandwidths=<padrão 1gbit,10gbit,25gbit>
- **2026-07-27 16:14:08** — Orquestrador anterior interrompido em bench_1gbit_3n_12g_N1920 rep1 (bench). Reconciliado: órfãos varridos, marcado failed para retentativa.
- **2026-07-27 16:14:10** — GPU divergente em chuc-5.lille.grid5000.fr: esperado 4, encontrado 3. Linhas cuja distribuição uniforme exigir mais que 3 neste nó serão adiadas (csv_row_fits_gpu_capacity), não executadas incorretamente.
- **2026-07-27 16:14:31** — Pre-flight de campanha: OK. sha256(bin/dc)=0be619f19bc6000a2b3c4ad8aee835180c18e69f117fb318e4ef1d2fb487ac90
- **2026-07-27 16:14:31** — Orquestrador iniciado. 4 nós disponíveis, 78/105 linhas compatíveis. phase=bench dry_run=0 only_id=bench_25gbit_2n_8g_N1536 bandwidths=<padrão 1gbit,10gbit,25gbit>
- **2026-07-27 16:16:32** — Experimento bench_25gbit_2n_8g_N1536 rep1 -> done (104s)
- **2026-07-27 16:18:22** — Experimento bench_25gbit_2n_8g_N1536 rep2 -> done (100s)
- **2026-07-27 16:20:04** — Experimento bench_25gbit_2n_8g_N1536 rep3 -> done (92s)
- **2026-07-27 16:21:48** — Experimento bench_25gbit_2n_8g_N1536 rep4 -> done (93s)
- **2026-07-27 16:23:33** — Experimento bench_25gbit_2n_8g_N1536 rep5 -> done (94s)
- **2026-07-27 16:23:34** — Execução do orquestrador finalizada (fase=bench): OK=5 FAILED=0 SKIPPED_DONE=0 SKIPPED_VRAM=0 SKIPPED_DEFER=0
- **2026-07-27 16:23:36** — GPU divergente em chuc-5.lille.grid5000.fr: esperado 4, encontrado 3. Linhas cuja distribuição uniforme exigir mais que 3 neste nó serão adiadas (csv_row_fits_gpu_capacity), não executadas incorretamente.
- **2026-07-27 16:23:57** — Pre-flight de campanha: OK. sha256(bin/dc)=0be619f19bc6000a2b3c4ad8aee835180c18e69f117fb318e4ef1d2fb487ac90
- **2026-07-27 16:23:57** — Orquestrador iniciado. 4 nós disponíveis, 78/105 linhas compatíveis. phase=bench dry_run=0 only_id=bench_25gbit_2n_8g_N1600 bandwidths=<padrão 1gbit,10gbit,25gbit>
- **2026-07-27 16:24:06** — GPU divergente em chuc-5.lille.grid5000.fr: esperado 4, encontrado 3. Linhas cuja distribuição uniforme exigir mais que 3 neste nó serão adiadas (csv_row_fits_gpu_capacity), não executadas incorretamente.
- **2026-07-27 16:24:26** — Pre-flight de campanha: OK. sha256(bin/dc)=0be619f19bc6000a2b3c4ad8aee835180c18e69f117fb318e4ef1d2fb487ac90
- **2026-07-27 16:24:26** — Orquestrador iniciado. 4 nós disponíveis, 78/105 linhas compatíveis. phase=bench dry_run=0 only_id=bench_25gbit_2n_8g_N1664 bandwidths=<padrão 1gbit,10gbit,25gbit>
- **2026-07-27 16:27:00** — Experimento bench_25gbit_2n_8g_N1664 rep1 -> done (137s)
- **2026-07-27 16:29:25** — Experimento bench_25gbit_2n_8g_N1664 rep2 -> done (135s)
- **2026-07-27 16:31:51** — Experimento bench_25gbit_2n_8g_N1664 rep3 -> done (136s)
- **2026-07-27 16:34:16** — Experimento bench_25gbit_2n_8g_N1664 rep4 -> done (135s)
- **2026-07-27 16:36:42** — Experimento bench_25gbit_2n_8g_N1664 rep5 -> done (135s)
- **2026-07-27 16:36:42** — Execução do orquestrador finalizada (fase=bench): OK=5 FAILED=0 SKIPPED_DONE=0 SKIPPED_VRAM=0 SKIPPED_DEFER=0
- **2026-07-27 16:36:44** — GPU divergente em chuc-5.lille.grid5000.fr: esperado 4, encontrado 3. Linhas cuja distribuição uniforme exigir mais que 3 neste nó serão adiadas (csv_row_fits_gpu_capacity), não executadas incorretamente.
- **2026-07-27 16:37:05** — Pre-flight de campanha: OK. sha256(bin/dc)=0be619f19bc6000a2b3c4ad8aee835180c18e69f117fb318e4ef1d2fb487ac90
- **2026-07-27 16:37:05** — Orquestrador iniciado. 4 nós disponíveis, 78/105 linhas compatíveis. phase=bench dry_run=0 only_id=bench_1gbit_3n_12g_N1920 bandwidths=<padrão 1gbit,10gbit,25gbit>
- **2026-07-27 16:42:27** — Experimento bench_1gbit_3n_12g_N1920 rep1 -> done (305s)
- **2026-07-27 16:47:42** — Experimento bench_1gbit_3n_12g_N1920 rep2 -> done (303s)
- **2026-07-27 16:52:59** — Experimento bench_1gbit_3n_12g_N1920 rep3 -> done (307s)
- **2026-07-27 16:58:14** — Experimento bench_1gbit_3n_12g_N1920 rep4 -> done (304s)
- **2026-07-27 17:03:30** — Experimento bench_1gbit_3n_12g_N1920 rep5 -> done (305s)
- **2026-07-27 17:03:31** — Execução do orquestrador finalizada (fase=bench): OK=5 FAILED=0 SKIPPED_DONE=0 SKIPPED_VRAM=0 SKIPPED_DEFER=0
- **2026-07-27 17:03:33** — GPU divergente em chuc-5.lille.grid5000.fr: esperado 4, encontrado 3. Linhas cuja distribuição uniforme exigir mais que 3 neste nó serão adiadas (csv_row_fits_gpu_capacity), não executadas incorretamente.
- **2026-07-27 17:03:54** — Pre-flight de campanha: OK. sha256(bin/dc)=0be619f19bc6000a2b3c4ad8aee835180c18e69f117fb318e4ef1d2fb487ac90
- **2026-07-27 17:03:54** — Orquestrador iniciado. 4 nós disponíveis, 78/105 linhas compatíveis. phase=bench dry_run=0 only_id=bench_10gbit_3n_12g_N1920 bandwidths=<padrão 1gbit,10gbit,25gbit>
- **2026-07-27 17:07:13** — Experimento bench_10gbit_3n_12g_N1920 rep1 -> done (181s)
- **2026-07-27 17:10:20** — Experimento bench_10gbit_3n_12g_N1920 rep2 -> done (177s)
- **2026-07-27 17:13:32** — Experimento bench_10gbit_3n_12g_N1920 rep3 -> done (180s)
- **2026-07-27 17:16:42** — Experimento bench_10gbit_3n_12g_N1920 rep4 -> done (180s)
- **2026-07-27 17:19:50** — Experimento bench_10gbit_3n_12g_N1920 rep5 -> done (176s)
- **2026-07-27 17:19:50** — Execução do orquestrador finalizada (fase=bench): OK=5 FAILED=0 SKIPPED_DONE=0 SKIPPED_VRAM=0 SKIPPED_DEFER=0
- **2026-07-27 17:19:53** — GPU divergente em chuc-5.lille.grid5000.fr: esperado 4, encontrado 3. Linhas cuja distribuição uniforme exigir mais que 3 neste nó serão adiadas (csv_row_fits_gpu_capacity), não executadas incorretamente.
- **2026-07-27 17:20:13** — Pre-flight de campanha: OK. sha256(bin/dc)=0be619f19bc6000a2b3c4ad8aee835180c18e69f117fb318e4ef1d2fb487ac90
- **2026-07-27 17:20:13** — Orquestrador iniciado. 4 nós disponíveis, 78/105 linhas compatíveis. phase=bench dry_run=0 only_id=bench_25gbit_3n_12g_N1920 bandwidths=<padrão 1gbit,10gbit,25gbit>
- **2026-07-27 17:23:30** — Experimento bench_25gbit_3n_12g_N1920 rep1 -> done (179s)
- **2026-07-27 17:26:39** — Experimento bench_25gbit_3n_12g_N1920 rep2 -> done (179s)
- **2026-07-27 17:29:49** — Experimento bench_25gbit_3n_12g_N1920 rep3 -> done (179s)
- **2026-07-27 17:32:58** — Experimento bench_25gbit_3n_12g_N1920 rep4 -> done (178s)
- **2026-07-27 17:36:06** — Experimento bench_25gbit_3n_12g_N1920 rep5 -> done (177s)
- **2026-07-27 17:36:07** — Execução do orquestrador finalizada (fase=bench): OK=5 FAILED=0 SKIPPED_DONE=0 SKIPPED_VRAM=0 SKIPPED_DEFER=0
- **2026-07-27 17:36:09** — GPU divergente em chuc-5.lille.grid5000.fr: esperado 4, encontrado 3. Linhas cuja distribuição uniforme exigir mais que 3 neste nó serão adiadas (csv_row_fits_gpu_capacity), não executadas incorretamente.
- **2026-07-27 17:36:30** — Pre-flight de campanha: OK. sha256(bin/dc)=0be619f19bc6000a2b3c4ad8aee835180c18e69f117fb318e4ef1d2fb487ac90
- **2026-07-27 17:36:30** — Orquestrador iniciado. 4 nós disponíveis, 78/105 linhas compatíveis. phase=bench dry_run=0 only_id=bench_1gbit_3n_12g_N1984 bandwidths=<padrão 1gbit,10gbit,25gbit>
- **2026-07-27 17:42:10** — Experimento bench_1gbit_3n_12g_N1984 rep1 -> done (322s)
- **2026-07-27 17:47:46** — Experimento bench_1gbit_3n_12g_N1984 rep2 -> done (325s)
- **2026-07-27 17:53:20** — Experimento bench_1gbit_3n_12g_N1984 rep3 -> done (323s)
- **2026-07-27 17:58:51** — Experimento bench_1gbit_3n_12g_N1984 rep4 -> done (321s)
- **2026-07-27 18:04:25** — Experimento bench_1gbit_3n_12g_N1984 rep5 -> done (322s)
- **2026-07-27 18:04:25** — Execução do orquestrador finalizada (fase=bench): OK=5 FAILED=0 SKIPPED_DONE=0 SKIPPED_VRAM=0 SKIPPED_DEFER=0
- **2026-07-27 18:04:27** — GPU divergente em chuc-5.lille.grid5000.fr: esperado 4, encontrado 3. Linhas cuja distribuição uniforme exigir mais que 3 neste nó serão adiadas (csv_row_fits_gpu_capacity), não executadas incorretamente.
- **2026-07-27 18:04:48** — Pre-flight de campanha: OK. sha256(bin/dc)=0be619f19bc6000a2b3c4ad8aee835180c18e69f117fb318e4ef1d2fb487ac90
- **2026-07-27 18:04:48** — Orquestrador iniciado. 4 nós disponíveis, 78/105 linhas compatíveis. phase=bench dry_run=0 only_id=bench_10gbit_3n_12g_N1984 bandwidths=<padrão 1gbit,10gbit,25gbit>
- **2026-07-27 18:08:13** — Experimento bench_10gbit_3n_12g_N1984 rep1 -> done (187s)
- **2026-07-27 18:10:11** — Experimento bench_10gbit_3n_12g_N1984 rep2 -> timeout (108s)
- **2026-07-27 18:10:21** — Execução do orquestrador finalizada (fase=bench): OK=1 FAILED=1 SKIPPED_DONE=0 SKIPPED_VRAM=0 SKIPPED_DEFER=3
- **2026-07-27 18:10:24** — GPU divergente em chuc-5.lille.grid5000.fr: esperado 4, encontrado 3. Linhas cuja distribuição uniforme exigir mais que 3 neste nó serão adiadas (csv_row_fits_gpu_capacity), não executadas incorretamente.
- **2026-07-27 18:10:44** — Pre-flight de campanha: OK. sha256(bin/dc)=0be619f19bc6000a2b3c4ad8aee835180c18e69f117fb318e4ef1d2fb487ac90
- **2026-07-27 18:10:44** — Orquestrador iniciado. 4 nós disponíveis, 78/105 linhas compatíveis. phase=bench dry_run=0 only_id=bench_25gbit_3n_12g_N1984 bandwidths=<padrão 1gbit,10gbit,25gbit>
- **2026-07-27 18:10:52** — Execução do orquestrador finalizada (fase=bench): OK=0 FAILED=0 SKIPPED_DONE=0 SKIPPED_VRAM=0 SKIPPED_DEFER=5
- **2026-07-27 18:11:03** — GPU divergente em chuc-5.lille.grid5000.fr: esperado 4, encontrado 3. Linhas cuja distribuição uniforme exigir mais que 3 neste nó serão adiadas (csv_row_fits_gpu_capacity), não executadas incorretamente.
- **2026-07-27 18:11:23** — Pre-flight de campanha: OK. sha256(bin/dc)=0be619f19bc6000a2b3c4ad8aee835180c18e69f117fb318e4ef1d2fb487ac90
- **2026-07-27 18:11:23** — Orquestrador iniciado. 4 nós disponíveis, 78/105 linhas compatíveis. phase=bench dry_run=0 only_id=bench_25gbit_2n_8g_N1600 bandwidths=<padrão 1gbit,10gbit,25gbit>
- **2026-07-27 18:11:31** — Execução do orquestrador finalizada (fase=bench): OK=0 FAILED=0 SKIPPED_DONE=0 SKIPPED_VRAM=0 SKIPPED_DEFER=5
- **2026-07-28 15:52:09** — Pre-flight de campanha: OK. sha256(bin/dc)=ee0c74ebbf8969e77097d8333a4d3373b1f13237cc8a1e412398347f7b94014a
- **2026-07-28 15:52:09** — Orquestrador iniciado. 4 nós disponíveis, 78/105 linhas compatíveis. phase=bench dry_run=0 only_id=bench_25gbit_1n_4g_N1344 bandwidths=<padrão 1gbit,10gbit,25gbit>
- **2026-07-28 15:54:18** — Pre-flight de campanha: OK. sha256(bin/dc)=ee0c74ebbf8969e77097d8333a4d3373b1f13237cc8a1e412398347f7b94014a
- **2026-07-28 15:54:18** — Orquestrador iniciado. 4 nós disponíveis, 78/105 linhas compatíveis. phase=bench dry_run=0 only_id=bench_25gbit_1n_4g_N1344 bandwidths=<padrão 1gbit,10gbit,25gbit>
- **2026-07-28 15:56:42** — Experimento bench_25gbit_1n_4g_N1344 rep1 -> done (127s)
- **2026-07-28 15:58:58** — Experimento bench_25gbit_1n_4g_N1344 rep2 -> done (127s)
- **2026-07-28 16:01:15** — Experimento bench_25gbit_1n_4g_N1344 rep3 -> done (127s)
- **2026-07-28 16:03:35** — Experimento bench_25gbit_1n_4g_N1344 rep4 -> done (129s)
- **2026-07-28 16:05:52** — Experimento bench_25gbit_1n_4g_N1344 rep5 -> done (127s)
- **2026-07-28 16:05:52** — Execução do orquestrador finalizada (fase=bench): OK=5 FAILED=0 SKIPPED_DONE=0 SKIPPED_VRAM=0 SKIPPED_DEFER=0
- **2026-07-28 16:06:47** — Pre-flight de campanha: OK. sha256(bin/dc)=ee0c74ebbf8969e77097d8333a4d3373b1f13237cc8a1e412398347f7b94014a
- **2026-07-28 16:06:47** — Orquestrador iniciado. 4 nós disponíveis, 78/105 linhas compatíveis. phase=bench dry_run=0 only_id=bench_10gbit_2n_8g_N1728 bandwidths=<padrão 1gbit,10gbit,25gbit>
- **2026-07-28 16:09:14** — Experimento bench_10gbit_2n_8g_N1728 rep1 -> done (130s)
- **2026-07-28 16:11:35** — Experimento bench_10gbit_2n_8g_N1728 rep2 -> done (131s)
- **2026-07-28 16:13:55** — Experimento bench_10gbit_2n_8g_N1728 rep3 -> done (129s)
- **2026-07-28 16:16:13** — Experimento bench_10gbit_2n_8g_N1728 rep4 -> done (128s)
- **2026-07-28 16:18:32** — Experimento bench_10gbit_2n_8g_N1728 rep5 -> done (129s)
- **2026-07-28 16:18:32** — Execução do orquestrador finalizada (fase=bench): OK=5 FAILED=0 SKIPPED_DONE=0 SKIPPED_VRAM=0 SKIPPED_DEFER=0
- **2026-07-28 16:19:11** — Pre-flight de campanha: OK. sha256(bin/dc)=ee0c74ebbf8969e77097d8333a4d3373b1f13237cc8a1e412398347f7b94014a
- **2026-07-28 16:19:11** — Orquestrador iniciado. 4 nós disponíveis, 78/105 linhas compatíveis. phase=bench dry_run=0 only_id=bench_1gbit_2n_8g_N1728 bandwidths=<padrão 1gbit,10gbit,25gbit>
- **2026-07-28 16:22:17** — Experimento bench_1gbit_2n_8g_N1728 rep1 -> done (169s)
- **2026-07-28 16:25:13** — Experimento bench_1gbit_2n_8g_N1728 rep2 -> done (165s)
- **2026-07-28 16:28:13** — Experimento bench_1gbit_2n_8g_N1728 rep3 -> done (170s)
- **2026-07-28 16:31:12** — Experimento bench_1gbit_2n_8g_N1728 rep4 -> done (169s)
- **2026-07-28 16:34:09** — Experimento bench_1gbit_2n_8g_N1728 rep5 -> done (167s)
- **2026-07-28 16:34:09** — Execução do orquestrador finalizada (fase=bench): OK=5 FAILED=0 SKIPPED_DONE=0 SKIPPED_VRAM=0 SKIPPED_DEFER=0
- **2026-07-28 16:35:03** — Pre-flight de campanha: OK. sha256(bin/dc)=ee0c74ebbf8969e77097d8333a4d3373b1f13237cc8a1e412398347f7b94014a
- **2026-07-28 16:35:03** — Orquestrador iniciado. 4 nós disponíveis, 78/105 linhas compatíveis. phase=bench dry_run=0 only_id=bench_25gbit_4n_16g_N2176 bandwidths=<padrão 1gbit,10gbit,25gbit>
- **2026-07-28 16:36:54** — Experimento bench_25gbit_4n_16g_N2176 rep1 -> failed (93s)
- **2026-07-28 16:38:55** — Experimento bench_25gbit_4n_16g_N2176 rep2 -> failed (100s)
- **2026-07-28 16:40:49** — Experimento bench_25gbit_4n_16g_N2176 rep3 -> failed (94s)
- **2026-07-28 16:42:43** — Experimento bench_25gbit_4n_16g_N2176 rep4 -> failed (94s)
- **2026-07-28 16:44:37** — Experimento bench_25gbit_4n_16g_N2176 rep5 -> failed (94s)
- **2026-07-28 16:44:46** — Execução do orquestrador finalizada (fase=bench): OK=0 FAILED=5 SKIPPED_DONE=0 SKIPPED_VRAM=0 SKIPPED_DEFER=0
- **2026-07-28 16:50:11** — Pre-flight de campanha: OK. sha256(bin/dc)=ee0c74ebbf8969e77097d8333a4d3373b1f13237cc8a1e412398347f7b94014a
- **2026-07-28 16:50:11** — Orquestrador iniciado. 4 nós disponíveis, 78/105 linhas compatíveis. phase=bench dry_run=0 only_id=bench_25gbit_4n_16g_N2176 bandwidths=<padrão 1gbit,10gbit,25gbit>
- **2026-07-28 16:53:44** — Experimento bench_25gbit_4n_16g_N2176 rep1 -> done (195s)
- **2026-07-28 16:57:07** — Experimento bench_25gbit_4n_16g_N2176 rep2 -> done (190s)
- **2026-07-28 17:00:35** — Experimento bench_25gbit_4n_16g_N2176 rep3 -> done (196s)
- **2026-07-28 17:03:59** — Experimento bench_25gbit_4n_16g_N2176 rep4 -> done (193s)
- **2026-07-28 17:07:30** — Experimento bench_25gbit_4n_16g_N2176 rep5 -> done (199s)
- **2026-07-28 17:07:30** — Execução do orquestrador finalizada (fase=bench): OK=5 FAILED=0 SKIPPED_DONE=0 SKIPPED_VRAM=0 SKIPPED_DEFER=0
- **2026-07-28 17:08:41** — Pre-flight de campanha: OK. sha256(bin/dc)=ee0c74ebbf8969e77097d8333a4d3373b1f13237cc8a1e412398347f7b94014a
- **2026-07-28 17:08:41** — Orquestrador iniciado. 4 nós disponíveis, 78/105 linhas compatíveis. phase=bench dry_run=0 only_id=bench_10gbit_4n_16g_N2176 bandwidths=<padrão 1gbit,10gbit,25gbit>
- **2026-07-28 17:12:12** — Experimento bench_10gbit_4n_16g_N2176 rep1 -> done (193s)
- **2026-07-28 17:15:38** — Experimento bench_10gbit_4n_16g_N2176 rep2 -> done (195s)
- **2026-07-28 17:19:00** — Experimento bench_10gbit_4n_16g_N2176 rep3 -> done (190s)
- **2026-07-28 17:22:23** — Experimento bench_10gbit_4n_16g_N2176 rep4 -> done (192s)
- **2026-07-28 17:25:58** — Experimento bench_10gbit_4n_16g_N2176 rep5 -> done (203s)
- **2026-07-28 17:25:58** — Execução do orquestrador finalizada (fase=bench): OK=5 FAILED=0 SKIPPED_DONE=0 SKIPPED_VRAM=0 SKIPPED_DEFER=0
- **2026-07-28 17:26:51** — Pre-flight de campanha: OK. sha256(bin/dc)=ee0c74ebbf8969e77097d8333a4d3373b1f13237cc8a1e412398347f7b94014a
- **2026-07-28 17:26:51** — Orquestrador iniciado. 4 nós disponíveis, 78/105 linhas compatíveis. phase=bench dry_run=0 only_id=bench_1gbit_4n_16g_N2176 bandwidths=<padrão 1gbit,10gbit,25gbit>
- **2026-07-28 17:33:11** — Experimento bench_1gbit_4n_16g_N2176 rep1 -> done (362s)
- **2026-07-28 17:39:25** — Experimento bench_1gbit_4n_16g_N2176 rep2 -> done (362s)
- **2026-07-28 17:45:42** — Experimento bench_1gbit_4n_16g_N2176 rep3 -> done (365s)
- **2026-07-28 17:52:01** — Experimento bench_1gbit_4n_16g_N2176 rep4 -> done (368s)
- **2026-07-28 17:58:15** — Experimento bench_1gbit_4n_16g_N2176 rep5 -> done (362s)
- **2026-07-28 17:58:15** — Execução do orquestrador finalizada (fase=bench): OK=5 FAILED=0 SKIPPED_DONE=0 SKIPPED_VRAM=0 SKIPPED_DEFER=0
- **2026-07-29 15:47:40** — Deploy iniciado em 4 nós: chuc-2.lille.grid5000.fr,chuc-3.lille.grid5000.fr chuc-7.lille.grid5000.fr,chuc-8.lille.grid5000.fr (env=debiannvopen11-big)
- **2026-07-29 16:14:44** — Deploy iniciado em 4 nós: chuc-2.lille.grid5000.fr,chuc-3.lille.grid5000.fr chuc-7.lille.grid5000.fr,chuc-8.lille.grid5000.fr (env=debiannvopen11-big)
- **2026-07-29 16:46:40** — Deploy iniciado em 4 nós: chuc-2.lille.grid5000.fr,chuc-3.lille.grid5000.fr chuc-7.lille.grid5000.fr,chuc-8.lille.grid5000.fr (env=debiannvopen11-big)
- **2026-07-29 17:04:37** — Setup concluído. Censo de GPU: chuc-2.lille.grid5000.fr 4,chuc-6.lille.grid5000.fr 4 chuc-8.lille.grid5000.fr 4
- **2026-07-29 17:04:56** — Build OK (BACKEND=cuda PROFILE=akypuera ARCH=sm_80), commit=a17fcf2
- **2026-07-29 17:05:19** — Pre-flight de campanha: OK. sha256(bin/dc)=d24cd60d4191651d12830f653457e0ef11542a7136b59c3e27a620795c994512
- **2026-07-29 17:05:35** — Versões de toolchain capturadas em /home/aandrade/ic/io-research/distributed-cube-average/g5k/logs/versions.txt
- **2026-07-29 17:05:35** — Resume (deploy manual, setup/build via script) completo. 3 nós disponíveis.
- **2026-07-29 17:06:16** — Pre-flight de campanha: OK. sha256(bin/dc)=d24cd60d4191651d12830f653457e0ef11542a7136b59c3e27a620795c994512
- **2026-07-29 17:06:16** — Orquestrador iniciado. 3 nós disponíveis, 66/105 linhas compatíveis. phase=bench dry_run=0 only_id=<todos> bandwidths=<padrão 1gbit,10gbit,25gbit>
- **2026-07-29 17:08:46** — Experimento bench_1gbit_1n_4g_N1408 rep1 -> done (135s)
- **2026-07-29 17:11:09** — Experimento bench_1gbit_1n_4g_N1408 rep2 -> done (134s)
- **2026-07-29 17:13:30** — Experimento bench_1gbit_1n_4g_N1408 rep3 -> done (134s)
- **2026-07-29 17:15:53** — Experimento bench_1gbit_1n_4g_N1408 rep4 -> done (136s)
- **2026-07-29 17:18:15** — Experimento bench_1gbit_1n_4g_N1408 rep5 -> done (135s)
- **2026-07-29 17:18:15** — Pulado bench_1gbit_1n_4g_N1472: VRAM 36.03GB > orçamento seguro (gate conservador, ver design doc secao 4/6.5).
- **2026-07-29 17:20:50** — Experimento bench_1gbit_2n_8g_N1600 rep1 -> done (146s)
- **2026-07-29 17:23:26** — Experimento bench_1gbit_2n_8g_N1600 rep2 -> done (148s)
- **2026-07-29 17:25:59** — Experimento bench_1gbit_2n_8g_N1600 rep3 -> done (145s)
- **2026-07-29 17:28:35** — Experimento bench_1gbit_2n_8g_N1600 rep4 -> done (148s)
- **2026-07-29 17:31:10** — Experimento bench_1gbit_2n_8g_N1600 rep5 -> done (147s)
- **2026-07-29 17:34:16** — Experimento bench_1gbit_2n_8g_N1664 rep1 -> done (178s)
- **2026-07-29 17:37:25** — Experimento bench_1gbit_2n_8g_N1664 rep2 -> done (181s)
- **2026-07-29 17:40:08** — Experimento bench_1gbit_2n_8g_N1664 rep3 -> timeout (155s)
- **2026-07-29 17:40:17** — Pulado bench_1gbit_2n_8g_N1856: VRAM 36.19GB > orçamento seguro (gate conservador, ver design doc secao 4/6.5).
- **2026-07-29 17:40:18** — Pulado bench_1gbit_3n_12g_N2112: VRAM 35.76GB > orçamento seguro (gate conservador, ver design doc secao 4/6.5).
- **2026-07-29 17:40:26** — Pulado bench_10gbit_1n_4g_N1472: VRAM 36.03GB > orçamento seguro (gate conservador, ver design doc secao 4/6.5).
- **2026-07-29 17:40:29** — Pulado bench_10gbit_2n_8g_N1856: VRAM 36.19GB > orçamento seguro (gate conservador, ver design doc secao 4/6.5).
- **2026-07-29 17:40:31** — Pulado bench_10gbit_3n_12g_N2112: VRAM 35.76GB > orçamento seguro (gate conservador, ver design doc secao 4/6.5).
- **2026-07-29 17:40:42** — Pulado bench_25gbit_1n_4g_N1472: VRAM 36.03GB > orçamento seguro (gate conservador, ver design doc secao 4/6.5).
- **2026-07-29 17:40:44** — Pulado bench_25gbit_2n_8g_N1856: VRAM 36.19GB > orçamento seguro (gate conservador, ver design doc secao 4/6.5).
- **2026-07-29 17:40:46** — Pulado bench_25gbit_3n_12g_N2112: VRAM 35.76GB > orçamento seguro (gate conservador, ver design doc secao 4/6.5).
- **2026-07-29 17:40:46** — Execução do orquestrador finalizada (fase=bench): OK=12 FAILED=1 SKIPPED_DONE=209 SKIPPED_VRAM=9 SKIPPED_DEFER=63
- **2026-07-30 17:30:00** — Sessão de preparação para o problema-âncora de 5 nós (2x2x5, 20 GPUs). Job 2179594 (chuc-4,6,7,8 — apenas 4 nós, escalonador reduziu de 5) expira às 17:45; job 2179960 (5 nós chuc reais) está agendado para 2026-07-31 15:15. Decisão do usuário: aguardar o job de amanhã; preparar tudo agora.
  N-âncora derivado para 2x2x5: usando o mesmo modelo de VRAM calibrado contra os 4 anchors existentes (VRAM_GB_por_GPU ≈ local_count × 44.48e-9 + 0.1415, reproduz N1344/1728/1920/2176 com resíduo ≤0.02GB), varredura em múltiplos de 10 (divisíveis por 2 e por 5) entre N=2280 e N=2400 mostra N=2340 como o maior valor que ainda fica ≤87% do orçamento de 34GB (40GB×0.85): VRAM=29.32GB (86.2%), consistente com o padrão dos anchors de 2 nós (86.0%) e 4 nós (86.6%), que também ficam no topo da banda 80-87%. N=2350 já cruza para 87.3%.
  Fórmula de decomposição local (STENCIL=4, confirmada em include/definitions.h e src/worker.c): eixo com P=1 -> sem halo; P=2 -> halo de um lado só (+STENCIL); P>=3 -> halo dos dois lados nos ranks internos (+2×STENCIL, pior caso). Para 2x2x5: dois eixos P=2 (full=N/2+4=1174) e um eixo P=5 (full=N/5+8=476). local_count=1174×1174×476=656.059.376, dentro da faixa dos 4 anchors existentes (602M-658M) — preserva o tamanho de bloco local por GPU quase idêntico ao do anchor de 4 nós (658M).
  Linhas adicionadas em g5k/csv/experimentos.csv: 1gbit/10gbit/25gbit,5,20,2x2x5,N=2340,1174x1174x476,29.32 (inseridas antes das duas linhas pré-existentes N=2432/2496, que são pontos da varredura geral de 105 linhas e NÃO satisfazem o critério de 80-87% — 2432 dá 96.9% e 2496 dá 104.7% do orçamento, ambas > 100% na estimativa conservadora do CSV, portanto inadequadas como anchor).
- **2026-08-07 04:53:09** — Deploy iniciado em 3 nós: chuc-2.lille.grid5000.fr,chuc-6.lille.grid5000.fr chuc-8.lille.grid5000.fr (env=debiannvopen11-big)
- **2026-08-07 04:59:53** — Deploy iniciado em 1 nós: chuc-8.lille.grid5000.fr (env=debiannvopen11-big)
- **2026-08-07 05:10:56** — Setup concluído. Censo de GPU: chuc-5.lille.grid5000.fr 4
- **2026-08-07 05:11:15** — Build OK (BACKEND=cuda PROFILE=akypuera ARCH=sm_80), commit=a17fcf2
- **2026-08-07 05:11:37** — Pre-flight de campanha: OK. sha256(bin/dc)=ba1cc6561f125f7f38ef979b11963c4a8e2a7291490eb74a766f3ef0df33338f
- **2026-08-07 05:11:52** — Versões de toolchain capturadas em /home/aandrade/ic/io-research/distributed-cube-average/g5k/logs/versions.txt
- **2026-08-07 05:11:52** — Resume (deploy manual, setup/build via script) completo. 1 nós disponíveis.
