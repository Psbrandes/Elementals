# Elementals no navegador e no itch.io

Dois arquivos, os dois gerados da versão unificada (`prototipo/unificada/`), Godot 4.4.1:

- `prototipo/unificada/elementals-web.zip` (14 MB): roda no navegador, só para jogar sozinho. Modelo Web sem
  threads, então o itch.io roda sem configuração extra.
- `prototipo/unificada/elementals-windows.zip` (38 MB): pasta `Elementals` com o `Elementals.exe` (tudo dentro de
  um arquivo só) e o `COMO-JOGAR-ONLINE.md` (o guia do co-op pela internet). É esse que serve para jogar
  online com amigos.

## O que muda na versão web

- **Sem co-op online.** O co-op usa ENet (UDP), que o navegador não permite. Na versão web a tecla O não abre
  a sala e a dica dela some da tela de título. O resto do jogo (7 heróis, combos, fase, chefe, som) é igual.
- O som só começa depois do primeiro clique ou tecla (regra dos navegadores).
- Esc no navegador em tela cheia também sai da tela cheia; a pausa continua funcionando.

Mudanças no código (`versao-web.patch`): `scripts/title.gd` esconde o online quando roda na web, e
`export_presets.cfg` novo com os presets "Web" e "Windows" (inclui os `.json` dos personagens e efeitos, tira `tests/` e
`tools/`).

## Testar no seu computador antes

Abrir o `index.html` direto com dois cliques não funciona; o jogo precisa de um servidor. Descompacte o zip,
abra o terminal na pasta e rode:

```
python -m http.server 8000
```

Depois abra http://localhost:8000 no Chrome ou Firefox.

## Subir no itch.io

1. Entre em https://itch.io/game/new (com a sua conta).
2. **Title:** Elementals. **Kind of project:** HTML.
3. Em **Uploads**, envie `elementals-web.zip` e marque **This file will be played in the browser**.
4. Em **Embed options**:
   - Viewport dimensions: **1152 x 648** (o jogo é 16:9 e escala sem borrar).
   - Marque **Mobile friendly** só se quiser; o jogo pede teclado ou controle.
   - Marque **Fullscreen button**.
   - **SharedArrayBuffer support**: pode deixar desmarcado (o build é sem threads).
5. Ainda em **Uploads**, clique em **Upload files** de novo e envie `elementals-windows.zip`. Nesse
   arquivo **não** marque "played in the browser"; marque o ícone do **Windows**. O nome que aparece
   para quem baixa pode ser "Elementals para Windows (co-op online)".
6. **Visibility & access:** escolha **Draft** para testar sozinho, ou **Restricted** e envie o link com
   senha para quem vai testar. Mude para **Public** só quando quiser que qualquer pessoa ache o jogo.
7. Salve e abra a página do jogo para conferir.

Sobre o Windows: o `.exe` não tem assinatura digital, então na primeira vez o Windows mostra "O Windows
protegeu o computador". Quem baixar clica em **Mais informações > Executar assim mesmo**. Vale avisar isso
na página. Depois, ao criar a sala, o Firewall pergunta se o Elementals pode usar a rede: permitir em redes
privadas e públicas.

Sugestão de texto para a página: "Beat 'em up em pixel art com 7 heróis elementais. Setas/WASD movem,
J ataca, K pula, L solta o especial. Funciona com controle. Jogue sozinho aqui no navegador, ou baixe a
versão para Windows para jogar em co-op online com amigos (tecla O na tela de título)."

Créditos que precisam aparecer na página (licenças CC-BY): heróis "Elementals" por chierit (CC-BY 4.0),
música de xDeviruchi (CC-BY-SA 4.0), efeitos do 400 Sounds Pack (Chequered Ink) e Pixabay.

## Gerar de novo depois de mudar o jogo

Com o Godot 4.4.1 e os modelos de exportação instalados (Editor > Manage Export Templates), na pasta do
projeto:

```
godot --headless --export-release "Web" ../build/web/index.html
godot --headless --export-release "Windows" ../build/win/Elementals.exe
```

Depois compacte o conteúdo de `build/web` (o `index.html` precisa ficar na raiz do zip) e a pasta com o
`Elementals.exe`, e suba de novo no mesmo jogo do itch.io (substituindo os arquivos antigos).
