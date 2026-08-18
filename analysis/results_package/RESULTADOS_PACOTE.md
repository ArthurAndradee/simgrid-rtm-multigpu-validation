# Pacote de evidências experimentais — Seção 5 (Resultados)

Gerado a partir de dados medidos (campanha em `chuc-2, chuc-3, chuc-7, chuc-8`, 
job OAR 2177765, e execuções anteriores de 3 nós já presentes em `g5k/results/`).
Nenhum valor abaixo é estimado ou interpolado. Todas as combinações têm n=5 repetições 
`checkpoint_status == "done"` para throughput e n=5 janelas de trace válidas para Masking Effectiveness.

Problemas-âncora: 1 nó/N=1344 (4 GPUs), 2 nós/N=1728 (8 GPUs), 3 nós/N=1920 (12 GPUs), 4 nós/N=2176 (16 GPUs).
Um quinto anchor (5 nós/N=2340, 20 GPUs, derivado pelo mesmo critério de ocupação
de VRAM) já está definido em `g5k/csv/experimentos.csv`, mas a campanha ainda não
rodou (bloqueada duas vezes pelo escalonador do Grid'5000 concedendo menos de 5 nós
chuc) — portanto não aparece nas tabelas/figuras abaixo.

---

## 1. Tabelas completas

Tabela completa por combinação (nós × banda): throughput e Masking Effectiveness,
com média, desvio padrão, IC95%, mínimo, máximo, coeficiente de variação e n.

| Nós|Banda  |    N|  n| Throughput médio (MSamples/s)| DP throughput| IC95 throughput| Throughput mín.| Throughput máx.| CV throughput (%)| ME média (%)| DP ME (pp)| IC95 ME (pp)| ME mín. (%)| ME máx. (%)| CV ME (%)|
|---:|:------|----:|--:|-----------------------------:|-------------:|---------------:|---------------:|---------------:|-----------------:|------------:|----------:|------------:|-----------:|-----------:|---------:|
|   1|1gbit  | 1344|  5|                      3266.485|        80.617|         100.100|        3185.719|        3394.008|             2.468|       84.718|      0.718|        0.891|      83.940|      85.506|     0.847|
|   1|10gbit | 1344|  5|                      3325.836|        78.904|          97.972|        3201.704|        3395.632|             2.372|       83.734|      2.944|        3.655|      79.111|      86.199|     3.516|
|   1|25gbit | 1344|  5|                      3298.530|        40.205|          49.921|        3230.539|        3335.375|             1.219|       85.079|      2.390|        2.967|      81.269|      87.005|     2.809|
|   2|1gbit  | 1728|  5|                      4886.908|       112.502|         139.689|        4770.636|        5047.778|             2.302|       44.915|      0.812|        1.009|      43.770|      45.849|     1.808|
|   2|10gbit | 1728|  5|                      7783.177|       136.902|         169.986|        7590.017|        7969.988|             1.759|       78.291|      2.320|        2.881|      75.737|      81.858|     2.963|
|   2|25gbit | 1728|  5|                      7397.968|       603.886|         749.824|        6530.861|        7903.514|             8.163|       74.440|      5.325|        6.612|      66.638|      78.447|     7.153|
|   3|1gbit  | 1920|  5|                      2863.048|         4.917|           6.105|        2857.693|        2869.903|             0.172|       28.904|      0.256|        0.317|      28.611|      29.291|     0.884|
|   3|10gbit | 1920|  5|                      5915.698|       115.152|         142.980|        5763.287|        6033.766|             1.947|       62.225|      0.612|        0.759|      61.280|      62.990|     0.983|
|   3|25gbit | 1920|  5|                      5960.805|        60.277|          74.844|        5885.803|        6023.780|             1.011|       63.079|      0.347|        0.431|      62.630|      63.531|     0.551|
|   4|1gbit  | 2176|  5|                      3445.934|        32.820|          40.752|        3396.353|        3472.526|             0.952|       26.165|      0.178|        0.220|      25.853|      26.286|     0.679|
|   4|10gbit | 2176|  5|                      8107.012|       317.958|         394.797|        7577.768|        8431.834|             3.922|       63.713|      2.066|        2.565|      60.241|      65.424|     3.243|
|   4|25gbit | 2176|  5|                      8054.030|       199.683|         247.940|        7816.671|        8337.159|             2.479|       64.323|      1.638|        2.034|      62.023|      66.263|     2.547|

---

## 2. Estatísticas (leitura condensada)

Mesmos dados da Tabela 1, formatados como "média ± IC95%" para citação direta no texto.

