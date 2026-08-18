# Mapa de viabilidade da campanha por walltime e por mecanismo de falha

Gerado automaticamente (session 2026-07-14). NAO editar a mao -- ver /tmp/gen_feas.py.

## Modelo e calibracao

Finalization = laco SERIAL no rank coordenador; cada worker escreve seu interior
(dim_local - 2*STENCIL por eixo) x2 campos (pc,qc), custo fixo tau por par fseek+fwrite.

    T_final(config) ~= Num_GPUs * interior_local * 2 * tau ,  tau = 0.959 us/par

Calibrado no Teste 4 (10gbit real, N=1536, 8 GPUs, local 772^3, /dev/null): 114 min medidos,
reproduzidos exatamente. Consistente com a via independente do Teste 1 (NFS ~4 MB/s -> ~15 min/particao).
Iteracoes (~1-2 min) sao desprezveis: T_run ~= T_final. Independente da banda de rede.

## Tabela por configuracao (bw-independente; 35 configs = 105 linhas / 3 bandas)

| Nos | GPUs | N | local pior caso | interior/worker | T_final 1 rep | T_final 5 reps |
|----:|-----:|--:|:---------------|----------------:|:-------------:|:--------------:|
| 1 | 4 | 64 | 64x36x36 | 4.390e+04 | 0 s | 2 s |
| 1 | 4 | 128 | 128x68x68 | 4.320e+05 | 3 s | 17 s |
| 1 | 4 | 256 | 256x132x132 | 3.813e+06 | 29 s | 2.4 min |
| 1 | 4 | 512 | 512x260x260 | 3.201e+07 | 4.1 min | 20.5 min |
| 1 | 4 | 1024 | 1024x516x516 | 2.622e+08 | 33.5 min | 2.79 h |
| 1 | 4 | 1088 | 1088x548x548 | 3.149e+08 | 40.3 min | 3.36 h |
| 1 | 4 | 1152 | 1152x580x580 | 3.743e+08 | 47.9 min | 3.99 h |
| 1 | 4 | 1216 | 1216x612x612 | 4.407e+08 | 56.4 min | 4.70 h |
| 1 | 4 | 1280 | 1280x644x644 | 5.145e+08 | 65.8 min | 5.48 h |
| 1 | 4 | 1344 | 1344x676x676 | 5.962e+08 | 76.2 min | 6.35 h |
| 1 | 4 | 1408 | 1408x708x708 | 6.860e+08 | 87.7 min | 7.31 h |
| 1 | 4 | 1472 | 1472x740x740 | 7.844e+08 | 1.67 h | 8.36 h |
| 2 | 8 | 1536 | 772x772x772 | 4.459e+08 | 1.90 h | 9.50 h |
| 2 | 8 | 1600 | 804x804x804 | 5.044e+08 | 2.15 h | 10.75 h |
| 2 | 8 | 1664 | 836x836x836 | 5.677e+08 | 2.42 h | 12.10 h |
| 2 | 8 | 1728 | 868x868x868 | 6.361e+08 | 2.71 h | 13.56 h |
| 2 | 8 | 1792 | 900x900x900 | 7.097e+08 | 3.03 h | 15.13 h |
| 2 | 8 | 1856 | 932x932x932 | 7.889e+08 | 3.36 h | 16.81 h |
| 3 | 12 | 1920 | 964x964x648 | 5.849e+08 | 3.74 h | 18.70 h |
| 3 | 12 | 1984 | 996x996x670 | 6.462e+08 | 4.13 h | 20.66 h |
| 3 | 12 | 2048 | 1028x1028x691 | 7.106e+08 | 4.54 h | 22.72 h |
| 3 | 12 | 2112 | 1060x1060x712 | 7.791e+08 | 4.98 h | 24.91 h |
| 4 | 16 | 2176 | 1092x1092x552 | 6.392e+08 | 5.45 h | 27.25 h |
| 4 | 16 | 2240 | 1124x1124x568 | 6.975e+08 | 5.95 h | 29.73 h |
| 4 | 16 | 2304 | 1156x1156x584 | 7.591e+08 | 6.47 h | 32.36 h |
| 4 | 16 | 2368 | 1188x1188x600 | 8.243e+08 | 7.03 h | 35.13 h |
| 5 | 20 | 2432 | 1220x1220x495 | 7.154e+08 | 7.62 h | 38.11 h |
| 5 | 20 | 2496 | 1252x1252x508 | 7.738e+08 | 8.24 h | 41.22 h |
| 6 | 24 | 2560 | 1284x1284x435 | 6.952e+08 | 8.89 h | 44.45 h |
| 6 | 24 | 2624 | 1316x883x664 | 7.508e+08 | 9.60 h | 48.00 h |
| 6 | 24 | 2688 | 1348x1348x456 | 8.044e+08 | 10.29 h | 51.43 h |
| 7 | 27 | 2752 | 926x926x926 | 7.736e+08 | 11.13 h | 55.64 h |
| 7 | 27 | 2816 | 947x947x947 | 8.279e+08 | 11.91 h | 59.55 h |
| 8 | 30 | 2880 | 1444x968x584 | 7.941e+08 | 12.69 h | 63.46 h |
| 8 | 32 | 2944 | 1476x744x744 | 7.952e+08 | 13.56 h | 67.79 h |

