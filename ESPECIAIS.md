# Especiais: animação inteira, quadro a quadro

Base: `prototipo/unificada/elementals-unificada.zip`. Projeto novo: `elementals-especiais.zip`.
Patch: `especiais.diff` (`patch -p1` na raiz do projeto).
Vídeos (lado a lado, ANTES à esquerda, DEPOIS à direita): `video-especiais-antes-depois.mp4` (os 7) e
`especial-<herói>.mp4` (um por herói). Cada trecho mostra o especial (L) e o especial 2 (baixo + L).

## Por que continuavam ruins

A correção de ritmo anterior (`attack_frame` por poses) valeu para todos os golpes, inclusive o especial:

1. **Pulava quadros.** O especial cabia em no máximo 28 ticks de preparo e 30 de recuperação, e cada pose
   ficava 3 ticks. A Água tem 32 quadros: mostrava ~11. O Terra mostrava 10 dos 21 quadros do pilar,
   o Vento 8 dos 15 do fim. A arte dos especiais é uma coreografia (o Vento some e reaparece, o pilar
   cresce e explode), então pular quadros vira "teletransporte" e pedaços faltando.
2. **Efeito genérico por cima.** No impacto saía também um efeito do pacote PVFX (`special_<elemento>`),
   de outro estilo e maior (o redemoinho cinza do Vento, as chamas no chão da Brasa), que cobria a arte
   do herói e continuava depois que ele já tinha voltado ao parado.
3. **Quadro de dano errado.** O dano saía no quadro de maior alcance da arte, que nem sempre é o golpe
   (na Água era o fim, o gelo no chão).
4. **Especial 2 com a mesma arte.** Pilares de Pedra (Terra) e Fonte de Cura (Água) usam `sp_atk`
   espremido em 26 a 28 ticks: parecia o especial grande cortado.

## O que mudou

- `scripts/character_sprite.gd`: `art_timing()` e `art_frame_at()`. Um golpe com `art_tpf` toca os quadros
  `art_from..art_to` **todos, na ordem**, `art_tpf` ticks cada; o dano vale de `art_impact` a `art_end`
  (enquanto o efeito desenhado está na tela) e o último quadro fica 4 ticks a mais.
- `scripts/player.gd`: tabela `SPECIAL_ART` (ticks por quadro, quadro de impacto e fim do dano de cada herói);
  `special_attack()` usa essa tabela; o alcance acompanha a arte (até 96 px; Metal acerta dos dois lados);
  saiu o efeito genérico por cima do especial (`SPECIAL_FX_AHEAD` e o `stage.fx` em `_update_attack`).
  `_show_attack()` usa `art_frame_at` quando o golpe tem `art_tpf`.
- `scripts/hero_moves.gd`: Pilares de Pedra toca só a parte das pedras (quadros 0 a 7) e sem o efeito genérico;
  Fonte de Cura toca a gota caindo, o respingo e as bolhas subindo (11 a 21). `get_move` aplica `art_timing`.
- `tests/test_runner.gd`: novo `test_special_art_plays_every_frame` (os 7 heróis: todos os quadros aparecem,
  nenhum rápido demais, nunca volta, dano no quadro de impacto, acerta a 40 px); o preparo da Brasa agora é 36.
- `tests/especiais_showcase.gd`: gravação dos vídeos
  (`godot --path . --resolution 1152x648 --fixed-fps 60 --write-movie /tmp/e/f.png --script res://tests/especiais_showcase.gd -- DEPOIS [id]`).

| Herói | Quadros | Ticks/quadro | Dano (quadros) | Duração antes | Depois |
|---|---|---|---|---|---|
| Brasa | 18 | 3 | 12–14 | 0,80 s | 0,97 s |
| Vento | 30 | 3 | 8–27 | 1,00 s | 1,57 s |
| Folha | 17 | 3 | 9–12 | 0,70 s | 0,92 s |
| Terra | 25 | 3 | 4–20 | 0,73 s | 1,32 s |
| Metal | 11 | 4 | 3–8 | 0,53 s | 0,80 s |
| Cristal | 15 | 4 | 8–12 | 0,70 s | 1,07 s |
| Água | 32 | 3 | 12–22 | 0,87 s | 1,67 s |

O herói continua invencível o especial inteiro. Para afinar: `SPECIAL_ART` e `SPECIAL_MAX_REACH` em
`player.gd`, `ART_SETTLE_TICKS` em `character_sprite.gd`.

## Testes

| Teste | Resultado |
|---|---|
| `tests/test_runner.gd` | 469 verificações, 0 falhas (eram 434) |
| `tests/test_movement.gd` | 62, 0 falhas |
| `tests/test_menus.gd` | 49, 0 falhas |
| `tests/playthrough.gd` (robô) | fase concluída em 237 s, 3 quedas |

## Mesclar com a outra frente

Só mexe em `character_sprite.gd` (funções novas no fim da seção de ritmo), `player.gd` (tabela do especial,
`special_attack`, `_show_attack`, `_update_attack`), `hero_moves.gd` (dois `special2` e `get_move`) e testes.
Não toca em fase, inimigos, cenários, rede nem menus. No online o quadro vem do `state_frame`, então host e
cliente continuam iguais.
