# Fase 2: Cemitério de Ferro

Base: `prototipo/gelo-inimigo/elementals-gelo-inimigo.zip` (a versão mais nova, com a correção do Guardião
andando de costas). Godot 4.4.1.
Zip: `elementals-fase-2.zip`. Diff só do código: `fase-2.diff`. Vídeo com som (2 min): `video-fase-2.mp4`.
Fotos: `inicio-fase-2.png`, `curandeira.png`, `chefe-corrosao.png`.

## Como jogar a fase 2

- **No título:** a linha nova **Fase** (logo abaixo de Jogar) troca com as setas para os lados
  (`< 1 Bairro >` / `< 2 Cemitério >`). Jogar ou J nessa linha vai para a seleção de herói.
- **No fim da fase 1:** a tela de vitória ganhou **Próxima fase** (primeira opção). Os pontos e as vidas
  passam para a fase 2.
- **Linha de comando:** `godot --path . res://scenes/main.tscn -- --fase=2` abre direto nela.
- Online continua só na fase 1 por enquanto (a sala sempre volta para ela).

## O que tem

Três seções: **Portão do ferro-velho**, **Pilhas de sucata** e **Prensa enferrujada**. 13 ondas em 6 travas
e 2 emboscadas, como a fase 1, mas com os inimigos antigos misturados mais cedo. Cada inimigo novo aparece
primeiro numa situação que ensina como lidar com ele: a Sombra sozinha na 1ª trava, a Curandeira atrás de
um Brutamontes no começo das Pilhas de sucata.

### Inimigos novos (arte dos pacotes da chierit que já estão no projeto, com paleta "corrompida")

| Inimigo | Vida | Elemento | Fraco | Resiste | O que faz |
|---|---|---|---|---|---|
| **Sombra** (Wind Hashashin roxo) | 34 | Sombra | Fogo, Cristal | Vento | Luta como o Faca e tem o **Passo Sombrio**: some piscando (16 quadros, dá para acertar e cancelar), fica invisível e intocável, e reaparece nas **costas** do herói com um corte de "!" de 16 quadros (dá tempo de virar, esquivar ou pular). |
| **Curandeira** (Water Priestess esverdeada) | 40 | Água | Folha, Terra | Água, Fogo | Fica longe e **reza** brilhando em verde ("CURA..."). Depois de 44 quadros, todo inimigo ferido perto dela recupera 20 de vida. Um golpe na reza cancela a cura. Não cura chefe. Encurralada, dá um jato d'água que empurra o herói. |

### Chefe: Corrosão, a Lâmina Enferrujada (Metal Bladekeeper cor de ferrugem)

340 de vida, Metal, fraca contra Fogo e Terra, resiste a Metal e Vento. Mesma barra e marca de 50% do
Ferrugem e o mesmo esquema de três fases:

| Fase | Golpes |
|---|---|
| 1 (armadura nos 2 primeiros golpes) | **Corte duplo** (o 2º derruba). **Lâmina giratória**: bumerangue na faixa dela, acerta na ida e na volta (mude de faixa ou pule). **Guarda**: segura golpes de frente que não derrubam ("BLOQUEIO") e revida com um contragolpe no 2º bloqueio. Quebra a guarda: golpe que derruba, pelas costas, pulando ou com a fraqueza. |
| 2 (50%, "SEM ARMADURA!") | Mais rápida, golpes não são interrompidos na antecipação (como o Ferrugem). **Investida cortante**: mira a faixa do herói, marca no chão onde vai parar e atravessa (16, derruba). |
| 3 (25%, "FÚRIA!") | Chama **duas Sombras**. **Chuva de lâminas**: três lâminas em arco que cravam no herói e dos lados (círculos no chão). O corte duplo emenda direto na chuva. |

A lâmina (`assets/props/lamina.png`) é arte original do projeto (CC0), gerada por `tools/gerar_lamina.py`.

## Trocar o cenário pelos assets novos

Hoje a fase 2 usa o ferro-velho atual **à noite** (as camadas `bg_noite_*` que já estavam no pacote), com céu,
chão e luzes mais escuros. Tudo isso fica num lugar só, a chave `"scenery"` da fase 2 em `scripts/fases.gd`:

```gdscript
"scenery": {
	"dir": "res://assets/scenery/",   # pasta da arte
	"bg": "bg_noite_%d.png",          # 4 camadas de fundo (%d = 1 a 4, a 1ª é a mais longe)
	"floor": "chao.png",              # ladrilho do chão
	"floor_tint": Color(0.55, 0.52, 0.62),
	"sky": Color8(40, 38, 66),        # cor atrás de tudo
	"ambient": ..., "sun": ...,       # luzes
	"seed": 4242,                     # sorteio da posição dos objetos
},
```

Para os assets novos: copie para `assets/scenery/fase2/` (camadas, chão e os objetos em `props/`), troque
`"dir"`, `"bg"` e `"floor"`, e acrescente `"back_row"`, `"deep_row"` e `"front_row"` com os nomes dos objetos
(mesmo formato de `StageScenery.BACK_ROW`). O que não for trocado continua vindo do ferro-velho. Os nomes
das seções e da fase também ficam em `scripts/fases.gd`. Se mandar os arquivos, eu encaixo.

