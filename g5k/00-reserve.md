# 00 — Reserva OAR (frontend de Lille)

A reserva é o único passo manual. Troque apenas `nodes=N` — todo o resto do
pipeline se adapta automaticamente ao conteúdo de `$OAR_NODE_FILE`.

```bash
# Interativa
oarsub -I -t deploy \
  -l "{cluster='chuc'}/nodes=4+{type='kavlan'}/vlan=1,walltime=4:00:00"

# Agendada
oarsub -r "2026-07-08 20:00:00" -t deploy \
  -l "{cluster='chuc'}/nodes=8+{type='kavlan'}/vlan=1,walltime=6:00:00"
```

Notas:

* Se quiser **incluir ou excluir o chuc-7** (3 GPUs) explicitamente, use
  propriedades OAR, por exemplo: `{cluster='chuc' AND host NOT IN ('chuc-7.lille.grid5000.fr')}`.
  Nada nos scripts exige isso — o chuc-7 é detectado e recebe `slots=3`
  automaticamente — mas contagens de ranks "boas" para o `MPI_Dims_create`
  (8, 12, 16, 27...) são mais fáceis com nós homogêneos.
* Verifique com `oarnodes -l | grep chuc` se o cluster exige fila
  `production` no seu site; se sim, acrescente `-q production`.
* Dentro do job, no frontend:

```bash
cd ~/ic/io-research/distributed-cube-average/g5k
./01-deploy.sh          # kadeploy + kavlan + DHCP + verificação
./02-setup.sh           # SSH mesh, GPUs, Nix, nv-bridge, warmup (paralelo)
./03-build.sh           # compila no head node (binário vai para o NFS)
./04-shape.sh 1gbit     # traffic shaping em TODOS os nós (ou "off")
./05-run.sh --label 1gbit-128 -- --size-x=128 --size-y=128 --size-z=128 \
    --absorption=2 --dx=1e-1 --dy=1e-1 --dz=1e-1 --dt=1e-6 --time-max=1e-4 \
    --output-file=./validation/predicted.dc
./06-sweep.sh           # (opcional) varredura banda × tamanho
```
