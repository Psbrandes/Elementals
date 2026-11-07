# Elementals: equilíbrio da dificuldade

Zip: `prototipo/dificuldade/elementals-dificuldade.zip` (Godot 4.4.1, base: `elementals-completo.zip`).
Diff só desta frente: `prototipo/dificuldade/dificuldade.diff`.

## O que a medição mostrou

O robô de teste antes reagia ao "!" no mesmo quadro (reflexo perfeito). Ganhou um tempo de reação humano
(`reacao=14`, cerca de 0,23 s), o detalhe por trava e o dano por fonte. Com isso, nos 8 heróis, versão completa:

| Robô (média de 8 heróis) | Mortes na fase | Vida perdida |
|---|---|---|
| Habilidoso com reação humana | 4,0 (2 a 7) | 579 |
| Básico (só aperta J) | 4,4 (2 a 6) | 615 |

Com 3 vidas, isso é fim de jogo para o robô. Ou seja, a medição **não** confirma que o jogo ficou fácil no total.
O que existe é uma curva desigual:

- **Início fácil demais**: as travas 1 e 2 tiram de 0 a 50 de vida. O combo com lançador (52 de dano) mata um
  Capanga (30), um Faca (25) ou um Brigão (36) inteiro sem ele encostar no chão. É daí que vem a sensação de "fácil".
- **Fim com picos**: o soco de pedra do Ferrugem sozinho tira de 85 a 280 de vida; o fim do Armazém (travas 5 e 6)
  tira de 80 a 140.
- **Faca injusto**: preparo de 8 quadros, mais rápido que a reação humana (12 a 18). O "!" não dava tempo.

O robô é pior que uma pessoa em posicionamento (entra no meio do bando e até soca os barris: 100 de vida por
fase vêm de barril), então os números são o lado pessimista.

## O que mudou

1. **Três níveis de dificuldade** (`scripts/difficulty.gd`, novo). Na seleção de personagem, **L** troca entre
   Fácil, Normal e Difícil (aparece embaixo do nome do herói). Também dá para usar `-- --dificuldade=dificil`.
   Todos os números ficam numa tabela só (`LEVELS`), para afinar sem mexer no resto:

   | | Vida dos inimigos | Dano recebido | Espera entre ataques | Atacando juntos | Vidas | Comida |
   |---|---|---|---|---|---|---|
   | Fácil | ×0,8 | ×0,65 | ×1,35 | 1 | 5 | ×1,5 |
   | Normal | ×1 | ×1 | ×1 | 2 | 3 | ×1 |
   | Difícil | ×1,25 | ×1,2 | ×0,8 | 3 | 3 | ×0,6 |

   No Difícil o combo com lançador deixa de matar o Capanga e o Brigão de uma vez.
2. **Faca**: preparo 8 → 11 quadros (`data/enemies/faca.tres`). Continua o mais rápido, mas o "!" dá tempo.
3. **Ferrugem**: soco de pedra 20 → 16 de dano (`scripts/boss.gd`). O padrão continua o mesmo: quem fica
   socando a armadura apanha.

## Resultado (média de 8 heróis, robô com reação humana)

| | Habilidoso: mortes | Básico: mortes | Vidas |
|---|---|---|---|
| Antes (Normal) | 4,0 | 4,4 | 3 |
| Fácil | 1,2 | 1,8 | 5 |
| Normal | 3,1 | 4,6 | 3 |
| Difícil | 5,8 | 7,2 | 3 |

No Normal, o habilidoso termina a fase no limite das vidas (com a vida extra dos 20.000 pontos), e quem só aperta
J perde. Uma pessoa joga melhor que o robô, então deve sobrar margem. O Fácil é para quem está aprendendo.

## Arquivos alterados

| Arquivo | Mudança |
|---|---|
| `scripts/difficulty.gd` (+ `.uid`) | Novo. Níveis e multiplicadores. |
| `scripts/enemy.gd` | Vida do inimigo e espera entre ataques passam pelo nível. |
| `scripts/boss.gd` | Espera entre ataques passa pelo nível; soco de pedra 16. |
| `scripts/player.gd` | Dano recebido passa pelo nível; vidas iniciais pelo nível; `last_hit_by` (só para o teste). |
| `scripts/stage.gd` | Atacantes simultâneos e chance de comida passam pelo nível. |
| `scripts/select.gd` | L troca a dificuldade; mostra o nível. |
| `data/enemies/faca.tres` | Preparo 11. |
| `tests/balanco.gd` | Opções `reacao=N`, `trechos`, `vidas`, `dif=`; mostra dano por trava e por fonte. |

Para mesclar com as outras frentes: o dano entra num ponto só (`Player.take_hit`), então menu, co-op e cenários
não precisam mudar nada. Se o menu novo tiver opções, basta chamar `Difficulty.cycle()` e `Difficulty.display_name()`.
No co-op online vale o nível do host.

## Testes

- `tests/test_runner.gd`: 439 verificações, 0 falhas
- `tests/test_movement.gd`: 62 verificações, 0 falhas
- `tests/playthrough.gd`: termina a fase (238 s, 5 mortes)
- `tools/teste_coop.sh` (rápido): co-op ok

Medir de novo: `godot --headless --path . --fixed-fps 60 --script res://tests/balanco.gd -- fire_knight habil reacao=14 trechos dif=normal`