## Coletabilidade por walltime (1 rep DEVE caber inteiro; reps espalhaveis entre alocacoes via checkpoint)

| Walltime | Configs coletaveis (1 rep) | Maior N coletavel por num de nos |
|---------:|:--------------------------:|:---------------------------------|
| 2h | 13/35 | 1no:N<=1472, 2no:N<=1536 |
| 4h | 19/35 | 1no:N<=1472, 2no:N<=1856, 3no:N<=1920 |
| 6h | 24/35 | 1no:N<=1472, 2no:N<=1856, 3no:N<=2112, 4no:N<=2240 |
| 12h | 33/35 | 1no:N<=1472, 2no:N<=1856, 3no:N<=2112, 4no:N<=2368, 5no:N<=2496, 6no:N<=2688, 7no:N<=2816 |
| 24h | 35/35 | 1no:N<=1472, 2no:N<=1856, 3no:N<=2112, 4no:N<=2368, 5no:N<=2496, 6no:N<=2688, 7no:N<=2816, 8no:N<=2944 |

## Classificacao por MECANISMO de inviabilidade (dois mecanismos DISTINTOS)

**Mecanismo A -- DEADLOCK do gather sob 1gbit (Causa 1):**
- Afeta APENAS linhas MULTI-NO em 1gbit (o gather de ~1.8-3.2GB/worker cruza a NIC moldada pelo tc).
- 23 configs multi-no x 1 banda = **23 linhas INVIAVEIS em QUALQUER walltime** (nunca alcancam MPI_Finalize).
- Confirmado empiricamente na escala real (N=1536, ~1.8GB): 1gbit trava; 10gbit e 25gbit NAO.
- Single-no em 1gbit NAO deadlocka (gather intra-no via sm/self, nao toca o tc).

**Mecanismo B -- Finalization O(voxels) serial (Causa 2):**
- Afeta TODAS as linhas (single e multi-no), independente de banda; nao trava, apenas DEMORA.
- Inviabilidade e relativa ao walltime: 1 rep tem de caber inteiro (nao fracionavel).
- Piora com mais maquinas nesta campanha (Num_GPUs x voxels/worker ambos crescem): 1.9h (2 nos) -> 13.6h (8 nos).

**Resumo das 105 linhas:**
- 36 linhas single-no (12 configs x3): sem deadlock; viabilidade so por Finalization (todas <=1.67h/rep -> coletaveis ate em 2h).
- 23 linhas multi-no 1gbit: INVIAVEIS por DEADLOCK (Mecanismo A).
- 46 linhas multi-no 10/25gbit: viabilidade por Finalization (Mecanismo B) -- ver tabela de walltime.

## Nota critica (nao superinterpretar)
A metrica cientifica (total_time/msamples_per_s, janela MPI_Irecv->MPI_Waitall) e calculada ANTES
da Finalization (main.c:186). Nas linhas inviaveis por Mecanismo B, o DADO existe internamente;
o que estoura o walltime e apenas a IMPRESSAO/coleta apos a escrita. Ja no Mecanismo A (deadlock 1gbit),
o processo pode nem chegar ao fim das iteracoes de forma limpa em reps contaminados -- mas em estado limpo
as iteracoes completam e o travamento e so na fase de gather (portanto total_time TAMBEM ja foi calculado).
