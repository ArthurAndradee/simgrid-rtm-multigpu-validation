# Proposta: flag --benchmark/--skip-output (pular gather+write) -- analise completa

Sessao 2026-07-14. Documento de PLANEJAMENTO. NENHUM codigo foi alterado.
Referencia cruzada: g5k/logs/finalization_feasibility_map.md (modelo de tempo e mecanismos).

## 1. Plano de reservas com o CODIGO ATUAL (com gather+write)

Total sequencial coletavel ~= 1561 h ~= 65 dias de walltime; 23 linhas (1gbit multi-no)
permanecem INVIAVEIS por deadlock. Nao e uma campanha executavel -> priorizar subconjunto:

- R1-R4 (1 no x 12h): TODAS as 12 configs single-no, 5 reps (banda e no-op -> 1x/N). ~43h.
  Eixo 'tamanho de problema x 4 GPUs' completo.
- R5-R8 (2 nos x 12h): 2-no 10/25gbit N=1536-1856 (6 cfg x2 bw x5 reps), 1.9-3.4h/rep. ~200h.
- R9+ (3-4 nos x 24h, varios): 3-no N<=2112 e 4-no N<=2240 (10/25gbit, <6h/rep). ~300h+.
- NAO agendavel praticamente: 5-8 nos N>=2432 (7.6-13.6h/rep -> 2-3 reservas 24h por config so p/ 5 reps).
- NAO agendar: 23 linhas 1gbit multi-no -> DEADLOCK; documentar como limitacao.

Veredito: com codigo atual, coleta-se single-no completo + nucleo multi-no pequeno (2-3 nos,
10/25gbit). N grande, muitos nos, e TODO 1gbit multi-no ficam fora -> dominio de validade reduzido.

## 2. Comparacao CODIGO ATUAL vs --benchmark

| Metrica                 | Codigo atual        | Com --benchmark     |
|-------------------------|---------------------|---------------------|
| Linhas coletaveis       | 82/105 (23 deadlock)| 105/105             |
| Walltime total          | ~65 dias            | ~1 dia (~59x menor) |
| Reservas de 6h          | inviavel            | ~4                  |
| 1gbit multi-no          | DEADLOCK            | coletavel           |
| N grande/muitos nos     | estoura walltime    | ~3 min/run          |

Base: T_final=Num_GPUs*interior*2*0.959us (calibrado Teste 4). Com skip, run ~= iteracoes (~1-3 min).

## 3. Fundamento de comparabilidade (hipotese central da proposta)

FATO VERIFICADO NO CODIGO: o caminho SimGrid JA NAO executa o gather+write.
- worker.c:407-409: dc_send_data_to_coordinator tem '#ifdef SIMGRID return;' (no-op na simulacao).
- main.c:188-193: dc_receive_and_write_results esta sob '#ifndef SIMGRID' (nao chamado na simulacao).
Logo o 'Fletcher' que o modelo SimGrid representa e contra o qual foi calibrado NAO inclui a
Finalization. A versao real COM gather+write DIVERGE da referencia num trecho que:
- nao entra em total_time (medido em main.c:186, ANTES do gather em main.c:187);
- nao entra na janela de masking effectiveness (gather usa Send/Recv DEPOIS do ultimo Waitall;
  metrica definida Irecv->Waitall, e o R clipa eventos a essa janela);
- nao existe na simulacao.
=> Pular o gather+write no caminho real APROXIMA real<->SimGrid (remove divergencia), nao afasta.

Fato habilitador adicional: a metrica de masking effectiveness SO existe se o processo alcancar
MPI_Finalize (Akypuera despeja rastro-*.rst apenas no Finalize; processo travado/morto perde o
buffer em memoria). Com codigo atual, 1gbit multi-no (deadlock) e N grande (walltime) sao
CIENTIFICAMENTE INCOLETAVEIS para a metrica fina -- nao por escolha, por impossibilidade fisica.
Skip -> Finalize em segundos -> traco despejado -> 105 linhas coletaveis.

## 4. Vantagens / limitacoes / impactos

VANTAGENS:
- Destrava as 23 linhas 1gbit multi-no e as de N grande (unica forma de coletar a metrica fina nelas).
- ~59x menos walltime; campanha vira ~1 dia vs ~65 dias.
- Aproxima o binario real do caminho SimGrid calibrado (mais comparavel).
- Possivel bonus (NAO confirmado): pode eliminar o erro de aky_converter ('no send for this
  receive') observado nos testes, se causado pelos Send/Recv bloqueantes do gather no traco.

LIMITACOES / IMPACTOS:
- Ainda e recompilar (aditivo/guardado/reversivel, default bit-identico ao original).
- Runs em modo benchmark NAO produzem .dc -> nao servem para validacao NUMERICA (SHA-256/delta).
  A validacao numerica ja foi feita historicamente (<=512^3, tese) e e separada da de desempenho.
- Para N>512^3 (nunca validado numericamente), reporta-se desempenho de uma computacao cuja
  CORRETUDE nunca foi verificada e que o modo benchmark torna inverificavel (mesmo kernel, mas
  acumulacao FP em N grande nunca checada). LIMITACAO A DOCUMENTAR.
- Diferenca de traco benchmark vs nao-benchmark: so segura SE o R (compare_sim_real.R) realmente
  clipa a janela Irecv->Waitall antes de computar makespan. VERIFICAR no R antes de comitar.

## 5. Desenho da implementacao (NAO implementado) -- ver secao no chat/diff previsto.

## 6. Auditoria critica (argumentos CONTRA) -- ver secao no chat.

## 7. VERIFICACAO no compare_sim_real.R (feita 2026-07-14) -- DE-RISK do ponto critico

compare_sim_real.R:281-293 computa a metrica assim:
  core_start = min(Start onde Operation=='MPI_Irecv')
  core_end   = max(End   onde Operation=='MPI_Waitall')
  df filtrado: filter(Start < core_end) & filter(End > core_start)
               & filter(Operation %in% c('MPI_Irecv','MPI_Isend','MPI_Waitall'))
O gather (dc_send_data_to_coordinator usa MPI_Send; dc_receive usa MPI_Recv; ambos DEPOIS do
ultimo MPI_Waitall das iteracoes) e excluido DUPLAMENTE: (1) por janela (Start>=core_end) e
(2) por tipo de operacao (Send/Recv nao estao na lista). Ate o 'total_time' do R (summarized_dataset)
e max(End)-min(Start) DEPOIS desse recorte -> janela das iteracoes, nao o processo inteiro.
CONCLUSAO: modo benchmark (sem gather) produz EXATAMENTE a mesma masking effectiveness e o mesmo
total_time-de-janela que o modo completo. Risco de divergencia de metrica: ELIMINADO (verificado).