| Nós|Banda  |Throughput (MSamples/s) |Masking Effectiveness (%) |  n|
|---:|:------|:-----------------------|:-------------------------|--:|
|   1|1gbit  |3266.5 ± 100.1          |84.7 ± 0.9 pp             |  5|
|   1|10gbit |3325.8 ± 98.0           |83.7 ± 3.7 pp             |  5|
|   1|25gbit |3298.5 ± 49.9           |85.1 ± 3.0 pp             |  5|
|   2|1gbit  |4886.9 ± 139.7          |44.9 ± 1.0 pp             |  5|
|   2|10gbit |7783.2 ± 170.0          |78.3 ± 2.9 pp             |  5|
|   2|25gbit |7398.0 ± 749.8          |74.4 ± 6.6 pp             |  5|
|   3|1gbit  |2863.0 ± 6.1            |28.9 ± 0.3 pp             |  5|
|   3|10gbit |5915.7 ± 143.0          |62.2 ± 0.8 pp             |  5|
|   3|25gbit |5960.8 ± 74.8           |63.1 ± 0.4 pp             |  5|
|   4|1gbit  |3445.9 ± 40.8           |26.2 ± 0.2 pp             |  5|
|   4|10gbit |8107.0 ± 394.8          |63.7 ± 2.6 pp             |  5|
|   4|25gbit |8054.0 ± 247.9          |64.3 ± 2.0 pp             |  5|

---

## 3. Comparações quantitativas

### 3.1 Ganhos por transição de banda, por topologia

| Nós| Ganho thr 1→10 (%)| Ganho thr 10→25 (%)| Ganho thr 1→25 (%)| Retornos thr (%)| Ganho ME 1→10 (%)| Ganho ME 10→25 (%)| Ganho ME 1→25 (%)| Retornos ME (%)|
|---:|------------------:|-------------------:|------------------:|----------------:|-----------------:|------------------:|-----------------:|---------------:|
|   1|                1.8|                -0.8|                1.0|            -45.2|              -1.2|                1.6|               0.4|          -138.3|
|   2|               59.3|                -4.9|               51.4|             -8.4|              74.3|               -4.9|              65.7|            -6.6|
|   3|              106.6|                 0.8|              108.2|              0.7|             115.3|                1.4|             118.2|             1.2|
|   4|              135.3|                -0.7|              133.7|             -0.5|             143.5|                1.0|             145.8|             0.7|

### 3.2 Comparação entre escalas (throughput/GPU e ME por nó)

| Nós|Banda  | Throughput/GPU (MSamples/s)| ME média (%)|
|---:|:------|---------------------------:|------------:|
|   1|1gbit  |                       816.6|         84.7|
|   2|1gbit  |                       610.9|         44.9|
|   3|1gbit  |                       238.6|         28.9|
|   4|1gbit  |                       215.4|         26.2|
|   1|10gbit |                       831.5|         83.7|
|   2|10gbit |                       972.9|         78.3|
|   3|10gbit |                       493.0|         62.2|
|   4|10gbit |                       506.7|         63.7|
|   1|25gbit |                       824.6|         85.1|
|   2|25gbit |                       924.7|         74.4|
|   3|25gbit |                       496.7|         63.1|
|   4|25gbit |                       503.4|         64.3|

### 3.3 Variação passo-a-passo entre topologias consecutivas

|Banda  |Passo | Throughput/GPU (MSamples/s)| Δ% throughput/GPU| Δ abs. throughput/GPU| ME (%)| Δ% ME| Δ ME (pp)|
|:------|:-----|---------------------------:|-----------------:|---------------------:|------:|-----:|---------:|
|10gbit |1->2  |                       972.9|              17.0|                 141.4|   78.3|  -6.5|      -5.4|
|10gbit |2->3  |                       493.0|             -49.3|                -479.9|   62.2| -20.5|     -16.1|
|10gbit |3->4  |                       506.7|               2.8|                  13.7|   63.7|   2.4|       1.5|
|1gbit  |1->2  |                       610.9|             -25.2|                -205.8|   44.9| -47.0|     -39.8|
|1gbit  |2->3  |                       238.6|             -60.9|                -372.3|   28.9| -35.6|     -16.0|
|1gbit  |3->4  |                       215.4|              -9.7|                 -23.2|   26.2|  -9.5|      -2.7|
|25gbit |1->2  |                       924.7|              12.1|                 100.1|   74.4| -12.5|     -10.6|
|25gbit |2->3  |                       496.7|             -46.3|                -428.0|   63.1| -15.3|     -11.4|
|25gbit |3->4  |                       503.4|               1.3|                   6.6|   64.3|   2.0|       1.2|

### 3.4 Inclinação da curva (regressão linear vs. número de nós)

