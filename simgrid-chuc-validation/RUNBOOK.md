# Runbook — amanhã, 17h10 (França), 1h30, 2 nós chuc

Reserva confirmada: job OAR **2185769** (`types = deploy`, 2 nós chuc, sem
kavlan — não precisamos, ver README.md).

## Estratégia de tempo

Os dois nós chuc reservados vão rodar **em paralelo desde o início**, não
um como fallback do outro: nó A faz 1 e 2 nós simulados, nó B faz 3 e 4 —
cada um mais barato que fazer os 4 em sequência num nó só. Se um dos dois
falhar (deploy, GPU degradada etc.), o outro sozinho ainda cobre metade dos
resultados a tempo, e dá pra decidir na hora se vale usar o resto do
walltime pra completar o que faltar nele.

## Passo a passo

```bash
# 1. No frontend (ssh frontend.lille.grid5000.fr) -- UMA VEZ só, cobre os 2 nós
export OAR_JOB_ID=2185769
export OAR_NODE_FILE=/var/lib/oar/2185769
cd ~/ic/io-research/distributed-cube-average
./simgrid-chuc-validation/deploy.sh
# mostra os 2 hostnames no final; anote como <NODE_A> e <NODE_B>

# 2. Em DOIS terminais separados, um por nó:
ssh root@<NODE_A>   # terminal 1
ssh root@<NODE_B>   # terminal 2

# 3. Em cada terminal (a home é NFS-compartilhada, o repo já está lá):
cd ~/ic/io-research/distributed-cube-average
nix-shell simgrid-chuc-validation/shell.nix

# 4. Rode a validação -- nó A faz 1,2; nó B faz 3,4
./simgrid-chuc-validation/run_validation.sh 1,2      # terminal 1 (NODE_A)
./simgrid-chuc-validation/run_validation.sh 3,4      # terminal 2 (NODE_B)

# 5. Depois que os dois terminarem, em QUALQUER lugar com a home montada
#    (não precisa ser dentro do nix-shell nem de um nó chuc):
exit  # sai do nix-shell, se ainda estiver nele
source /home/aandrade/miniconda/etc/profile.d/conda.sh
conda activate r-analysis
Rscript simgrid-chuc-validation/compute_fidelity_error.R
```

## Se o tempo apertar

- `run_validation.sh` pula automaticamente qualquer `<nós>n_<banda>` que já
  tenha `dc.output` válido -- rodar de novo (no mesmo nó ou no outro) não
  repete trabalho.
- Se só 1 nó vingar, rode `./run_validation.sh 1,2,3,4` nele mesmo (ordem
  já é da configuração mais barata pra mais cara) e aceite que 3/4 nós
  pode não terminar a tempo -- 1 e 2 nós sozinhos já dão um primeiro
  fidelity error real, que é o número que falta no artigo.
- `compute_fidelity_error.R` roda sobre o que existir em
  `simgrid-chuc-validation/results/` -- não precisa esperar os 12
  completos, dá pra rodar parcial e ver o que já saiu.

## O que eu NÃO vou fazer sozinho

- Não vou submeter/cancelar reservas OAR sem você confirmar (isso inclui o
  `oardel`/`oarsub -t deploy` sugerido acima).
- Se algo divergir muito do esperado (ex.: `smpirun` não aceitar algum cfg,
  build falhar por dependência faltando no shell mínimo), vou reportar e
  parar, não vou tentar "corrigir escondido" mudando os parâmetros
  calibrados nem os dados da campanha real.
