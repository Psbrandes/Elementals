# Elementals: menu, música, efeitos sonoros e tela de vitória

Base: `prototipo/elementals-completo.zip` (Godot 4.4.1). Vídeo com som: `prototipo/menu-som-vitoria/video-menu-som-vitoria.mp4`.

## O que mudou para quem joga

- **Menu principal** no título: Jogar, Co-op online, Opções, Controles, Créditos e Sair (só no PC). Fundo novo
  com céu estrelado, montanhas em parallax, os 8 orbes dos elementos girando em volta do nome (cada letra
  passa pelas cores dos elementos) e os 8 heróis no chão, um de cada vez soltando o especial. O atalho O
  para o co-op continua.
- **Opções**: volume da música e dos efeitos (0 a 10, 0 é mudo) e tela cheia no PC. Ficam salvas em
  `user://opcoes.cfg`. Também dá para abrir as opções pela pausa.
- **Menu de pausa** (Esc, P ou Start): Continuar, Recomeçar a seção, Opções e Menu principal. A música
  abaixa enquanto o jogo está pausado.
- **Fim de jogo** com menu: Continuar desta seção ou Menu principal.
- **Tela de vitória**: "FASE CONCLUÍDA!" cai letra por letra, toca a fanfarra e sobe um painel com o herói,
  tempo, inimigos derrotados, maior combo e quedas. Os bônus e o total são contados com som e no fim a nota
  da fase (D a S) é carimbada enquanto o herói solta o especial. J pula a contagem. Depois: Jogar de novo,
  Escolher outro herói ou Menu principal. Online, o host volta todos para a sala (como antes) e o cliente vê
  os mesmos números.
- **Nota da fase**: até 3 pontos pelo tempo (menos de 4, 6 ou 8 min), 3 por cair pouco (0, até 2 ou até 4
  quedas) e 3 pelo maior combo (30, 15 ou 8 golpes). S com 8 ou mais, A com 6, B com 4, C com 2. O robô do
  playthrough (258 s, 7 quedas) tira C. Ajuste em `Stage.stage_rank`.

## Música e efeitos novos (originais, CC0)

Compostos e sintetizados do zero por `tools/gerar_audio.py` (chiptune: quadradas, triângulo e ruído, sem
amostras de terceiros). Volume médio igual ao das faixas que já existiam (cerca de -12 dB).

| Arquivo | Onde toca |
|---|---|
| `music/selecao.ogg` | escolha de herói, loop de 29 s em lá menor |
| `music/vitoria.ogg` | fanfarra da vitória, 7 s, toca uma vez |
| `music/resultado.ogg` | loop calmo depois da fanfarra, na tela de vitória |
| `sfx/dodge`, `land` | esquiva (no lugar do "whiff") e pouso de pulo alto |
| `sfx/grab`, `throw` | agarrão e arremesso |
| `sfx/alert` | bipe baixinho junto do "!" do aviso de golpe inimigo |
| `sfx/block`, `counter` | inimigo bloqueando (no lugar do "hit") e contra-ataque |
| `sfx/charge_ready` | J segurado chegou no golpe carregado |
| `sfx/rank_up` | nota de estilo do combo subiu |
| `sfx/go`, `boss_intro`, `extra_life` | "GO!", chegada do chefe, vida extra |
| `sfx/tally`, `tally_end`, `stamp` | contagem e nota da tela de vitória |
| `sfx/menu_open`, `menu_close` | abrir e fechar submenus e a pausa |

As faixas da fase, do chefe e do título (xDeviruchi) e os efeitos de combate que já existiam continuam.

## Arquivos

Novos:
- `scripts/settings.gd`: autoload `Settings` (volumes, tela cheia, barramentos de áudio "Music" e "SFX").
- `scripts/ui/menu_list.gd`, `options_menu.gd`, `ui_draw.gd`: lista de menu, submenu de opções e desenho.
- `tools/gerar_audio.py`: gera as 3 músicas e os 17 efeitos (`python3 tools/gerar_audio.py assets/audio`).
- `tests/test_menus.gd` (49 verificações) e `tests/vitrine_menus.gd` (vídeo).
- 3 músicas e 17 efeitos em `assets/audio`.

Alterados (mudanças pequenas e localizadas):
- `project.godot`: autoload `Settings` antes do `SoundBank`.
- `scripts/title.gd`: reescrito com o menu.
- `scripts/hud.gd`: menus de pausa, fim de jogo e a tela de vitória (substitui o quadro de resultado).
- `scripts/stage.gd`: conta inimigos derrotados e maior combo, guarda `final_results` na vitória, nota da
  fase, funções `continue_here`, `restart_stage` e `go_to_scene`; fora do online, o J do fim de jogo e da
  vitória agora é do menu do HUD. Sons de "GO!" e da chegada do chefe.
- `scripts/sound_bank.gd` e `sound.gd`: barramentos, música sem loop, `Sound.ui` (som de interface que não
  vai para os outros jogadores) e um sorteio próprio para a variação de tom. Antes, tocar um som consumia o
  sorteio do jogo, então cada som novo mudava o comportamento dos inimigos (um teste do chefe falhava por isso).
- `scripts/player.gd`: contador de quedas e sons de agarrão, arremesso, carregado, nota e vida extra.
- `scripts/player_movement.gd`, `fighter.gd`, `enemy.gd`: sons de esquiva, pouso, contra-ataque, bloqueio e aviso.
- `scripts/select.gd`: toca a música da seleção.
- `scripts/net/net_session.gd`: o evento "cleared" leva os números da vitória para o cliente, e a música
  repassada respeita o "sem loop".
- `README.md` e `assets/characters/CREDITS.md`.

## Testes

| Teste | Resultado |
|---|---|
| `tests/test_runner.gd` | 439 verificações, 0 falhas |
| `tests/test_movement.gd` | 62 verificações, 0 falhas |
| `tests/test_menus.gd` (novo) | 49 verificações, 0 falhas |