|Banda  | Slope thr/GPU (MSamples/s por nó)| R² thr/GPU vs nós| Slope ME (pp por nó)| R² ME vs nós|
|:------|---------------------------------:|-----------------:|--------------------:|------------:|
|10gbit |                          -145.423|             0.615|               -7.613|        0.849|
|1gbit  |                          -217.603|             0.916|              -19.167|        0.840|
|25gbit |                          -139.178|             0.666|               -7.363|        0.860|

---

## 4. Tendências observadas (descrição factual dos dados, sem interpretação)

- Amplitude de Masking Effectiveness entre bandas, por topologia (pp = pontos percentuais): 1 nó(s)=1.3pp; 2 nó(s)=33.4pp; 3 nó(s)=34.2pp; 4 nó(s)=38.2pp
- Maior IC95 individual de ME (pp) por topologia, para referencia de ruido de medicao: 1 nó(s)=3.66pp; 2 nó(s)=6.61pp; 3 nó(s)=0.76pp; 4 nó(s)=2.57pp
- Primeira topologia em que a amplitude de ME entre bandas excede o maior IC95 individual observado naquela topologia: 2 nó(s) (amplitude=33.4pp > IC95=6.61pp)
- Variacao da amplitude de ME (pp) de uma topologia para a seguinte: 1->2 nós: +32.0pp; 2->3 nós: +0.8pp; 3->4 nós: +4.0pp
- Maior crescimento de amplitude ocorre no passo 1->2 nós (+32.0pp)
- [1 Gbit/s] Variacao percentual do throughput/GPU por passo de escala: 1->2: -25.2%; 2->3: -60.9%; 3->4: -9.7%
- [1 Gbit/s] Variacao absoluta de ME (pp) por passo de escala: 1->2: -39.8pp; 2->3: -16.0pp; 3->4: -2.7pp
- [10 Gbit/s] Variacao percentual do throughput/GPU por passo de escala: 1->2: +17.0%; 2->3: -49.3%; 3->4: +2.8%
- [10 Gbit/s] Variacao absoluta de ME (pp) por passo de escala: 1->2: -5.4pp; 2->3: -16.1pp; 3->4: +1.5pp
- [25 Gbit/s] Variacao percentual do throughput/GPU por passo de escala: 1->2: +12.1%; 2->3: -46.3%; 3->4: +1.3%
- [25 Gbit/s] Variacao absoluta de ME (pp) por passo de escala: 1->2: -10.6pp; 2->3: -11.4pp; 3->4: +1.2pp
- R^2 do ajuste linear (throughput/GPU vs numero de nos) por banda: 10 Gbit/s=0.615; 1 Gbit/s=0.916; 25 Gbit/s=0.666
- R^2 do ajuste linear (ME vs numero de nos) por banda: 10 Gbit/s=0.849; 1 Gbit/s=0.840; 25 Gbit/s=0.860
- Razao (ganho 10->25) / (ganho 1->10), throughput, por topologia: 1 nó(s)=-45.2%; 2 nó(s)=-8.4%; 3 nó(s)=0.7%; 4 nó(s)=-0.5%
- Razao (ganho 10->25) / (ganho 1->10), Masking Effectiveness, por topologia: 1 nó(s)=-138.3%; 2 nó(s)=-6.6%; 3 nó(s)=1.2%; 4 nó(s)=0.7%
- Diferenca de ME entre 10gbit e 25gbit (pp), por topologia, e se fica dentro do IC95: 1 nó(s): +1.35pp (IC95max=3.66pp, dentro=TRUE); 2 nó(s): -3.85pp (IC95max=6.61pp, dentro=TRUE); 3 nó(s): +0.85pp (IC95max=0.76pp, dentro=FALSE); 4 nó(s): +0.61pp (IC95max=2.57pp, dentro=TRUE)
- Inversao de ordem (throughput 10gbit > 25gbit, valor medio) observada em: 1 nó(s) (10gbit=3325.8 MSamples/s > 25gbit=3298.5 MSamples/s, diff=27.3); 2 nó(s) (10gbit=7783.2 MSamples/s > 25gbit=7398.0 MSamples/s, diff=385.2); 4 nó(s) (10gbit=8107.0 MSamples/s > 25gbit=8054.0 MSamples/s, diff=53.0)
- Combinacoes (nos, banda) com Masking Effectiveness medio < 0.5: 2 nó(s)/1 Gbit/s (ME=0.449); 3 nó(s)/1 Gbit/s (ME=0.289); 4 nó(s)/1 Gbit/s (ME=0.262)
- Repeticoes com |z-score| > 2 dentro do proprio experiment_id (n=5, portanto criterio exploratorio, nao um teste formal): nenhuma detectada

