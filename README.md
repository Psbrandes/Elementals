# Elementals

Beat 'em up 2.5D em pixel art no estilo dos 16 bits (Streets of Rage 2, Golden Axe II, TMNT: The Hyperstone Heist), feito em Godot 4 com GDScript.

O projeto já tem a **fase 1 jogável do começo ao fim** (Bairro do Porto, com o chefe Ferrugem) e **7 heróis jogáveis com arte de verdade** (pacotes Elementals, de chierit; o Guardião de Gelo, do pacote Boss: Frost Guardian, é inimigo). Inimigos e chefe usam pacotes da CraftPix (samurais, demônio e bruxa). O cenário padrão é o ferro-velho (CraftPix), e há mais 4 versões elementais com arte original (Terra, Deserto, Natureza e Vulcão), escolhidas na seleção. Os itens ainda são formas simples coloridas.

**Estilo 2.5D.** O cenário é 3D, visto por uma câmera em perspectiva que acompanha o scroll, e os heróis são os sprites 2D da pixel art, desenhados de frente para a câmera (billboards). A imagem 3D é renderizada em 384x216 e ampliada, então o cenário também fica pixelado. Toda a lógica (movimento, golpes, profundidade) continua em 2D; o 3D só espelha o que acontece nela.

## Como rodar

