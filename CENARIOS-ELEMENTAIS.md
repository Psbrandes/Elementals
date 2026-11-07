# Cenários elementais (Terra, Deserto, Natureza, Vulcão)

Zip: `prototipo/cenarios-elementais/elementals-cenarios-elementais.zip` (Godot 4.4.1, feito sobre `elementals-completo.zip`).
Diff do código: `prototipo/cenarios-elementais/cenarios-elementais.diff` (sem as imagens).
Prévia: `cenarios-visao-geral.png` (os 4 lado a lado) e `cenario-<bioma>.png` (começo, meio e arena do chefe de cada um).

## O que mudou

O ferro-velho (pacote Dump Tileset da CraftPix) saiu. A fase agora pode ser jogada em 4 cenários elementais,
todos com **arte original** feita em código por `tools/gerar_cenarios.py` (pixel art com sombreado de cima à
esquerda, pontilhado Bayer e contorno escuro, sem pacote de terceiros). Isso também tira a licença da CraftPix do
cenário (inimigos e chefe continuam CraftPix).

| Cenário | Seções da fase | O que tem |
|---|---|---|
| Cânion de Terra | Trilha do cânion, Mina de âmbar, Círculo de pedras | paredões com estratos, chaminés de pedra, cristais de âmbar, carrinho de mina, escora, menir com espiral, chão rachado |
| Deserto Escaldante | Mar de dunas, Ruínas do oásis, Templo soterrado | mesas ao longe, dunas, cactos, palmeiras, colunas e arco em ruínas, crânio e ossos, chão de areia ondulada |
| Floresta Antiga | Trilha da mata, Bosque antigo, Clareira do santuário | árvores grandes, moitas com flores, cogumelos, toco, tronco caído, samambaia, pedras com musgo, grama com terra |
| Vulcão em Fúria | Encosta de cinzas, Rio de lava, Cratera do vulcão | vulcão com lava descendo, cachoeiras de lava, basalto com veios acesos, obsidiana, fumarolas, árvores queimadas |

Cada bioma tem céu, 3 camadas de fundo (parallax pela perspectiva, como antes), chão, 18 a 22 objetos, luzes
próprias e o próprio barril e caixa quebráveis (barril de madeira com cipó, ânfora e cesto, urna de pedra e caixa
de mina, caldeirão de magma e caixa queimada). O nome da seção que aparece ao entrar nela segue o bioma.

## Como escolher

- **Solo**: na seleção de personagem, **Shift ou I (RB/LB no controle) troca o cenário** (L fica para a dificuldade) (aparece "Cenário: ..." embaixo do herói).
- **Online**: o host aperta Shift/I na sala; o cenário vai junto quando a partida começa e nos continues.
- O padrão é o Cânion de Terra.

## Arquivos

- `assets/scenery/biomas/<bioma>/`: `bg_1..4.png`, `chao.png`, `barril.png`, `caixa.png`, `props/*.png`
- `scripts/stage_scenery.gd`: tabela `BIOMES` (nome, cores, luzes, seções e objetos de cada fileira), `biome` atual
- `scripts/view_3d.gd`: céu, luzes e quebráveis vêm do bioma
- `scripts/select.gd`, `scripts/net/lobby.gd`, `scripts/net/net.gd`: escolha com Shift/I e envio para o cliente
- `tools/gerar_cenarios.py` + `tools/pixel.py`: o gerador (numpy, scipy e Pillow). Sementes fixas: rodar de novo dá as mesmas imagens
- `tests/vitrine_cenarios.gd`: tira as fotos de prévia

Dica para quem for mexer na arte: a câmera é bem inclinada para baixo, então só a faixa de baixo das camadas do
fundo aparece (céu: linhas ~270-300 de 360; camada 4: ~150-340). O que importa fica perto do horizonte.

## Testes

| Teste | Resultado |
|---|---|
| `tests/test_runner.gd` | 439 verificações, 0 falhas |
| `tests/test_movement.gd` | 62 verificações, 0 falhas |
| `tests/playthrough.gd` (robô, fase inteira) | termina a fase (258 s, 7 mortes, igual à versão completa) |
| `tests/vitrine_cenarios.gd` | 12 fotos, os 4 biomas |

## Fica para depois

- Ligar os cenários a fases diferentes (fase 1 Terra, 2 Deserto...), cada uma com ondas e chefe próprios.
- Objetos animados (lava pulsando, fumaça subindo, folhas balançando) e música por bioma.
