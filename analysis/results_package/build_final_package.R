# Assembles the final ordered package: 1) tabelas completas, 2) estatísticas,
# 3) comparações, 4) tendências, 5) placeholders, 6) legendas, 7) figuras.
suppressMessages(library(tidyverse))
suppressMessages(library(knitr))

tab_dir <- "analysis/results_package/tables"
fig_dir <- "analysis/results_package/figures"
out_md <- "analysis/results_package/RESULTADOS_PACOTE.md"

part1 <- read_csv(file.path(tab_dir, "part1_statistics.csv"), show_col_types = FALSE)
part2 <- read_csv(file.path(tab_dir, "part2_band_gains.csv"), show_col_types = FALSE)
part3_raw <- read_csv(file.path(tab_dir, "part3_scaling_raw.csv"), show_col_types = FALSE)
part3_steps <- read_csv(file.path(tab_dir, "part3_scaling_steps.csv"), show_col_types = FALSE)
part3_slopes <- read_csv(file.path(tab_dir, "part3_scaling_slopes.csv"), show_col_types = FALSE)
trend_lines <- readLines(file.path(tab_dir, "part4_trends.txt"))
placeholders <- readLines(file.path(tab_dir, "part6_placeholders.md"))
amp <- read_csv(file.path(tab_dir, "part4_amplitude_by_topology.csv"), show_col_types = FALSE)
suff <- read_csv(file.path(tab_dir, "part4_10gbit_vs_25gbit.csv"), show_col_types = FALSE)
inv <- read_csv(file.path(tab_dir, "part4_order_inversion_10v25_throughput.csv"), show_col_types = FALSE)
outl <- read_csv(file.path(tab_dir, "part4_outliers_zscore_gt2.csv"), show_col_types = FALSE)

md <- c()
w <- function(...) md <<- c(md, ...)
kbl <- function(df, digits = 3) paste(kable(df, digits = digits, format = "pipe"), collapse = "\n")

w("# Pacote de evidências experimentais — Seção 5 (Resultados)")
w("")
w("Gerado a partir de dados medidos (campanha em `chuc-2, chuc-3, chuc-7, chuc-8`, ")
w("job OAR 2177765, e execuções anteriores de 3 nós já presentes em `g5k/results/`).")
w("Nenhum valor abaixo é estimado ou interpolado. Todas as combinações têm n=5 repetições ")
w("`checkpoint_status == \"done\"` para throughput e n=5 janelas de trace válidas para Masking Effectiveness.")
w("")
w("Problemas-âncora: 1 nó/N=1344 (4 GPUs), 2 nós/N=1728 (8 GPUs), 3 nós/N=1920 (12 GPUs), 4 nós/N=2176 (16 GPUs).")
w("Um quinto anchor (5 nós/N=2340, 20 GPUs, derivado pelo mesmo critério de ocupação")
w("de VRAM) já está definido em `g5k/csv/experimentos.csv`, mas a campanha ainda não")
w("rodou (bloqueada duas vezes pelo escalonador do Grid'5000 concedendo menos de 5 nós")
w("chuc) — portanto não aparece nas tabelas/figuras abaixo.")
w("")
w("---")
w("")

# ===================================================================
w("## 1. Tabelas completas")
w("")
w("Tabela completa por combinação (nós × banda): throughput e Masking Effectiveness,")
w("com média, desvio padrão, IC95%, mínimo, máximo, coeficiente de variação e n.")
w("")
t1 <- part1 |>
  transmute(
    Nós = nodes, Banda = band, N = N, n = n,
    `Throughput médio (MSamples/s)` = mean_msamples,
    `DP throughput` = sd_msamples, `IC95 throughput` = ci95_msamples,
    `Throughput mín.` = min_msamples, `Throughput máx.` = max_msamples,
    `CV throughput (%)` = cv_msamples_pct,
    `ME média (%)` = 100 * mean_me, `DP ME (pp)` = 100 * sd_me, `IC95 ME (pp)` = 100 * ci95_me,
    `ME mín. (%)` = 100 * min_me, `ME máx. (%)` = 100 * max_me, `CV ME (%)` = cv_me_pct
  )
w(kbl(t1))
w("")
write_csv(t1, file.path(tab_dir, "TABELA_1_completa.csv"))

w("---")
w("")

