# Elementals: versão completa (as 5 frentes juntas)

Zip: `prototipo/elementals-completo.zip` (Godot 4.4.1). Vídeo: `prototipo/completo/video-versao-completa.mp4`
(45 s solo com o robô habilidoso + 100 s de co-op online gravado no host, com o parceiro em outra instância).

## O que entrou

Combate e combos com a correção de ritmo, movimentação, golpes próprios dos 8 heróis, inimigos/fase/chefe e
co-op online, mescladas nessa ordem (o co-op por último, como o guia dele pedia).

## Resultado dos testes

| Teste | Resultado |
|---|---|
| `tests/test_runner.gd` | 439 verificações, 0 falhas |
| `tests/test_movement.gd` | 62 verificações, 0 falhas |
| `tests/playthrough.gd` (robô) | termina a fase (258 s, 7 mortes) |
| `tools/teste_coop.sh` (rápido) | co-op ok |
| `HOST_FRAMES=30000 CLIENT_FRAMES=29000 tools/teste_coop.sh` | fase inteira em co-op, chefe vencido, 3 ataques em dupla, o cliente viu todos |

## Decisões na mesclagem

- **player.gd**: mesclado por função. O pulo usa o PlayerMovement (altura variável, controle no ar) e o pulo
  cancelado do combate vai para a frente quando não há direção. No ar, J sai a corrente aérea (chute, soco,
  pisão) e baixo + J o golpe aéreo próprio do herói. O carregado deixa o herói mais lento pelo `_walk_speed()`,
  então vale também para a corrida. Mergulhos que terminam em impacto não reativam a corrida no pouso.
- **"push" com dois sentidos**: no combate é o deslize do atordoado; no HeroMoves era um empurrão instantâneo.
  Somados, o jab jogava o inimigo 45 px e o combo quebrava. Agora o golpe corpo a corpo só usa o deslize; o
  empurrão instantâneo continua só nos projéteis.
- **Números que sobem**: as frentes de combate e de inimigos criaram dois sistemas. Ficou um só
  (`Stage.popup` e `popup_spawned`, desenho do combate); "FRACO!", "RESISTE" e "BLOQUEIO" usam o mesmo.
- **Animação dos golpes**: o `attack_frame()` por poses da correção de ritmo vale para os golpes próprios
  (com `anim` e `full_art`) e para os inimigos.
- **Alvo dos inimigos**: `Enemy._target()` agora escolhe entre todos os heróis (`_pick_target` do co-op). A
  explosão de bomba, pedra e barril acerta todos os heróis, e o orbe enche o medidor de quem pegou.

## Co-op online com as novidades

- A foto do host leva o estado novo que muda a arte ou o HUD: esquiva, corrida, derrapagem e salto no
  agarrão; golpe aéreo próprio, carga do J, nota de estilo e tempo do combo; animação do golpe; escudo,
  esquiva e fúria dos inimigos; cor (gelo, queimadura, fase do chefe); ponto de queda do salto do chefe;
  pavio e balanço do barril; e o novo tipo de ator `Lob` (bomba e pedra, com o círculo no chão).
- O cliente agora manda esquiva (Shift/I), J segurado (golpe carregado) e K segurado (altura do pulo).
- Câmera lenta: só o host chama `Engine.time_scale`; o valor vai no cabeçalho da foto e o cliente desacelera
  junto os efeitos locais.
- Eventos novos para o cliente: números e avisos que sobem, destaques do combo (CONTRA!, AÉREO...) e o nome
  dos golpes próprios e do ataque em dupla.
- **Ataque em dupla ligado ao multiplayer**: os dois heróis apertam L juntos (até 15 quadros) e perto
  (90 px); a fusão sai no host e aparece nas duas telas. O robô do co-op agora espera o especial do parceiro
  para soltar junto, e o teste longo confere que a dupla saiu.

## Equilíbrio

Medido com `tests/balanco.gd` (robô básico e robô habilidoso que usa lançador, pulo cancelado, combo aéreo,
esquiva no aviso, virada e especial 2), em Brasa, Vento, Terra, Gelo e Água:

| | Vida perdida na fase | Mortes |
|---|---|---|
| Frente de inimigos sozinha, robô habilidoso (Brasa) | 752 | 6 |
| Completa, robô básico | 540 a 790 | 4 a 5 |
| Completa, habilidoso sem esquiva | 500 a 720 | 3 a 6 |
| Completa, habilidoso com esquiva perfeita | 380 a 480 | 1 a 4 |

Com os inimigos novos, as ferramentas de combo não deixaram a fase mais fácil: sem esquiva, o robô habilidoso
apanha quanto apanhava na frente de inimigos sozinha. O que mais reduz o dano é esquivar no "!", e o robô faz
isso com reflexo perfeito, o que um jogador não tem. Por isso não mexi nos números. Se a fase ficar fácil
para quem domina a esquiva, o primeiro ajuste é `DODGE_COOLDOWN_FRAMES` (hoje 12) e `ROLL_INVULN_FRAMES` (12)
em `scripts/player_movement.gd`.

## Fica para depois

- Os golpes próprios com preparo de 4 a 5 quadros podem ganhar 1 a 2 quadros para a pose de antecipação
  (sugestão da correção de ritmo, opcional).
