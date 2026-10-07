# Microbench de contenção da NIC

`microbench.c` mede, com 4 emissores num nó e 4 receptores em outro, quando
cada fluxo termina sob o mesmo shaping (`tc tbf`) da campanha.

Os resultados coletados até 2026-10-02 não estão nesta branch.
`run_microbench.sh` não passava `--mca pml ucx`, ao contrário da campanha
(`g5k/lib/run.sh`), e as durações medidas (4 × 13,6 MB em 20–40 ms sob
"1 Gbit/s") ficaram abaixo do mínimo de bytes/taxa (436 ms).

Antes de recoletar:
- passar `--mca pml ucx`, como na campanha;
- rejeitar rodadas mais curtas que o mínimo físico (bytes / taxa);
- incluir os modos bidirecional e de 4 fluxos por nó.