# ===================================================================
w("## 2. Estatísticas (leitura condensada)")
w("")
w("Mesmos dados da Tabela 1, formatados como \"média ± IC95%\" para citação direta no texto.")
w("")
t2 <- part1 |>
  transmute(
    Nós = nodes, Banda = band,
    `Throughput (MSamples/s)` = sprintf("%.1f ± %.1f", mean_msamples, ci95_msamples),
    `Masking Effectiveness (%)` = sprintf("%.1f ± %.1f pp", 100 * mean_me, 100 * ci95_me),
    `n` = n
  )
w(kbl(t2, digits = 1))
w("")
write_csv(t2, file.path(tab_dir, "TABELA_2_condensada.csv"))

w("---")
w("")

# ===================================================================
w("## 3. Comparações quantitativas")
w("")
w("### 3.1 Ganhos por transição de banda, por topologia")
w("")
t3a <- part2 |>
  transmute(
    Nós = nodes,
    `Ganho thr 1→10 (%)` = thr_gain_1to10_pct, `Ganho thr 10→25 (%)` = thr_gain_10to25_pct,
    `Ganho thr 1→25 (%)` = thr_gain_1to25_pct, `Retornos thr (%)` = thr_diminishing_returns_pct,
    `Ganho ME 1→10 (%)` = me_gain_1to10_pct, `Ganho ME 10→25 (%)` = me_gain_10to25_pct,
    `Ganho ME 1→25 (%)` = me_gain_1to25_pct, `Retornos ME (%)` = me_diminishing_returns_pct
  )
w(kbl(t3a, digits = 1))
w("")
write_csv(t3a, file.path(tab_dir, "TABELA_3a_ganhos_banda.csv"))

w("### 3.2 Comparação entre escalas (throughput/GPU e ME por nó)")
w("")
t3b <- part3_raw |> transmute(Nós = nodes, Banda = band,
  `Throughput/GPU (MSamples/s)` = throughput_per_gpu, `ME média (%)` = 100 * mean_me)
w(kbl(t3b, digits = 1))
w("")
write_csv(t3b, file.path(tab_dir, "TABELA_3b_por_gpu.csv"))

w("### 3.3 Variação passo-a-passo entre topologias consecutivas")
w("")
t3c <- part3_steps |> transmute(
  Banda = band, Passo = step,
  `Throughput/GPU (MSamples/s)` = throughput_per_gpu,
  `Δ% throughput/GPU` = thr_per_gpu_pct_change, `Δ abs. throughput/GPU` = thr_per_gpu_abs_diff,
  `ME (%)` = 100 * mean_me, `Δ% ME` = me_pct_change, `Δ ME (pp)` = me_abs_diff_pp
)
w(kbl(t3c, digits = 1))
w("")
write_csv(t3c, file.path(tab_dir, "TABELA_3c_passos.csv"))

w("### 3.4 Inclinação da curva (regressão linear vs. número de nós)")
w("")
t3d <- part3_slopes |> transmute(
  Banda = band,
  `Slope thr/GPU (MSamples/s por nó)` = slope_throughput_per_gpu_per_node,
  `R² thr/GPU vs nós` = r2_throughput_per_gpu_vs_nodes,
  `Slope ME (pp por nó)` = slope_me_pp_per_node,
  `R² ME vs nós` = r2_me_vs_nodes
)
w(kbl(t3d, digits = 3))
w("")
write_csv(t3d, file.path(tab_dir, "TABELA_3d_slopes.csv"))

w("---")
w("")

# ===================================================================
w("## 4. Tendências observadas (descrição factual dos dados, sem interpretação)")
w("")
for (l in trend_lines) {
  if (nchar(l) > 0) w(paste0("- ", l))
}
w("")
w("**Nota sobre a razão de retornos decrescentes em 1 nó:** nessa topologia o ganho")
w("1→10 é próximo de zero (throughput) ou já próximo do teto (ME), então a razão")
w("(ganho 10→25)/(ganho 1→10) tem um denominador pequeno e produz valores percentuais")
w("grandes ou de sinal instável (ex.: -138,3% para ME). Isso é um efeito aritmético do")
w("denominador pequeno, não um sinal de retorno decrescente maior do que nas demais")
w("topologias — visível diretamente comparando as colunas de ganho absoluto (pp) com")
w("as de razão percentual nas Tabelas 3a e a Figura 4.")
w("")
w("---")
w("")

# ===================================================================
w("## 5. Placeholders preenchidos")
w("")
w("```")
w(placeholders)
w("```")
w("")
w("---")
w("")

