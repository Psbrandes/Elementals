# Guia: jogar o co-op do Elementals pela internet

Um jogador é o **host** (cria a sala) e os outros entram pelo IP dele. Só o host precisa estar
"alcançável". Escolha para host quem tem a melhor internet, de preferência no cabo.

## 1. Todo mundo com a mesma versão

Todos precisam da mesma pasta do jogo (`elementals-coop-internet.zip`). Quem tem o Godot 4.4.1 abre o
projeto e aperta F5. Para amigos sem Godot, exporte um executável: **Projeto > Exportar > Adicionar >
Windows Desktop > Exportar projeto** (na primeira vez o Godot pede para baixar os "export templates").

A versão de navegador (itch.io) **não serve para o co-op online**: o navegador não abre conexões UDP,
que é o que o jogo usa. Para jogar online com amigos, use o executável.

## 2. Ligar os computadores (escolha um caminho)

### Caminho A: Tailscale (recomendado, sem mexer no roteador)

1. Todos instalam o Tailscale (tailscale.com/download) e entram com uma conta (Google serve).
2. O host convida os amigos: no painel do Tailscale, **Machines > (o PC do host) > Share**, e manda o
   link. Ou todos entram na mesma conta/rede ("tailnet").
3. No jogo, o host abre a sala: na tela de título aperte **O**, escolha **Criar sala**. A sala mostra
   o IP do host; o IP do Tailscale começa com **100.** e aparece primeiro.
4. O amigo escolhe **Entrar numa sala** e digita esse IP (100.x.y.z).

Funciona mesmo com internet de operadora que não deixa abrir porta (CGNAT, comum em fibra no Brasil).
Radmin VPN e ZeroTier funcionam do mesmo jeito (o IP do Radmin começa com 26.).

### Caminho B: abrir a porta no roteador do host

1. No roteador do host, crie um redirecionamento de porta (port forwarding): **UDP 7777** para o IP
   local do PC do host (o IP 192.168... que a sala mostra).
2. O amigo digita o IP público do host (veja em "qual é meu ip" no Google).
3. Se não conectar, compare o "IP WAN" que aparece no roteador com o IP público. Se forem
   diferentes, a operadora usa CGNAT e a porta nunca vai abrir: use o Caminho A.

Para usar outra porta, o amigo digita `IP:porta` (ex.: `100.101.102.103:7800`) e o host abre o jogo com
`-- --port=7800`.

### Firewall do Windows (os dois caminhos)

Na primeira vez que o host cria a sala, o Windows pergunta se o Godot (ou o Elementals.exe) pode usar a
rede: marque **redes privadas e públicas** e clique em Permitir. Se clicou em Cancelar, libere em
"Permitir um aplicativo pelo Firewall do Windows".

## 3. Durante o jogo

- **F3** mostra/esconde o painel de rede, embaixo à direita:
  - **ping**: ida e volta até o host. Até 100 ms fica ótimo; 100 a 180 ms joga bem; acima de 200 ms os
    golpes começam a sair visivelmente depois do botão.
  - **espera**: quanto a tela fica atrás da foto mais nova para não tremer. Sobe sozinha quando a rede
    oscila.
  - **perda**: fotos que não chegaram. Até uns 5% quase não se nota (o jogo preenche as que faltam).
- O seu herói **anda na hora**, sem esperar o host. **Golpes, pulo e esquiva** são decididos pelo host e
  aparecem depois de um ping (é o preço de ninguém conseguir trapacear e todos verem a mesma luta).
- O host joga sem atraso nenhum.

## 4. O que me contar depois do teste

1. Os números do painel (ping, espera, perda) de cada amigo.
2. "Meu herói andando parece normal?" e "os golpes parecem atrasados?".
3. Se alguém viu o herói "voltar para trás" ou dar trancos, em que situação (correndo, agarrando...).
4. Quem foi o host e como cada um estava conectado (Wi-Fi ou cabo, cidade).

## 5. Testar sozinho, sem amigos

Dá para simular internet ruim em um PC só, com duas janelas do jogo:

1. No Godot: **Depurar > Personalizar instâncias de execução**, ligue "Ativar várias instâncias" com 2.
2. Rode (F5). Numa janela crie a sala, na outra entre em `127.0.0.1`.
3. Na fase, aperte **F8** nas duas janelas para trocar o perfil de rede: rede boa (40 ms), Brasil-Brasil
   (80 ms), longe (160 ms), ruim (250 ms com 8% de perda). Cada janela atrasa o que ela manda, então
   use o mesmo perfil nas duas.

Pela linha de comando também: `-- --lag=40 --jitter=15 --loss=1` (atraso e variação em ms, perda em %,
de cada lado).