**Nota sobre a razão de retornos decrescentes em 1 nó:** nessa topologia o ganho
1→10 é próximo de zero (throughput) ou já próximo do teto (ME), então a razão
(ganho 10→25)/(ganho 1→10) tem um denominador pequeno e produz valores percentuais
grandes ou de sinal instável (ex.: -138,3% para ME). Isso é um efeito aritmético do
denominador pequeno, não um sinal de retorno decrescente maior do que nas demais
topologias — visível diretamente comparando as colunas de ganho absoluto (pp) com
as de razão percentual nas Tabelas 3a e a Figura 4.

---

## 5. Placeholders preenchidos

```

=== Throughput e Masking Effectiveness por (nós, banda) ===

<throughput_1node_1gbit> = 3266.5 MSamples/s
<throughput_ci95_1node_1gbit> = ±100.10 MSamples/s
<throughput_sd_1node_1gbit> = 80.62 MSamples/s
<throughput_min_1node_1gbit> = 3185.7 MSamples/s
<throughput_max_1node_1gbit> = 3394.0 MSamples/s
<throughput_cv_1node_1gbit> = 2.47%
<total_time_1node_1gbit> = 73.0 s
<total_time_ci95_1node_1gbit> = ±2.20 s
<masking_eff_1node_1gbit> = 84.7%
<masking_eff_ci95_1node_1gbit> = ±0.89 pp
<masking_eff_sd_1node_1gbit> = 0.72 pp
<masking_eff_min_1node_1gbit> = 83.9%
<masking_eff_max_1node_1gbit> = 85.5%
<masking_eff_cv_1node_1gbit> = 0.85%
<n_reps_1node_1gbit> = 5
<throughput_1node_10gbit> = 3325.8 MSamples/s
<throughput_ci95_1node_10gbit> = ±97.97 MSamples/s
<throughput_sd_1node_10gbit> = 78.90 MSamples/s
<throughput_min_1node_10gbit> = 3201.7 MSamples/s
<throughput_max_1node_10gbit> = 3395.6 MSamples/s
<throughput_cv_1node_10gbit> = 2.37%
<total_time_1node_10gbit> = 71.7 s
<total_time_ci95_1node_10gbit> = ±2.15 s
<masking_eff_1node_10gbit> = 83.7%
<masking_eff_ci95_1node_10gbit> = ±3.66 pp
<masking_eff_sd_1node_10gbit> = 2.94 pp
<masking_eff_min_1node_10gbit> = 79.1%
<masking_eff_max_1node_10gbit> = 86.2%
<masking_eff_cv_1node_10gbit> = 3.52%
<n_reps_1node_10gbit> = 5
<throughput_1node_25gbit> = 3298.5 MSamples/s
<throughput_ci95_1node_25gbit> = ±49.92 MSamples/s
<throughput_sd_1node_25gbit> = 40.20 MSamples/s
<throughput_min_1node_25gbit> = 3230.5 MSamples/s
<throughput_max_1node_25gbit> = 3335.4 MSamples/s
<throughput_cv_1node_25gbit> = 1.22%
<total_time_1node_25gbit> = 72.3 s
<total_time_ci95_1node_25gbit> = ±1.11 s
<masking_eff_1node_25gbit> = 85.1%
<masking_eff_ci95_1node_25gbit> = ±2.97 pp
<masking_eff_sd_1node_25gbit> = 2.39 pp
<masking_eff_min_1node_25gbit> = 81.3%
<masking_eff_max_1node_25gbit> = 87.0%
<masking_eff_cv_1node_25gbit> = 2.81%
<n_reps_1node_25gbit> = 5
<throughput_2node_1gbit> = 4886.9 MSamples/s
<throughput_ci95_2node_1gbit> = ±139.69 MSamples/s
<throughput_sd_2node_1gbit> = 112.50 MSamples/s
<throughput_min_2node_1gbit> = 4770.6 MSamples/s
<throughput_max_2node_1gbit> = 5047.8 MSamples/s
<throughput_cv_2node_1gbit> = 2.30%
<total_time_2node_1gbit> = 104.2 s
<total_time_ci95_2node_1gbit> = ±2.95 s
<masking_eff_2node_1gbit> = 44.9%
<masking_eff_ci95_2node_1gbit> = ±1.01 pp
<masking_eff_sd_2node_1gbit> = 0.81 pp
<masking_eff_min_2node_1gbit> = 43.8%
<masking_eff_max_2node_1gbit> = 45.8%
<masking_eff_cv_2node_1gbit> = 1.81%
<n_reps_2node_1gbit> = 5
<throughput_2node_10gbit> = 7783.2 MSamples/s
<throughput_ci95_2node_10gbit> = ±169.99 MSamples/s
<throughput_sd_2node_10gbit> = 136.90 MSamples/s
<throughput_min_2node_10gbit> = 7590.0 MSamples/s
<throughput_max_2node_10gbit> = 7970.0 MSamples/s
<throughput_cv_2node_10gbit> = 1.76%
<total_time_2node_10gbit> = 65.4 s
<total_time_ci95_2node_10gbit> = ±1.43 s
<masking_eff_2node_10gbit> = 78.3%
<masking_eff_ci95_2node_10gbit> = ±2.88 pp
<masking_eff_sd_2node_10gbit> = 2.32 pp
<masking_eff_min_2node_10gbit> = 75.7%
<masking_eff_max_2node_10gbit> = 81.9%
<masking_eff_cv_2node_10gbit> = 2.96%
<n_reps_2node_10gbit> = 5
<throughput_2node_25gbit> = 7398.0 MSamples/s
<throughput_ci95_2node_25gbit> = ±749.82 MSamples/s
<throughput_sd_2node_25gbit> = 603.89 MSamples/s
<throughput_min_2node_25gbit> = 6530.9 MSamples/s
<throughput_max_2node_25gbit> = 7903.5 MSamples/s
<throughput_cv_2node_25gbit> = 8.16%
<total_time_2node_25gbit> = 69.2 s
<total_time_ci95_2node_25gbit> = ±7.35 s
<masking_eff_2node_25gbit> = 74.4%
<masking_eff_ci95_2node_25gbit> = ±6.61 pp
<masking_eff_sd_2node_25gbit> = 5.32 pp
<masking_eff_min_2node_25gbit> = 66.6%
<masking_eff_max_2node_25gbit> = 78.4%
<masking_eff_cv_2node_25gbit> = 7.15%
<n_reps_2node_25gbit> = 5
<throughput_3node_1gbit> = 2863.0 MSamples/s
<throughput_ci95_3node_1gbit> = ±6.10 MSamples/s
<throughput_sd_3node_1gbit> = 4.92 MSamples/s
<throughput_min_3node_1gbit> = 2857.7 MSamples/s
<throughput_max_3node_1gbit> = 2869.9 MSamples/s
<throughput_cv_3node_1gbit> = 0.17%
<total_time_3node_1gbit> = 244.1 s
<total_time_ci95_3node_1gbit> = ±0.52 s
<masking_eff_3node_1gbit> = 28.9%
<masking_eff_ci95_3node_1gbit> = ±0.32 pp
<masking_eff_sd_3node_1gbit> = 0.26 pp
<masking_eff_min_3node_1gbit> = 28.6%
<masking_eff_max_3node_1gbit> = 29.3%
<masking_eff_cv_3node_1gbit> = 0.88%
<n_reps_3node_1gbit> = 5
<throughput_3node_10gbit> = 5915.7 MSamples/s
<throughput_ci95_3node_10gbit> = ±142.98 MSamples/s
<throughput_sd_3node_10gbit> = 115.15 MSamples/s
<throughput_min_3node_10gbit> = 5763.3 MSamples/s
<throughput_max_3node_10gbit> = 6033.8 MSamples/s
<throughput_cv_3node_10gbit> = 1.95%
<total_time_3node_10gbit> = 118.2 s
<total_time_ci95_3node_10gbit> = ±2.86 s
<masking_eff_3node_10gbit> = 62.2%
<masking_eff_ci95_3node_10gbit> = ±0.76 pp
<masking_eff_sd_3node_10gbit> = 0.61 pp
<masking_eff_min_3node_10gbit> = 61.3%
<masking_eff_max_3node_10gbit> = 63.0%
<masking_eff_cv_3node_10gbit> = 0.98%
<n_reps_3node_10gbit> = 5
<throughput_3node_25gbit> = 5960.8 MSamples/s
<throughput_ci95_3node_25gbit> = ±74.84 MSamples/s
<throughput_sd_3node_25gbit> = 60.28 MSamples/s
<throughput_min_3node_25gbit> = 5885.8 MSamples/s
<throughput_max_3node_25gbit> = 6023.8 MSamples/s
<throughput_cv_3node_25gbit> = 1.01%
<total_time_3node_25gbit> = 117.3 s
<total_time_ci95_3node_25gbit> = ±1.47 s
<masking_eff_3node_25gbit> = 63.1%
<masking_eff_ci95_3node_25gbit> = ±0.43 pp
<masking_eff_sd_3node_25gbit> = 0.35 pp
<masking_eff_min_3node_25gbit> = 62.6%
<masking_eff_max_3node_25gbit> = 63.5%
<masking_eff_cv_3node_25gbit> = 0.55%
<n_reps_3node_25gbit> = 5
<throughput_4node_1gbit> = 3445.9 MSamples/s
<throughput_ci95_4node_1gbit> = ±40.75 MSamples/s
<throughput_sd_4node_1gbit> = 32.82 MSamples/s
<throughput_min_4node_1gbit> = 3396.4 MSamples/s
<throughput_max_4node_1gbit> = 3472.5 MSamples/s
<throughput_cv_4node_1gbit> = 0.95%
<total_time_4node_1gbit> = 295.7 s
<total_time_ci95_4node_1gbit> = ±3.52 s
<masking_eff_4node_1gbit> = 26.2%
<masking_eff_ci95_4node_1gbit> = ±0.22 pp
<masking_eff_sd_4node_1gbit> = 0.18 pp
<masking_eff_min_4node_1gbit> = 25.9%
<masking_eff_max_4node_1gbit> = 26.3%
<masking_eff_cv_4node_1gbit> = 0.68%
<n_reps_4node_1gbit> = 5
<throughput_4node_10gbit> = 8107.0 MSamples/s
<throughput_ci95_4node_10gbit> = ±394.80 MSamples/s
<throughput_sd_4node_10gbit> = 317.96 MSamples/s
<throughput_min_4node_10gbit> = 7577.8 MSamples/s
<throughput_max_4node_10gbit> = 8431.8 MSamples/s
<throughput_cv_4node_10gbit> = 3.92%
<total_time_4node_10gbit> = 125.9 s
<total_time_ci95_4node_10gbit> = ±6.35 s
<masking_eff_4node_10gbit> = 63.7%
<masking_eff_ci95_4node_10gbit> = ±2.57 pp
<masking_eff_sd_4node_10gbit> = 2.07 pp
<masking_eff_min_4node_10gbit> = 60.2%
<masking_eff_max_4node_10gbit> = 65.4%
<masking_eff_cv_4node_10gbit> = 3.24%
<n_reps_4node_10gbit> = 5
<throughput_4node_25gbit> = 8054.0 MSamples/s
<throughput_ci95_4node_25gbit> = ±247.94 MSamples/s
<throughput_sd_4node_25gbit> = 199.68 MSamples/s
<throughput_min_4node_25gbit> = 7816.7 MSamples/s
<throughput_max_4node_25gbit> = 8337.2 MSamples/s
<throughput_cv_4node_25gbit> = 2.48%
<total_time_4node_25gbit> = 126.6 s
<total_time_ci95_4node_25gbit> = ±3.87 s
<masking_eff_4node_25gbit> = 64.3%
<masking_eff_ci95_4node_25gbit> = ±2.03 pp
<masking_eff_sd_4node_25gbit> = 1.64 pp
<masking_eff_min_4node_25gbit> = 62.0%
<masking_eff_max_4node_25gbit> = 66.3%
<masking_eff_cv_4node_25gbit> = 2.55%
<n_reps_4node_25gbit> = 5

=== Ganhos por transicao de banda, por topologia (Parte 2) ===

<relative_gain_1to10_thr_1node> = 1.8%
<relative_gain_10to25_thr_1node> = -0.8%
<relative_gain_1to25_thr_1node> = 1.0%
<diminishing_returns_thr_1node> = -45.2%
<relative_gain_1to10_me_1node> = -1.2%
<relative_gain_10to25_me_1node> = 1.6%
<relative_gain_1to25_me_1node> = 0.4%
<diminishing_returns_me_1node> = -138.3%
<gain_1to10_me_pp_1node> = -1.0 pp
<gain_10to25_me_pp_1node> = 1.3 pp
<gain_1to25_me_pp_1node> = 0.4 pp
<relative_gain_1to10_thr_2node> = 59.3%
<relative_gain_10to25_thr_2node> = -4.9%
<relative_gain_1to25_thr_2node> = 51.4%
<diminishing_returns_thr_2node> = -8.4%
<relative_gain_1to10_me_2node> = 74.3%
<relative_gain_10to25_me_2node> = -4.9%
<relative_gain_1to25_me_2node> = 65.7%
<diminishing_returns_me_2node> = -6.6%
<gain_1to10_me_pp_2node> = 33.4 pp
<gain_10to25_me_pp_2node> = -3.9 pp
<gain_1to25_me_pp_2node> = 29.5 pp
<relative_gain_1to10_thr_3node> = 106.6%
<relative_gain_10to25_thr_3node> = 0.8%
<relative_gain_1to25_thr_3node> = 108.2%
<diminishing_returns_thr_3node> = 0.7%
<relative_gain_1to10_me_3node> = 115.3%
<relative_gain_10to25_me_3node> = 1.4%
<relative_gain_1to25_me_3node> = 118.2%
<diminishing_returns_me_3node> = 1.2%
<gain_1to10_me_pp_3node> = 33.3 pp
<gain_10to25_me_pp_3node> = 0.9 pp
<gain_1to25_me_pp_3node> = 34.2 pp
<relative_gain_1to10_thr_4node> = 135.3%
<relative_gain_10to25_thr_4node> = -0.7%
<relative_gain_1to25_thr_4node> = 133.7%
<diminishing_returns_thr_4node> = -0.5%
<relative_gain_1to10_me_4node> = 143.5%
<relative_gain_10to25_me_4node> = 1.0%
<relative_gain_1to25_me_4node> = 145.8%
<diminishing_returns_me_4node> = 0.7%
<gain_1to10_me_pp_4node> = 37.5 pp
<gain_10to25_me_pp_4node> = 0.6 pp
<gain_1to25_me_pp_4node> = 38.2 pp

=== Throughput por GPU (Parte 3) ===

<throughput_per_gpu_1node_1gbit> = 816.6 MSamples/s
<throughput_per_gpu_2node_1gbit> = 610.9 MSamples/s
<throughput_per_gpu_3node_1gbit> = 238.6 MSamples/s
<throughput_per_gpu_4node_1gbit> = 215.4 MSamples/s
<throughput_per_gpu_1node_10gbit> = 831.5 MSamples/s
<throughput_per_gpu_2node_10gbit> = 972.9 MSamples/s
<throughput_per_gpu_3node_10gbit> = 493.0 MSamples/s
<throughput_per_gpu_4node_10gbit> = 506.7 MSamples/s
<throughput_per_gpu_1node_25gbit> = 824.6 MSamples/s
<throughput_per_gpu_2node_25gbit> = 924.7 MSamples/s
<throughput_per_gpu_3node_25gbit> = 496.7 MSamples/s
<throughput_per_gpu_4node_25gbit> = 503.4 MSamples/s

=== Variacao passo-a-passo entre escalas (Parte 3) ===

<thr_per_gpu_pctchange_1to2_10gbit> = 17.0%
<thr_per_gpu_absdiff_1to2_10gbit> = 141.4 MSamples/s
<me_pctchange_1to2_10gbit> = -6.5%
<me_absdiff_pp_1to2_10gbit> = -5.4 pp
<thr_per_gpu_pctchange_2to3_10gbit> = -49.3%
<thr_per_gpu_absdiff_2to3_10gbit> = -479.9 MSamples/s
<me_pctchange_2to3_10gbit> = -20.5%
<me_absdiff_pp_2to3_10gbit> = -16.1 pp
<thr_per_gpu_pctchange_3to4_10gbit> = 2.8%
<thr_per_gpu_absdiff_3to4_10gbit> = 13.7 MSamples/s
<me_pctchange_3to4_10gbit> = 2.4%
<me_absdiff_pp_3to4_10gbit> = 1.5 pp
<thr_per_gpu_pctchange_1to2_1gbit> = -25.2%
<thr_per_gpu_absdiff_1to2_1gbit> = -205.8 MSamples/s
<me_pctchange_1to2_1gbit> = -47.0%
<me_absdiff_pp_1to2_1gbit> = -39.8 pp
<thr_per_gpu_pctchange_2to3_1gbit> = -60.9%
<thr_per_gpu_absdiff_2to3_1gbit> = -372.3 MSamples/s
<me_pctchange_2to3_1gbit> = -35.6%
<me_absdiff_pp_2to3_1gbit> = -16.0 pp
<thr_per_gpu_pctchange_3to4_1gbit> = -9.7%
<thr_per_gpu_absdiff_3to4_1gbit> = -23.2 MSamples/s
<me_pctchange_3to4_1gbit> = -9.5%
<me_absdiff_pp_3to4_1gbit> = -2.7 pp
<thr_per_gpu_pctchange_1to2_25gbit> = 12.1%
<thr_per_gpu_absdiff_1to2_25gbit> = 100.1 MSamples/s
<me_pctchange_1to2_25gbit> = -12.5%
<me_absdiff_pp_1to2_25gbit> = -10.6 pp
<thr_per_gpu_pctchange_2to3_25gbit> = -46.3%
<thr_per_gpu_absdiff_2to3_25gbit> = -428.0 MSamples/s
<me_pctchange_2to3_25gbit> = -15.3%
<me_absdiff_pp_2to3_25gbit> = -11.4 pp
<thr_per_gpu_pctchange_3to4_25gbit> = 1.3%
<thr_per_gpu_absdiff_3to4_25gbit> = 6.6 MSamples/s
<me_pctchange_3to4_25gbit> = 2.0%
<me_absdiff_pp_3to4_25gbit> = 1.2 pp

=== Inclinacao (slope) e ajuste linear (Parte 3) ===

<slope_thr_per_gpu_10gbit> = -145.42 MSamples/s por nó
<r2_thr_per_gpu_10gbit> = 0.615
<slope_me_10gbit> = -7.61 pp por nó
<r2_me_10gbit> = 0.849
<slope_thr_per_gpu_1gbit> = -217.60 MSamples/s por nó
<r2_thr_per_gpu_1gbit> = 0.916
<slope_me_1gbit> = -19.17 pp por nó
<r2_me_1gbit> = 0.840
<slope_thr_per_gpu_25gbit> = -139.18 MSamples/s por nó
<r2_thr_per_gpu_25gbit> = 0.666
<slope_me_25gbit> = -7.36 pp por nó
<r2_me_25gbit> = 0.860
```