1. Instale o [Godot 4.4](https://godotengine.org/download) (versão padrão, não a .NET).
2. Abra o Godot, clique em **Importar** e escolha o `project.godot` desta pasta.
3. Aperte **F5** para jogar.

## Controles

A tela de título tem um menu (Jogar, Co-op online, Opções, Controles, Créditos e Sair): setas escolhem, J ou Enter confirmam, K volta. Na seleção de personagem, setas escolhem, J confirma e K volta. Em **Opções** dá para mudar o volume da música e dos efeitos (0 a 10) e ligar a tela cheia no PC; as escolhas ficam salvas.

| Ação | Teclado | Gamepad |
|---|---|---|
| Mover (8 direções) | Setas ou WASD | D-pad ou analógico |
| Soco (combo de 3) | J | A / Cruz |
| Pulo | K | B / Círculo |
| Especial (Erupção) | L | X / Quadrado |
| Lançador (3º golpe) | J, J, cima + J | igual |
| Chute de brasa (3º golpe) | J, J, frente + J | igual |
| Cancelar no especial | L logo depois de um golpe que acertou | igual |
| Correr | Frente, frente e segura | igual |
| Investida | Correndo + J (ou frente, frente + J) | igual |
| Esquiva: rolamento | Shift ou I (com direção rola para lá; sem direção, para trás) | RB / LB |
| Esquiva: passo lateral | Shift ou I + cima/baixo | RB / LB + cima/baixo |
| Pulo baixo / alto | Toque curto em K / segurar K | igual |
| Agarrar | Andar contra um inimigo (correndo não agarra) | igual |
| Pulo cancelado | K logo depois de um golpe que acertou | igual |
| Combo aéreo | No ar: J, J, J (chute, soco, pisão) | igual |
| Joelhada / arremesso | Agarrado: J / direção + J | igual |
| Saltar por cima do agarrado | Agarrado: K | igual |
| Suplex | Agarrado pelas costas (ou depois do salto): direção + J | igual |
| Mostrar caixas de colisão | F1 | |
| Pausa | Esc ou P | Start |
| Jogo online (na tela de título) | O | Y / Triângulo |

## O que já tem

**Heróis jogáveis**

Todos usam os mesmos comandos; o que muda é a arte, a cor do elemento (medidor e especial) e três números. O jogo começa com o Brasa selecionado.

| Herói | Pacote | Vida | Velocidade | Força |
|---|---|---|---|---|
| Brasa, Cavaleiro de Fogo | Fire Knight | 100 | 1,0 | 1,0 |
| Vento, Assassino do Vento | Wind Hashashin | 85 | 1,2 | 0,9 |
| Folha, Arqueira da Folha | Leaf Ranger | 90 | 1,1 | 0,95 |
| Terra, Monge da Terra | Ground Monk | 110 | 1,0 | 1,05 |
| Metal, Guardiã das Lâminas | Metal Bladekeeper | 95 | 1,05 | 1,0 |
| Cristal, Esmagador de Cristal | Crystal Mauler | 120 | 0,9 | 1,15 |
| Água, Sacerdotisa da Água | Water Priestess | 90 | 1,0 | 0,95 |

- Cada golpe usa uma animação do pacote (jab = 1º ataque, direto = 2º, gancho e chute = 3º, lançador = ataque aéreo, investida = rolamento, especial = ataque especial). O quadro em que a arte vai mais longe é alinhado com o primeiro quadro ativo do golpe, então a animação acompanha os números de jogo. Golpe rápido com arte longa mostra só os quadros perto do impacto (no máximo 1 quadro de arte a cada 2 quadros de jogo).
- O alcance de cada golpe acompanha até onde a arte do herói chega, com teto de 48 px (`REACH_CAP` em `player.gd`). A espada do Brasa acerta a 48 px; quem tem arte curta fica perto dos 26 a 32 px de base.
- Os pacotes não têm animação de queda: derrubado, o herói mostra o começo da animação de morte até um quadro "caído" escolhido por herói (`down` em `characters.gd`) e levanta tocando esse trecho ao contrário. A animação de morte inteira aparece quando ele perde uma vida.
- Os acertos continuam usando caixas (F1 mostra), não os pixels do desenho.
- As animações ficam em folhas de no máximo 2048 px de largura, limite seguro de textura em celular.

**Combate (todos os heróis)**
- Movimento em 8 direções com profundidade (90 px/s na horizontal, 60 px/s na profundidade) e ordem de desenho pelos pés.
- Combo jab, direto e gancho (6, 8 e 14 de dano). O próximo golpe só emenda se o anterior acertou; o gancho derruba.
- **Movimentação** (`scripts/player_movement.gd`, todos os números no topo):
  - Andar acelera em 3 quadros e para em 4: continua firme, sem o liga-desliga seco.
  - Corrida com frente, frente e segura: 1,8x na horizontal e 0,7x na profundidade, poeira nos pés. Soltar ou virar derrapa por 9 quadros. Correndo + J é a investida; correndo não agarra.
  - Rolamento (22 quadros, invencível do 1º ao 12º, ~45 px) e passo lateral (14 quadros, invencível até o 9º, ~18 px de faixa). A partir do quadro 14 do rolamento (9 do passo), um soco, pulo ou especial guardado já sai. Intervalo de 12 quadros entre esquivas. Durante a invencibilidade o herói brilha em vez de piscar.
  - Pulo com altura variável (soltar K cedo corta a subida), gravidade extra na descida e controle no ar (segurar uma direção corrige; sem direção mantém o embalo). Dá para virar no ar antes do chute. Pulo da corrida vai cerca de 1,6x mais longe e, pousando com a frente segura, continua correndo.
- Pulo + ataque é um chute que atravessa e derruba.
- Agarrão automático ao encostar: até 2 joelhadas e arremesso para frente ou para trás. O arremessado derruba quem estiver no caminho. K salta por cima do agarrado e o herói pousa nas costas dele; agarrado pelas costas, o arremesso vira suplex (+6 de dano, joga por cima do herói).
- Investida de brasa (frente, frente + ataque).
- **Sistema de combos:**
  - Contador de golpes no canto direito. Cada golpe que acerta um inimigo soma: socos, chutes, joelhadas, arremesso, especial e até o corpo arremessado acertando outro. Sem acertar nada por 1 s, o combo termina (mais curto que a queda e o levantar de um inimigo, então um alvo sozinho não rende combo infinito) e paga dano total x golpes em pontos (a partir de 3 golpes). Se o herói apanhar antes, o bônus se perde. Notas aos 5, 10, 20 e 30 golpes.
  - Três finais para o combo, escolhidos pela direção segurada no 3º J: neutro é o gancho (derruba), cima é o lançador (joga o inimigo para o alto) e frente é o chute de brasa (manda o inimigo voando e ele derruba quem estiver no caminho).
  - Juggle: inimigo lançado pode ser golpeado no ar até 3 vezes; cada golpe o mantém no alto. Lançar de novo um inimigo que já está no ar conta como golpe de juggle (não reinicia o contador). Brutamontes e chefe são pesados demais para serem lançados ou chutados longe.
  - Qualquer golpe que acertou pode ser cancelado na Erupção (L) e o combo continua.
- Medidor elemental: +8 por golpe, +12 por arremesso, zera quando o herói é derrubado. A Erupção gasta 50; sem medidor custa 15 de vida (nunca mata) e também serve para escapar quando está apanhando. Com o medidor cheio, as luvas piscam e os golpes dão +2.
- Hit stop (3 quadros, 6 no golpe que derruba), hit stun de 12 quadros, 40 quadros no chão e 20 de invencibilidade ao levantar.

**Inimigos** (IA de cerco: escolhem lados diferentes e no máximo 2 atacam ao mesmo tempo; todo golpe tem um "!" amarelo de aviso)
- Capanga (30 de vida): chega perto e soca. Variante de paleta: Capanga Brigão, mais rápido e forte.
- Faca (25): só ataca quando o jogador está ocupado ou de costas, golpeia rápido e recua.
- Brutamontes (80): armadura nos 2 primeiros golpes, inclusive contra golpe que derruba (jab, direto e gancho: ele só cai no gancho), não pode ser agarrado, alinha na profundidade e investe com os ombros (15, derruba). Desvie mudando de faixa e puna a recuperação.
- Fundeiro (20): fica longe, atira pedras (6) a cada 2 segundos e foge se o jogador chega perto.
- Guardião de Gelo (110, Gelo): inimigo pesado do Pátio do porto, com a arte do pacote Boss: Frost Guardian (só tem parado, andar, ataque, dano e morte). Armadura nos 2 primeiros golpes, não pode ser agarrado nem lançado, anda devagar e dá um soco de gelo com aviso longo (14, derruba). Entra sozinho numa onda antes de ser misturado.
- Escudeiro (45, Gelo): segura com o escudo golpes de frente que não derrubam ("BLOQUEIO", sem combo nem medidor) e, depois de 3 bloqueios, revida com uma escudada (8, derruba). Cai com chute aéreo, agarrão, golpe pelas costas, golpe que derruba ou com a fraqueza.
- Piromante (24, Fogo): fica a meia distância em qualquer faixa e joga bombas em arco no ponto onde o jogador está; um círculo vermelho marca a queda. A explosão (12, derruba) acerta os inimigos também.
- Esquiva: Capanga (10%), Brigão (25%), Faca (40%) e Piromante (20%) às vezes saem da faixa quando o jogador começa um golpe virado para eles (uma chance por golpe, com espera entre uma esquiva e outra).
- Combo inimigo: o Brigão emenda 2 socos quando o primeiro acerta (o segundo tem antecipação curta).
- Itens que caem: Capanga às vezes solta maçã, Brigão moedas, Brutamontes frango, Piromante orbe, Escudeiro maçã.
- Chefe Ferrugem (300), três fases:
  - Fase 1: soco de pedra (20, derruba), pisada que manda um abalo pela faixa dele (15; pule ou mude de faixa) e, de longe, arremesso de pedra em arco no ponto onde o jogador está (14, derruba; saia do círculo).
  - Fase 2 (50%): a armadura quebra e ele acelera; os golpes saem mesmo apanhando na antecipação. Ganha o salto: pula no jogador, marca o ponto de queda e cai com área (18, derruba) e dois abalos. No ar não pode ser atingido.
  - Fase 3 (25%, "FÚRIA!"): mais rápido, chama um Capanga e um Brigão e emenda a pisada logo depois do soco.

**Fraquezas elementais**

Cada inimigo tem um elemento. Golpe de herói do elemento fraco tira 1,5x e aparece "FRACO!"; se o golpe derruba, quebra a armadura na hora (Brutamontes, Ferrugem na fase 1). Elemento resistente tira 0,75x ("RESISTE"). A barra do inimigo mostra o elemento e a fraqueza.

| Inimigo | Elemento | Fraco contra | Resiste |
|---|---|---|---|
| Capanga | neutro | | |
| Capanga Brigão | Fogo | Água | Fogo |
| Faca | Vento | Terra, Cristal | Vento |
| Brutamontes | Metal | Água, Terra | Vento, Folha |
| Fundeiro | Folha | Fogo, Vento | Água, Terra |
| Piromante | Fogo | Água | Fogo |
| Escudeiro | Gelo | Metal, Terra | Água |
| Guardião de Gelo | Gelo | Fogo, Metal | Água |
| Ferrugem | Terra | Água, Folha | Terra |

**Cenários**

O padrão é o ferro-velho original (pacote Dump Vector Tileset, CraftPix). Também dá para jogar em 4 cenários
elementais com arte gerada em código por `tools/gerar_cenarios.py` (provisória: a arte deles vai ser trocada).
Cada cenário fica em `assets/scenery/biomas/<id>/` (`bg_1..4.png`, `chao.png`, `barril.png`, `caixa.png`, `props/`)
e é descrito na tabela `BIOMES` de `scripts/stage_scenery.gd`; para pôr arte nova, troque os arquivos da pasta
e a lista de objetos do bioma. Na seleção de personagem, **Shift ou I (RB/LB no controle) troca o cenário** (L fica para a dificuldade);
no online, o host troca com Shift/I na sala e o cenário vai para todos.

| Cenário | Seções | Destaques |
|---|---|---|
| Cânion de Terra | Trilha do cânion, Mina de âmbar, Círculo de pedras | paredões com estratos, chaminés de pedra, cristais de âmbar, carrinho de mina, menir com espiral |
| Deserto Escaldante | Mar de dunas, Ruínas do oásis, Templo soterrado | mesas ao longe, dunas, cactos, palmeiras, colunas e arco em ruínas, crânio e ossos |
| Floresta Antiga | Trilha da mata, Bosque antigo, Clareira do santuário | árvores grandes, moitas com flores, cogumelos, troncos caídos, pedras com musgo |
| Vulcão em Fúria | Encosta de cinzas, Rio de lava, Cratera do vulcão | vulcão com lava descendo, cachoeiras de lava, chão de basalto com veios acesos, obsidiana, fumarolas |

Cada bioma tem céu, 3 camadas de fundo, chão, 15 a 22 objetos e o próprio barril e caixa quebráveis
(barril de madeira, ânfora, urna de pedra, caldeirão de magma). Para mudar a arte, edite o gerador e rode
`python3 tools/gerar_cenarios.py` (precisa de numpy, scipy e Pillow). A câmera só enxerga a faixa de baixo
das camadas do fundo (veja o comentário em `sky()`), então o que importa fica perto do horizonte.

**Dificuldade**

Na seleção de personagem, **L** troca entre Fácil, Normal e Difícil (tabela `LEVELS` em `scripts/difficulty.gd`:
vida dos inimigos, dano recebido, espera entre ataques, atacantes juntos, vidas e comida). No online vale o nível do host.

**Versão web e Windows**

`export_presets.cfg` tem os presets "Web" (sem threads, sem co-op online: o item e a tecla O somem no navegador)
e "Windows" (um `.exe` só, com co-op online). Veja `COMO-PUBLICAR-NO-ITCH.md`.

**Fase 1: Bairro do Porto**
- Três seções (Rua do cais, Armazém, Pátio do porto), cada uma com sua paleta, scroll lateral e trava de câmera nos encontros, com "GO! >>" quando libera.
- 12 ondas em 6 travas, terminando no chefe. Cada seção apresenta um inimigo novo sozinho antes de misturá-lo, e a comida vem depois dos encontros mais duros.
- Ritmo das ondas: os 2 primeiros inimigos entram juntos e o resto em fila (um a cada 28 quadros, alternando os lados). Travas com `overlap` soltam a próxima onda quando sobra 1 inimigo, sem tela vazia no meio. O último inimigo da trava se enfurece (mais rápido, ataca sem esperar vaga) para a luta não morrer num inimigo que só rodeia.
- Emboscadas no meio do scroll (sem travar a câmera): uma Faca na Rua do cais, Fundeiro e Capanga no Armazém.
- Objetos: lixeira (1 golpe), caixa (2 golpes, balança no primeiro) e barril explosivo: o golpe acende o pavio, ele pisca por 0,75 s e explode (20, derruba) em todo mundo por perto, jogador incluído; a explosão acende outros barris. Soltam maçã (+20 de vida), frango (+50), moedas (+1.000 pontos) ou orbe elemental (+50 de medidor).
- Tela de título com menu e opções de volume, menu de pausa (continuar, recomeçar a seção, opções, menu principal; a música abaixa enquanto pausado), fim de jogo com menu (continuar do início da seção, com os pontos zerados, ou voltar ao título) e tela de vitória.
- **Tela de vitória:** "FASE CONCLUÍDA!" cai letra por letra, a fanfarra toca e sobe um painel com o herói, tempo, inimigos derrotados, maior combo e quedas; os bônus de vida e de tempo e o total são contados com som, e no fim a nota da fase (D a S) é carimbada. J pula a contagem. Depois: jogar de novo, escolher outro herói ou menu principal. A nota soma até 3 pontos pelo tempo (menos de 4, 6 ou 8 min), 3 por cair pouco (0, até 2, até 4 quedas) e 3 pelo maior combo (30, 15 ou 8 golpes): S com 8 ou mais, A com 6, B com 4, C com 2. Fica em `Stage.stage_rank`.
- Três vidas, vida extra a cada 20.000 pontos.
- Telas mais largas que 16:9 (celular 20:9) mostram mais cenário dos dois lados, e a arena e os pontos de spawn acompanham a largura visível. No celular e na web a escala é fracionária (sem barras pretas); no PC continua inteira. O jogo pausa sozinho quando a janela perde o foco ou o app vai para o fundo.

**Fase 2: Cemitério de Ferro** (`scripts/fases.gd`)
- Escolha no título (linha **Fase**, setas para os lados) ou no fim da fase 1 com **Próxima fase** (os pontos e as vidas passam junto). Online, por enquanto, só a fase 1.
- Três seções (Portão do ferro-velho, Pilhas de sucata, Prensa enferrujada), 13 ondas em 6 travas e 2 emboscadas. A Sombra aparece sozinha na primeira trava e a Curandeira atrás de um Brutamontes.
- **Sombra** (34, Sombra; fraca contra Fogo e Cristal): luta como o Faca e tem o Passo Sombrio: some piscando (dá para acertar e cancelar), fica invisível e intocável, e reaparece nas costas do herói com um corte de "!" de 16 quadros.
- **Curandeira** (40, Água; fraca contra Folha e Terra): fica longe e reza brilhando em verde ("CURA..."); no fim, quem está ferido perto dela recupera 20 de vida. Um golpe na reza cancela a cura. Não cura chefe. Encurralada, dá um jato d'água que empurra.
- **Chefe Corrosão, a Lâmina Enferrujada** (340, Metal; fraca contra Fogo e Terra), três fases:
  - Fase 1 (armadura): corte duplo (o 2º derruba), lâmina giratória que vai e volta na faixa dela (mude de faixa ou pule) e guarda: segura golpes de frente que não derrubam e revida no 2º bloqueio. Quebra a guarda: golpe que derruba, pelas costas, pulando ou com a fraqueza.
  - Fase 2 (50%): sem armadura e mais rápida; investida cortante que mira a faixa do herói e marca no chão onde vai parar.
  - Fase 3 (25%, "FÚRIA!"): chama duas Sombras, ganha a chuva de lâminas (três lâminas em arco, no herói e dos lados) e o corte duplo emenda nela.
- **Cenário provisório:** o ferro-velho à noite. Para trocar pela arte nova, veja o comentário no topo de `scripts/fases.gd` (pasta, camadas, chão, objetos, céu e luzes ficam na chave `scenery` da fase).

## Sensação do combate e combos (versão 2)

- **Hit stop pelo peso do golpe:** jab 3 quadros, direto 4, gancho 8, chute de brasa 9, especial 10. Contra-ataque soma 4 e o golpe que zera a vida congela 12. Quem apanha treme durante o congelamento.
- **Empurrão:** o alvo atordoado desliza para trás e freia, em vez de pular 3 px.
- **Cancelamentos:** golpe que acertou, depois do quadro ativo, emenda o próximo J na hora (sem esperar a recuperação) e K cancela num pulo que vai atrás do inimigo. O cancelamento no especial (L) continua.
- **Combo aéreo:** no ar, J, J, J (chute, soco, pisão). O 2º e o 3º só saem se o anterior acertou. Acertar um inimigo no ar segura o herói lá em cima (até 3 vezes por pulo).
- **Pisão e quique:** o pisão crava o inimigo no chão; ele quica uma vez por voo e aguenta mais 2 golpes.
- **Juggle com decaimento:** até 6 golpes no ar, e cada um levanta 14% menos, então o combo termina sozinho.
- **Contra-ataque:** acertar o inimigo durante o "!" tira 50% a mais e mostra "CONTRA!".
- **Escala de dano:** do 6º golpe do combo em diante cada golpe tira 7% menos, até no mínimo 40%.
- **Nota de estilo:** D, C, B, A, S e SS. Cada golpe vale 1 ponto, mais por contra-ataque, golpe aéreo, cancelamento, juggle e golpe final; repetir o mesmo golpe 3 vezes seguidas vale metade. A nota multiplica o bônus do combo (B x1,25, A x1,5, S x2, SS x3). O HUD mostra a nota, a barra de tempo do combo e os destaques.
- **Números de dano** sobem de cada inimigo atingido, e **câmera lenta** quando o golpe derruba o último inimigo de pé (mais longa no chefe).
- Vitrine para gravar vídeo: `godot --path . --fixed-fps 60 --write-movie /tmp/combos/f.png --script res://tests/combo_showcase.gd`.

## Golpes próprios de cada herói

Além do combo comum, cada herói tem quatro golpes só dele, com a cara do elemento, e dois heróis juntos podem soltar um ataque em dupla. Os comandos são os mesmos para todos:

| Comando | Golpe |
|---|---|
| Trás + J | golpe de virada (vira e bate em quem estava atrás) |
| Segurar J por meio segundo e soltar | ataque carregado (o herói pisca na cor do elemento quando está pronto) |
| Baixo + L | especial secundário (30 do medidor; sem medidor custa 10 de vida e nunca mata) |
| No ar: baixo + J | golpe aéreo próprio |
| Os dois heróis apertam L juntos, perto um do outro | ataque em dupla: fusão dos dois elementos |

| Herói | Trás + J | Carregado | Baixo + L | Aéreo |
|---|---|---|---|---|
| Brasa (Fogo) | Lâmina Reversa: queima | Espada Incandescente: derruba e queima | Bola de Fogo: projétil que queima | Meteoro: mergulho com explosão |
| Vento | Passo do Vento: surge atrás do inimigo | Lâmina Ciclone: giro de vários cortes que puxa | Corte de Vácuo: projétil rápido que atravessa | Mergulho do Falcão: mergulho longo de vários cortes |
| Folha | Salto Recuado: pula para trás e atira | Flecha Perfurante: atravessa a fila | Raízes Prendedoras: prende quem está a até 140 px | Chuva de Flechas: acerta o chão à frente |
| Terra | Cotovelada de Pedra | Punho Sísmico: com armadura, solta um tremor pelo chão | Pilares de Pedra: lança todos em volta | Queda de Rocha: cai reto e faz o chão tremer |
| Metal | Lâmina Giratória: corta dos dois lados | Estocada de Aço: avança longe | Postura de Aço: contra-ataque (apanhou, revida com 24) | Chuva de Lâminas |
| Cristal | Ombro de Cristal: avança e derruba | Esmagamento: com armadura, área grande | Estilhaços: três projéteis em três faixas | Bigorna: cai reto e lança quem está em volta |
| Água | Contracorrente: empurra | Maré: onda que atravessa e arrasta | Fonte de Cura: cura 20 e afasta todos (só com 40 de medidor) | Gota Cadente: mergulho que empurra na queda |

- **Queimadura:** 2 de dano a cada 1/3 de segundo, por alguns pulsos; nunca mata.
- **Congelamento:** o inimigo fica parado e azulado (não anda, não ataca e o tempo dele não corre). Um golpe que derruba estilhaça o gelo. Brutamontes e chefe ficam congelados só metade do tempo.
- **Armadura:** durante o golpe o herói leva o dano mas não é interrompido nem derrubado.
- **Ataque em dupla:** sai quando os dois especiais começam com até 15 quadros de diferença e os heróis estão a até 90 px. O nome muda com o par (Fogo + Vento é Tornado de Fogo, Água + Terra é Lamaçal, Fogo + Terra é Magma...). Precisa do multiplayer: os heróis entram no grupo `players` e a fusão procura o parceiro ali.
- O nome do golpe aparece no alto da tela quando ele sai.
- Tudo fica em `scripts/hero_moves.gd`: cada golpe é uma linha de dados (dano, alcance, animação e efeitos). Os projéteis estão em `scripts/hero_projectile.gd` (arte em `assets/heroes_fx`) e a queimadura e o congelamento em `scripts/element_status.gd`.
- `tests/showcase_moves.gd` grava a vitrine dos golpes: `godot --path . --fixed-fps 60 --write-movie golpes.avi --script res://tests/showcase_moves.gd`.

## Co-op online (2 a 4 jogadores)

Na tela de título, **O** (ou Y/Triângulo no gamepad) abre a sala online.

1. Um jogador escolhe **Criar sala**. A tela mostra o IP dele e a porta (7777).
2. Os outros escolhem **Entrar numa sala**, digitam esse IP e apertam Enter.
3. Na sala, setas trocam o herói, J marca pronto. Com todos prontos (mínimo 2), a fase começa sozinha.

Não precisa de servidor: o host é o servidor. Na mesma rede (Wi-Fi de casa) funciona direto. Pela internet, o host precisa liberar a porta UDP 7777 no roteador (redirecionamento de porta) ou os jogadores usam uma VPN de jogo como Tailscale, ZeroTier ou Radmin VPN e digitam o IP dela.

**Como funciona.** O host roda a fase inteira (inimigos, golpes, dano, itens) e é a única autoridade. Cada cliente manda os comandos do teclado para o host a cada quadro e recebe de volta uma foto compacta de todos os atores (cerca de 350 bytes por quadro, 21 KB/s por jogador), que ele só desenha. Por isso a lógica do combate não sabe de rede: o herói de um cliente, no host, é um `Player` comum com o controle em modo `scripted`. O cliente sente o atraso da conexão nos próprios golpes (sem previsão local); em rede local é imperceptível.

- Inimigos escolhem o herói mais perto, com desconto para quem já está cercado, então o grupo se divide. Cada jogador extra abre mais uma vaga de ataque.
- A câmera segue quem vai na frente sem deixar ninguém para trás da tela. Pontos são do time; vida extra vale para todos.
- Fim de jogo só quando todos ficam sem vidas. O host aperta J para continuar (todos voltam juntos) e, com a fase concluída, todos voltam para a sala.
- Online não tem pausa. Se um cliente cai, o herói dele some; se o host cai, todos voltam para a sala com o aviso.

Arquivos: `scripts/net/net.gd` (autoload `Net`: conexão, sala e RPCs), `scripts/net/net_session.gd` (foto da fase e comandos), `scripts/net/lobby.gd` + `scenes/lobby.tscn` (sala), `scripts/net/net_bot.gd` (robô de teste).

Teste automático com duas instâncias sem janela: `tools/teste_coop.sh <caminho do godot>`. Para abrir na mão duas janelas na mesma máquina: `godot --path . -- --net-host` e `godot --path . -- --net-join=127.0.0.1` (acrescente `--bot` para um robô jogar).

## Onde ajustar a sensação

Os números ficam em constantes no topo de cada script, com os valores do GDD como ponto de partida:

- `scripts/characters.gd`: elenco, vida, velocidade, força, cor e escala de cada herói.
- `scripts/player.gd`: velocidade, pulo, golpes do combo (`COMBO`), investida, especial, medidor e qual animação cada golpe usa (`ATTACK_ANIMS`).
- `scripts/fighter.gd`: hit stop, hit stun, tempo no chão, invencibilidade, faixa de profundidade.
- `data/enemies/*.tres`: vida, dano, velocidade e ritmo de ataque de cada inimigo. Dá para editar pelo Inspector do Godot. Uma variante de paleta é só uma cópia do `.tres` com outra cor.
- `scripts/view_3d.gd`: câmera (altura, distância, inclinação, campo de visão) e escala da profundidade (`DEPTH_SCALE`).
- `scripts/stage.gd`: layout da fase (`SECTIONS`: travas, ondas, lixeiras e caixas), quantos inimigos atacam juntos, bônus.
- `scripts/boss.gd`: golpes e fases do Ferrugem.
- `data/enemies/*.tres`: também o elemento, as fraquezas, a chance de esquiva, o combo e o item que cai de cada inimigo.
- `scripts/stage.gd`: `SPAWN_STAGGER` (fila de entrada), `overlap` e `ambushes` em `SECTIONS`.

## Estrutura

```
scenes/title.tscn      tela de título com menu (cena inicial)
scenes/select.tscn     seleção de personagem
scenes/lobby.tscn      sala do co-op online
scenes/main.tscn       Stage (lógica, escondida), View3D (o que aparece) e HUD
scenes/player.tscn     herói (a arte vem do personagem escolhido)
scenes/enemy.tscn      inimigo genérico; o arquétipo vem de um EnemyData
scenes/boss.tscn       Ferrugem
data/enemies/*.tres    arquétipos e variantes de paleta
scripts/fighter.gd     classe base: estados, golpes, dano, armadura, pseudo-3D
scripts/player.gd      controles, combo, pulo, agarrão, especial, vidas, escolha da animação
scripts/player_movement.gd  aceleração, corrida, esquiva, controle no ar, salto no agarrão
scripts/characters.gd  elenco jogável e leitura da arte
scripts/character_sprite.gd  desenha o herói a partir das tiras de animação
scripts/select.gd      tela de seleção
assets/characters/     tiras de animação dos 7 heróis, do Guardião de Gelo (inimigo) e characters.json (quadros, pés, quadro do golpe)
tools/pack_sprites.py  gera assets/characters a partir dos zips originais
scripts/enemy.gd       IA de cerco dos 6 arquétipos, esquiva, escudo, fraquezas
scripts/boss.gd        chefe
scripts/stage.gd       scroll, travas, ondas, itens, pontuação
scripts/projectile.gd  pedra e abalo
scripts/lob.gd         bomba e pedra em arco, com o círculo no chão
scripts/breakable.gd   lixeiras, caixas e barris explosivos
scripts/item.gd        comida e moedas
scripts/hud.gd         HUD, menu de pausa, fim de jogo e tela de vitória
scripts/settings.gd    opções salvas (volumes, tela cheia) e barramentos de áudio
scripts/ui/            lista de menu, submenu de opções e desenho de texto/heróis
scripts/view_3d.gd     câmera 3D, luzes e o espelho 3D de cada ator (sprite, blocos, sombras)
scripts/stage_scenery.gd  cenário 3D dos 4 biomas (fundo em camadas, chão e objetos)
tools/gerar_cenarios.py   gera a arte dos biomas (tools/pixel.py tem as formas e o sombreado)
tests/test_runner.gd   testes do combate e da fase
tests/playthrough.gd   robô que joga a fase inteira
tests/vitrine_inimigos.gd  vídeo das novidades de inimigos, ritmo e chefe
tests/test_menus.gd    testes do menu, opções, pausa e vitória
tests/vitrine_menus.gd vídeo do menu, pausa e vitória (com som)
scripts/net/           co-op online (sala, sessão da fase, robô)
tools/teste_coop.sh    teste do co-op com host e cliente sem janela
```

Na lógica, `position.y` é a profundidade (onde ficam os pés) e a altura do pulo fica em `height`, que só desloca o desenho. O `View3D` converte isso para o 3D: x vira x, a altura vira y e a profundidade vira z (`View3D.to_3d`). Como a perspectiva mostra mais largura no fundo do chão, os inimigos nascem mais longe da borda quando estão lá atrás (`Stage.offscreen_margin`). Os golpes são checados contra caixas (profundidade, alcance e altura), nunca contra os pixels.

## Inimigos e cenário

| Inimigo | Arte | Papel |
|---|---|---|
| Capanga | Samurai | briga em grupo |
| Capanga Brigão | Samurai tingido de vermelho | variante mais forte |
| Faca | Demônio | ataca rápido e recua |
| Brutamontes | Samurai Comandante | escudo e investida |
| Fundeiro | Samurai Arqueiro | atira flechas de longe |
| Ferrugem (chefe) | Bruxa | soco de pedra e pisada mágica |

A arte, a escala e a tinta de cada um ficam no `.tres` em `data/enemies` (grupo "Arte"). O cenário é escolhido entre 4 biomas elementais (veja a seção Cenários): as 4 camadas do fundo ficam em painéis a distâncias diferentes, o chão tem a textura do bioma e os objetos ficam em pé no chão, em `scripts/stage_scenery.gd`. Créditos e licenças em `assets/characters/CREDITS.md`.

## Som e música

O autoload `SoundBank` (`scripts/sound_bank.gd`) carrega tudo de `assets/audio/sfx` e
`assets/audio/music`. No código, chame a classe `Sound`: `Sound.play("hit")`,
`Sound.special(elemento)`, `Sound.music("fase")`. Arquivos `nome_1`, `nome_2` viram
variações sorteadas de `nome`. Para trocar um som, substitua o .ogg com o mesmo nome.
Créditos em `assets/characters/CREDITS.md`.

Os efeitos tocam no barramento de áudio "SFX" e a música no "Music", criados pelo autoload
`Settings` (`scripts/settings.gd`), que guarda os volumes em `user://opcoes.cfg`. Sons de
interface usam `Sound.ui("nome")`, que não é repassado aos outros jogadores no online.

Músicas e efeitos originais (CC0), gerados por `tools/gerar_audio.py` (precisa de numpy e
ffmpeg; `python3 tools/gerar_audio.py assets/audio` refaz todos):

| Arquivo | Onde toca |
|---|---|
| `music/selecao.ogg` | escolha de herói (loop) |
| `music/vitoria.ogg` | fanfarra da vitória (uma vez) |
| `music/resultado.ogg` | tela de vitória depois da fanfarra (loop) |
| `sfx/dodge`, `land` | esquiva e pouso de pulo alto |
| `sfx/grab`, `throw` | agarrão e arremesso |
| `sfx/alert` | bipe junto do "!" do aviso de golpe inimigo |
| `sfx/block`, `counter` | inimigo bloqueando e contra-ataque |
| `sfx/charge_ready` | J segurado chegou no golpe carregado |
| `sfx/rank_up` | nota de estilo do combo subiu |
| `sfx/go`, `boss_intro`, `extra_life` | "GO!", chegada do chefe e vida extra |
| `sfx/tally`, `tally_end`, `stamp` | contagem e nota da tela de vitória |
| `sfx/menu_open`, `menu_close` | abrir e fechar submenus e a pausa |

## Efeitos visuais

Faíscas de golpe, poeira na queda, barril quebrando, itens e o especial de cada elemento
vêm do PVFX Foundry (CC0), em `assets/vfx`. A lógica chama `stage.fx("hit", posição, altura)`
e o `View3D` toca a animação de frente para a câmera. Para trocar ou acrescentar um
efeito, edite `EFFECTS` em `tools/pack_vfx.py` e rode
`python3 tools/pack_vfx.py <pasta do pacote extraído>`.

## Arte dos heróis

As tiras em `assets/characters` saem dos PNGs originais dos pacotes. Para atualizar (por exemplo, com a versão paga de um pacote), extraia cada zip numa subpasta e rode:

```
python tools/pack_sprites.py <pasta com os zips extraídos>
```

Precisa de Python 3 com Pillow. O script recorta a área usada, acha o ponto dos pés e o quadro de maior alcance de cada golpe.

**Créditos:** heróis dos pacotes Elementals e o inimigo Guardião de Gelo (Boss: Frost Guardian), de [chierit](https://chierit.itch.io), licença CC-BY 4.0. O crédito aparece na tela de título e em `assets/characters/CREDITS.md`; o autor pede para não revender os pacotes.

## Testes

Os testes rodam o jogo de verdade, sem janela, e conferem dano, combo, profundidade, agarrão, especial, cada inimigo, o chefe, a câmera e os itens. O robô joga a fase inteira e avisa se ela travar. Com janela, ele salva capturas em `user://shots` ou na pasta passada depois de `--`:

```
godot --headless --path . --import
godot --headless --path . --fixed-fps 60 --script res://tests/test_runner.gd
godot --headless --path . --fixed-fps 60 --script res://tests/test_movement.gd
godot --headless --path . --fixed-fps 60 --script res://tests/playthrough.gd
tools/teste_coop.sh godot                                        # co-op rápido (40 s)
HOST_FRAMES=30000 CLIENT_FRAMES=29000 tools/teste_coop.sh godot  # co-op na fase inteira, confere o ataque em dupla
```

### Equilíbrio

`tests/balanco.gd` joga a fase com um robô "habilidoso" (lançador, pulo cancelado, combo aéreo, esquiva no aviso, golpe de virada e especial 2) ou com o robô básico (só jab e especial), e mostra mortes, vida perdida e tempo:

```
godot --headless --path . --fixed-fps 60 --script res://tests/balanco.gd -- fire_knight habil
godot --headless --path . --fixed-fps 60 --script res://tests/balanco.gd -- fire_knight habil sem_esquiva
godot --headless --path . --fixed-fps 60 --script res://tests/balanco.gd -- fire_knight basico
```

Medição da versão completa (Brasa, Vento, Gelo e Água; 3 vidas por continue): o robô básico perde de 540 a 790 de vida (4 a 5 mortes); o habilidoso sem esquiva, de 500 a 720 (3 a 6 mortes), igual à frente de inimigos sozinha (752, 6 mortes); com esquiva perfeita no aviso, de 380 a 480 (1 a 4 mortes). Ou seja, as ferramentas novas de combo não deixaram a fase com os inimigos novos mais fácil; o que mais reduz o dano é esquivar no "!", que é habilidade do jogador.

## Próximos passos

Ajustar a sensação e a dificuldade jogando, arte dos inimigos e do cenário 3D (modelos low-poly com textura pixelada no lugar das caixas), armas de chão (cano e faca), som e música. Depois, exportação para web e Android com controles de toque (etapa 4).
