# Co-op pela internet: o que mudou

Base: `prototipo/elementals-completo.zip`. Zip novo: `prototipo/coop-internet/elementals-coop-internet.zip`.
Guia para testar com amigos: `GUIA-COOP-INTERNET.md`.

## O problema

O cliente aplicava a foto mais nova assim que chegava. Em casa (127.0.0.1) isso é liso, mas na internet as
fotos chegam em rajadas: algumas vezes nenhuma num quadro (a tela congela), outras duas de uma vez (a tela
pula). E o herói do cliente só andava depois de ir e voltar do host.

## O que foi feito

1. **Buffer de fotos (cliente).** Cada foto leva o quadro do host. O cliente mostra uma por quadro, na
   ordem, um pouco atrás da mais nova. O tamanho dessa espera se ajusta sozinho: é o mínimo que, nos
   últimos 3 s, teria dado tempo de todas as fotos chegarem. Se ficou para trás, anda 2 quadros por vez;
   se está adiantado, espera um.
2. **Interpolação.** Foto perdida: as posições (e a altura no pulo, e a câmera) ficam no meio do caminho
   entre a anterior e a próxima. Isso também deixa o host mandar 30 fotos/s (`--net-rate=30`) para economizar
   upload, sem perder suavidade.
3. **Eventos no tempo certo.** Efeitos, sons, números e avisos levam o quadro do host e tocam junto com a
   foto certa, não antes.
4. **Predição do próprio herói andando.** O cliente manda um número em cada comando e o host devolve qual
   já usou. Andando (parado ou caminhando/correndo no chão), o herói do cliente parte da posição mais nova
   do host e refaz os passos dos comandos ainda não usados, com a mesma aceleração do `PlayerMovement`.
   Diferenças pequenas somem em alguns quadros (sem tranco). Golpe, pulo, esquiva, agarrão e dano
   continuam vindo do host.
5. **Throttle do ENet desligado.** O ENet jogava fora fotos de propósito quando o ping variava (dava ~5%
   de perda com rede sem perda nenhuma). Agora a perda medida é só a da rede.
6. **Canal das fotos sem ordem.** Antes uma foto que chegasse depois de uma mais nova era descartada; agora
   ela entra no buffer.
7. **Simulador de internet ruim** dentro do jogo (`--lag`, `--jitter`, `--loss`, ou F8 na fase).
8. **Painel de rede (F3)**: ping, espera e perda (cliente); ping de cada jogador (host).
9. **Sala**: aceita `IP:porta` e mostra primeiro o IP do Tailscale (100.x) ou Radmin (26.x).

## Medição (host e cliente com o robô, 40 a 100 s cada, `tools/teste_rede.sh`)

"Congelados" = quadros em que a tela do cliente não andou; "saltos" = quadros em que pulou o tempo do host.

| Rede simulada (ida e volta, variação, perda) | Antes: congelados / saltos | Agora: congelados / saltos | Fotos preenchidas | Espera extra |
|---|---|---|---|---|
| Mesmo PC, sem simulação | 0,3% / 0,3% | 0,0% / 0,2% | 0% | ~1 quadro |
| 40 ms, ±10, 0% | 20% / 20% | 0,0% / 0,3% | 0% | ~1 quadro |
| 80 ms, ±30, 1% | 23% / 22% | 0,0% / 0,3% | 1,3% | ~1,5 quadro |
| 160 ms, ±60, 3% | 33% / 28% | 0,2% / 0,0% | 3,5% | ~1 a 2 quadros |
| 250 ms, ±120, 8% | 46% / 30% | 0,1% / 0,0% | 8,2% | ~3 quadros |
| 80 ms, ±30, 1%, host a 30 fotos/s | | 0,1% / 0,3% | 50% (interpoladas) | ~1,5 quadro |

- A predição do herói andando corrige em média 0,2 a 1 px por quadro (cresce com o ping), espalhado
  em vários quadros.
- Fase inteira em co-op com 160 ms e 3% de perda: o robô chegou à onda 11 com 2 ataques em dupla, o cliente
  viu tudo, sem erro de script.
- Banda: ~600 bytes por foto, 60 por segundo = ~36 KB/s (~0,3 Mbit/s) de upload do host por amigo. Com 3
  amigos, ~1 Mbit/s. Com `--net-rate=30`, metade.

Testes antigos, todos passando: `tests/test_runner.gd` (439, 0 falhas), `tests/test_movement.gd` (62, 0
falhas), `tools/teste_coop.sh` rápido e longo (fase inteira, chefe, 4 duplas).

## O que ainda não dá para medir aqui

O teste com gente de verdade: se o atraso dos golpes (um ping) incomoda, e o comportamento de roteadores e
Wi-Fi reais. Isso é o teste com os amigos do guia.

## Arquivos alterados

| Arquivo | Mudança |
|---|---|
| `scripts/net/net.gd` | simulador (fila de envio com atraso/variação/perda, F8), tick nas fotos e eventos, canal das fotos sem ordem, throttle do ENet desligado, `IP:porta`, IP de VPN primeiro |
| `scripts/net/net_session.gd` | buffer + interpolação, eventos por quadro, número/confirmação dos comandos, predição do herói andando, painel F3, estatísticas no `--log` |
| `scripts/net/lobby.gd` | textos da sala |
| `tools/teste_rede.sh` (novo) | mede o cliente sob rede simulada, com ou sem `--sem-suavizar` |

Nada fora de `scripts/net/` mudou: combate, inimigos e HUD estão iguais.

## Regras para quem mexer depois

- Mudou como o herói anda no chão (velocidade, aceleração, corrida)? Ajuste `_predict()` em
  `net_session.gd`, que repete essa conta no cliente. Se esquecer, o herói do cliente vai dar pequenas
  correções ao andar, mas não quebra.
- Campo novo na foto do herói: o índice do dicionário extra é `entry[25]`; mantenha a ordem do `_pack()`.
- Opções de comparação: `--sem-suavizar` (jeito antigo) e `--sem-predicao` (buffer sem predição).