---

## 6. Legendas das figuras

**Figura 1.** Composição temporal da execução (computação vs. comunicação MPI) nos
doze experimentos-âncora (4 topologias × 3 bandas), organizada como matriz de
painéis: **linhas = número de nós** (1, 2, 3 e 4 — 4, 8, 12 e 16 GPUs;
N=1344/1728/1920/2176), **colunas = largura de banda** (1, 10 e 25 Gbit/s). O
número de GPUs é omitido dos rótulos dos painéis por ser inteiramente determinado
pelo número de nós nesta campanha.

Dentro de cada painel há uma faixa horizontal por rank MPI (eixo y), subdividida ao
longo do tempo em intervalos de igual duração; a altura de cada cor dentro de um
intervalo é a **fração exata** daquele intervalo que o rank passou no estado
correspondente. Amarelo = Compute; verde = MPI_Irecv; vermelho = MPI_Isend; azul =
MPI_Waitall. Medido nos traços, MPI_Irecv e MPI_Isend somados respondem por
0,0–0,4% de todo o tempo de comunicação (MPI_Waitall responde por 99,6–100%), de
modo que sua fração é correspondentemente imperceptível — isso é fiel aos dados,
não uma simplificação.

O eixo horizontal é **normalizado para 0–100% da janela de medição** de cada
execução, de forma que todos os doze painéis compartilhem a mesma escala temporal e
as proporções mascarada/exposta sejam diretamente comparáveis; a duração absoluta
correspondente está indicada na faixa clara no topo de cada painel, portanto não se
perde essa informação. A janela é [primeiro MPI_Irecv, último MPI_Waitall] — a mesma
usada no cálculo do Masking Effectiveness. Cada painel usa a repetição cuja duração
total (`total_time`) é a mais próxima da mediana das 5 repetições daquela condição.
Como linhas = nós (todos os painéis de uma linha têm a mesma contagem de rank), a
faixa de tempo tem espessura física idêntica nos doze painéis.