# ===================================================================
w("## 6. Legendas das figuras")
w("")
w("**Figura 1.** Composição temporal da execução (computação vs. comunicação MPI) nos")
w("doze experimentos-âncora (4 topologias × 3 bandas), organizada como matriz de")
w("painéis: **linhas = número de nós** (1, 2, 3 e 4 — 4, 8, 12 e 16 GPUs;")
w("N=1344/1728/1920/2176), **colunas = largura de banda** (1, 10 e 25 Gbit/s). O")
w("número de GPUs é omitido dos rótulos dos painéis por ser inteiramente determinado")
w("pelo número de nós nesta campanha.")
w("")
w("Dentro de cada painel há uma faixa horizontal por rank MPI (eixo y), subdividida ao")
w("longo do tempo em intervalos de igual duração; a altura de cada cor dentro de um")
w("intervalo é a **fração exata** daquele intervalo que o rank passou no estado")
w("correspondente. Amarelo = Compute; verde = MPI_Irecv; vermelho = MPI_Isend; azul =")
w("MPI_Waitall. Medido nos traços, MPI_Irecv e MPI_Isend somados respondem por")
w("0,0–0,4% de todo o tempo de comunicação (MPI_Waitall responde por 99,6–100%), de")
w("modo que sua fração é correspondentemente imperceptível — isso é fiel aos dados,")
w("não uma simplificação.")
w("")
w("O eixo horizontal é **normalizado para 0–100% da janela de medição** de cada")
w("execução, de forma que todos os doze painéis compartilhem a mesma escala temporal e")
w("as proporções mascarada/exposta sejam diretamente comparáveis; a duração absoluta")
w("correspondente está indicada na faixa clara no topo de cada painel, portanto não se")
w("perde essa informação. A janela é [primeiro MPI_Irecv, último MPI_Waitall] — a mesma")
w("usada no cálculo do Masking Effectiveness. Cada painel usa a repetição cuja duração")
w("total (`total_time`) é a mais próxima da mediana das 5 repetições daquela condição.")
w("Como linhas = nós (todos os painéis de uma linha têm a mesma contagem de rank), a")
w("faixa de tempo tem espessura física idêntica nos doze painéis.")
w("")
w("A subdivisão em intervalos (em vez de um retângulo por evento MPI) é uma exigência de")
w("fidelidade nesta escala: cada rank executa 200 ciclos de MPI_Waitall, o que corresponde")
w("a cerca de 0,010 pol por iteração na largura de painel usada — abaixo da resolução de")
w("impressão. Retângulos por evento seriam subpixel, e a fração de comunicação aparente")
w("passaria a depender do rasterizador do PDF e do nível de zoom, não dos dados. A")
w("subdivisão em intervalos é independente do renderizador e integra exatamente a mesma")
w("grandeza que a métrica de Masking Effectiveness (1 − razão de comunicação), apenas")
w("resolvida no tempo em vez de reduzida a um escalar.")
w("")
w("\"Compute\" é inferido como o complemento das chamadas MPI registradas dentro da janela,")
w("por rank — o traço Akypuera/PMPI instrumenta apenas chamadas MPI, sem um estado de")
w("\"Compute\" explícito.")
w("")
w("**Figura 2.** Masking Effectiveness (%) em função do número de nós, para os quatro")
w("problemas-âncora (N=1344/1728/1920/2176), uma curva por largura de banda. Pontos =")
w("médias de 5 repetições; linhas conectam os quatro problemas-âncora na ordem crescente")
w("de número de nós.")
w("")
w("**Figura 3.** Ganho relativo (%) de throughput e de Masking Effectiveness em cada")
w("transição de banda (1→10 Gbit/s e 10→25 Gbit/s), agrupado por topologia (1 a 4 nós).")
w("Cada painel corresponde a uma métrica (throughput à esquerda, Masking Effectiveness")
w("à direita); barras pareadas por topologia representam as duas transições.")
w("")
w("**Figura 4.** Razão entre o ganho da transição 10→25 Gbit/s e o ganho da transição")
w("1→10 Gbit/s, em percentual, por topologia, para throughput e Masking Effectiveness.")
w("Linha tracejada horizontal em 100% marca o caso em que as duas transições produziriam")
w("o mesmo ganho relativo; valores abaixo de 100% (incluindo negativos) indicam que a")
w("segunda transição de banda produziu um ganho relativo menor que a primeira.")
w("")
w("---")
w("")

# ===================================================================
w("## 7. Figuras geradas")
w("")
figs <- list.files(fig_dir, pattern = "\\.png$", full.names = FALSE)
for (f in sort(figs)) {
  w(sprintf("- `figures/%s` (e `.pdf` correspondente)", f))
}
w("")

writeLines(md, out_md)
cat(sprintf("Wrote final package to %s (%d lines)\n", out_md, length(md)))
