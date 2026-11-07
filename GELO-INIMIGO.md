# Gelo: sai dos heróis, vira inimigo

Base: `prototipo/menu-som-vitoria/elementals-menu-som-vitoria.zip` (Godot 4.4.1).
Zip novo: `elementals-gelo-inimigo.zip`. Diff: `gelo-inimigo.diff`. Vídeo: `video-guardiao-gelo.mp4`.

## Onde o Gelo entrou como herói

Na primeira versão com arte de verdade, o elenco pegou os 8 personagens da chierit. O Guardião de Gelo
vem de outro pacote ("Boss: Frost Guardian", arte de chefe com só 5 animações), mas entrou na lista de
jogáveis em `scripts/characters.gd`. Depois a frente de golpes por herói deu golpes próprios a ele em
`scripts/hero_moves.gd`, e o ataque em dupla ganhou 3 nomes com Gelo. Antes desta mudança ele não
existia como inimigo em lugar nenhum da fase.

## O que mudou

- **7 heróis jogáveis:** Brasa, Vento, Folha, Terra, Metal, Cristal e Água. A tela de seleção fica 4 + 3;
  cima/baixo na 4ª coluna desce para a Água. Título: 7 heróis no chão, 7 orbes e o subtítulo
  "Sete elementos contra a ferrugem". O lobby online usa a mesma lista.
- **Ataques em dupla:** saíram Nevasca (Água + Gelo), Choque Térmico (Fogo + Gelo) e Tempestade de Gelo
  (Gelo + Vento). Os outros 12 nomes continuam.
- **Golpes do Gelo herói** (Revés Glacial, Martelo Glacial, Prisão de Gelo, Avalanche) saíram. O
  congelamento continua no jogo pelas Raízes da Folha.
- **Fraquezas:** como nenhum herói é de Gelo, o Brigão e o Piromante agora são fracos só contra Água, e o
  Escudeiro resiste só a Água (antes apareciam "Gelo" na barra deles sem ninguém para usar).
- **Guardião de Gelo, inimigo novo** (`data/enemies/guardiao_gelo.tres`), com a arte do Frost Guardian:
  - 110 de vida, elemento Gelo, fraco contra Fogo e Metal, resiste a Água.
  - Armadura nos 2 primeiros golpes, não pode ser agarrado nem lançado, anda devagar.
  - Soco de gelo com "!" longo (20 quadros de aviso), 14 de dano e derruba. Para isso o `EnemyData`
    ganhou o campo `attack_knockdown`.
  - 50% de chance de soltar frango, 500 pontos.
  - Entra sozinho no Pátio do porto, numa onda nova entre as duas que já havia na trava antes do chefe
    (a fase passou de 12 para 13 ondas).

## Correção: andava de costas

A arte do Frost Guardian é de chefe e foi desenhada olhando para a **esquerda**; os outros pacotes olham
para a direita, e o jogo espelha o desenho contando com isso. Por isso ele andava e socava de costas.
As 5 folhas de animação dele em `assets/characters/frost_guardian/` foram espelhadas, e o pé e o quadro
do soco em `characters.json` foram recalculados (o soco agora acerta no quadro 7, com o braço esticado).
`tools/pack_sprites.py` ganhou a lista `FACES_LEFT`, que espelha esse pacote se as folhas forem geradas
de novo.

## Arquivos alterados

Novos:
- `data/enemies/guardiao_gelo.tres`: o inimigo.
- `tests/vitrine_guardiao.gd`: vídeo do Guardião contra o Brasa.

Alterados:
- `scripts/characters.gd`: tirado o Gelo da lista de jogáveis.
- `scripts/hero_moves.gd`: tirados os golpes do Gelo e os 3 ataques em dupla com Gelo.
- `scripts/player.gd`: especial "gelo" fora da lista de efeitos de herói; comentário.
- `scripts/sound_bank.gd`: som do especial de Gelo fora da tabela de heróis.
- `scripts/select.gd`: cima/baixo com a 2ª linha de 3.
- `scripts/title.gd`: textos e comentários (7 heróis).
- `scripts/enemy_data.gd` e `scripts/enemy.gd`: campo `attack_knockdown` (soco que derruba).
- `scripts/stage.gd`: `guardiao_gelo` na lista de inimigos e a onda nova no Pátio do porto.
- `data/enemies/capanga_brigao.tres`, `piromante.tres`, `escudeiro.tres`: fraquezas sem Gelo.
- `tests/test_runner.gd`: 7 heróis, Gelo não jogável, teste do Cristal no lugar do Gelo, congelamento
  testado direto, teste novo do Guardião (arte, onda, armadura, soco que derruba, fraqueza a Fogo).
- `assets/characters/frost_guardian/*.png` e `assets/characters/characters.json`: arte espelhada.
- `tools/pack_sprites.py`: `FACES_LEFT`.
- `tests/showcase_moves.gd` (comentário) e `README.md`.

## Testes

| Teste | Resultado |
|---|---|
| `tests/test_runner.gd` | 434 verificações, 0 falhas |
| `tests/test_movement.gd` | 62 verificações, 0 falhas |
| `tests/test_menus.gd` | 49 verificações, 0 falhas |
| `tests/playthrough.gd` | fase concluída em 274 s, 6 quedas (antes 258 s, 7 quedas) |

## Ao juntar com as outras frentes

As frentes de dificuldade, cenários, co-op internet e web ainda não foram juntadas. Pelos diffs delas,
os arquivos que podem dar conflito são `scripts/stage.gd`, `scripts/select.gd` e `scripts/enemy.gd`
(dificuldade e cenários mexem neles). O co-op internet não toca em nada desta mudança. Na frente de
dificuldade, conferir se a escala por dificuldade pega o inimigo novo.