## Equilíbrio (robô habilidoso de `tests/balanco.gd`, com esquiva perfeita)

| Herói | Fase 1: tempo, mortes, vida perdida | Fase 2: tempo, mortes, vida perdida |
|---|---|---|
| Brasa | 273 s, 3, 398 | 321 s, 3, 396 |
| Vento | 284 s, 5, 568 | 361 s, 7, 722 |
| Água | 273 s, 3, 490 | 401 s, 5, 740 |

A fase 2 é mais longa e mais dura, sobretudo para quem não tem a fraqueza dos inimigos novos (Vento é
resistido pela Sombra e pela Corrosão). O Brasa acha fácil porque é fraqueza da Sombra e da chefe.
O robô do playthrough (`tests/playthrough.gd -- --fase=2`) termina a fase em 258 s com 5 mortes.

## Arquivos

Novos:
- `scripts/fases.gd`: lista de fases (nome, músicas, seções, cenário), fase atual, pontos e vidas que passam.
- `scripts/enemies/sombra.gd`, `curandeira.gd`, `corrosao.gd` (estende `Boss`), `lamina_giratoria.gd` (+ `.uid`).
- `data/enemies/sombra.tres`, `curandeira.tres`, `corrosao.tres`.
- `assets/props/lamina.png` e `tools/gerar_lamina.py`.
- `tests/test_fase2.gd` (71 verificações) e `tests/vitrine_fase2.gd` (o vídeo).

Alterados (mudanças pequenas e localizadas):
- `scripts/stage.gd`: `sections` (vem de `Fases`) no lugar de `SECTIONS` nos 4 pontos que liam as seções;
  música da fase e do chefe vêm de `Fases`; 3 inimigos novos em `ENEMIES`; `make_enemy()` (usa o script
  próprio do inimigo, se tiver); `next_stage()` e pontos/vidas trazidos; explosão com visual de lâmina.
  `Stage.SECTIONS` (fase 1) não mudou.
- `scripts/enemy_data.gd`: campos `custom_script` e `boss_title`.
- `scripts/stage_scenery.gd`: tabela `DEFAULT` + `setting()`; camadas, chão, objetos e sorteio vêm da fase.
- `scripts/view_3d.gd`: céu e luzes vêm da fase; lâmina giratória e chuva de lâminas desenhadas com a arte nova.
- `scripts/hud.gd`: faixa do chefe pelo `boss_title`, nome da fase na entrada, "Próxima fase" na vitória.
- `scripts/title.gd`: linha "Fase" no menu.
- `scripts/select.gd`: começa a fase sem pontos trazidos.
- `scripts/background.gd`: lê as seções da fase atual (fundo 2D antigo).
- `scripts/net/net_session.gd`: o cliente cria o inimigo com o script certo (`Stage.make_enemy`).
- `scripts/net/net.gd`: partida online sempre na fase 1.
- `tests/vitrine_menus.gd`: um "baixo" a mais por causa da linha nova do menu.
- `README.md` e `assets/characters/CREDITS.md`.

## Testes

| Teste | Resultado |
|---|---|
| `tests/test_fase2.gd` (novo) | 71 verificações, 0 falhas |
| `tests/test_runner.gd` | 445 verificações, 0 falhas |
| `tests/test_movement.gd` | 62 verificações, 0 falhas |
| `tests/test_menus.gd` | 49 verificações, 0 falhas |
| `tests/playthrough.gd` (fase 1) | igual a antes: 274 s, 6 mortes |
| `tests/playthrough.gd -- --fase=2` | termina a fase 2: 258 s, 5 mortes |

## Ao juntar com as outras frentes

- **Cenários elementais** mexe muito em `stage_scenery.gd` e `view_3d.gd` (tabela `BIOMES`). O jeito mais
  simples é o bioma virar o cenário de cada fase: a chave `"scenery"` de `fases.gd` passa a apontar para um
  bioma. Na `stage.gd` os dois mexem em linhas diferentes.
- **Dificuldade** mexe em `enemy.gd`, `boss.gd` e `stage.gd`. Os inimigos novos herdam de `Enemy`/`Boss`,
  então a vida escalada pela dificuldade vale para eles; a espera entre ataques do Corrosão está no
  `_on_attack_finished` dele (vale passar pelo `Difficulty` também).
- **Co-op internet** mexe em `net.gd`/`net_session.gd` em outras funções; aqui são 2 linhas.

## Na versão unificada

- O cenário escolhido na seleção (Shift/I) vale para as duas fases. No **ferro-velho** (padrão), cada fase
  usa a arte própria da chave `"scenery"` em `scripts/fases.gd` (fase 2 = ferro-velho à noite, com as camadas
  `bg_noite_*` agora em `assets/scenery/biomas/ferro_velho/`). Nos biomas elementais, vale a arte do bioma.
- Os nomes das seções seguem a mesma regra (no ferro-velho, os da fase; nos biomas, os do bioma).
- A espera entre ataques do Corrosão e da Curandeira passa pela dificuldade, como a dos outros inimigos.