A subdivisão em intervalos (em vez de um retângulo por evento MPI) é uma exigência de
fidelidade nesta escala: cada rank executa 200 ciclos de MPI_Waitall, o que corresponde
a cerca de 0,010 pol por iteração na largura de painel usada — abaixo da resolução de
impressão. Retângulos por evento seriam subpixel, e a fração de comunicação aparente
passaria a depender do rasterizador do PDF e do nível de zoom, não dos dados. A
subdivisão em intervalos é independente do renderizador e integra exatamente a mesma
grandeza que a métrica de Masking Effectiveness (1 − razão de comunicação), apenas
resolvida no tempo em vez de reduzida a um escalar.

"Compute" é inferido como o complemento das chamadas MPI registradas dentro da janela,
por rank — o traço Akypuera/PMPI instrumenta apenas chamadas MPI, sem um estado de
"Compute" explícito.

**Figura 2.** Masking Effectiveness (%) em função do número de nós, para os quatro
problemas-âncora (N=1344/1728/1920/2176), uma curva por largura de banda. Pontos =
médias de 5 repetições; linhas conectam os quatro problemas-âncora na ordem crescente
de número de nós.

**Figura 3.** Ganho relativo (%) de throughput e de Masking Effectiveness em cada
transição de banda (1→10 Gbit/s e 10→25 Gbit/s), agrupado por topologia (1 a 4 nós).
Cada painel corresponde a uma métrica (throughput à esquerda, Masking Effectiveness
à direita); barras pareadas por topologia representam as duas transições.

**Figura 4.** Razão entre o ganho da transição 10→25 Gbit/s e o ganho da transição
1→10 Gbit/s, em percentual, por topologia, para throughput e Masking Effectiveness.
Linha tracejada horizontal em 100% marca o caso em que as duas transições produziriam
o mesmo ganho relativo; valores abaixo de 100% (incluindo negativos) indicam que a
segunda transição de banda produziu um ganho relativo menor que a primeira.

---

## 7. Figuras geradas

- `figures/fig1_masking_timeline_matrix.png` (e `.pdf` correspondente)
- `figures/fig2_masking_effectiveness_vs_nodes.png` (e `.pdf` correspondente)
- `figures/fig3_relative_gain_by_band_transition.png` (e `.pdf` correspondente)
- `figures/fig4_diminishing_returns.png` (e `.pdf` correspondente)

