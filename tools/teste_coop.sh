#!/bin/bash
# Teste do co-op online: abre um host e um cliente sem janela, os dois com o
# robô jogando, e confere se a fase anda nas duas pontas.
#   tools/teste_coop.sh [caminho do godot]
# Partida longa (fase inteira, confere o ataque em dupla):
#   HOST_FRAMES=30000 CLIENT_FRAMES=29000 tools/teste_coop.sh [caminho do godot]
GODOT=${1:-godot}
cd "$(dirname "$0")/.."
LOG=${COOP_LOG:-$(mktemp -d)}; mkdir -p "$LOG"
"$GODOT" --headless --path . --quit-after ${HOST_FRAMES:-2400} -- --net-host --bot --log --hero=fire_knight > "$LOG/host.log" 2>&1 &
HOST=$!
sleep 2
"$GODOT" --headless --path . --quit-after ${CLIENT_FRAMES:-2200} -- --net-join=127.0.0.1 --bot --log --hero=water_priestess > "$LOG/cliente.log" 2>&1
wait $HOST
grep "^\[" "$LOG/host.log" | tail -2
grep "^\[" "$LOG/cliente.log" | tail -2
fail=0
grep -q "Água(peer" "$LOG/host.log" || { echo "FALHA: o herói do cliente não apareceu no host"; fail=1; }
grep -q "^\[CLIENTE\].*Brasa(peer 1)" "$LOG/cliente.log" || { echo "FALHA: o cliente não recebeu o herói do host"; fail=1; }
grep "^\[CLIENTE\]" "$LOG/cliente.log" | grep -qv "onda=0" || { echo "FALHA: o cliente não viu nenhuma onda"; fail=1; }
if [ -n "$HOST_FRAMES" ]; then
	# Partida longa: o ataque em dupla precisa sair e o cliente precisa ver.
	grep "^\[HOST\]" "$LOG/host.log" | tail -1 | grep -qv "duplas=0" || { echo "FALHA: nenhum ataque em dupla"; fail=1; }
	grep "^\[CLIENTE\]" "$LOG/cliente.log" | tail -1 | grep -qv "duplas=0" || { echo "FALHA: o cliente não viu a dupla"; fail=1; }
fi
grep -q "SCRIPT ERROR" "$LOG/host.log" "$LOG/cliente.log" && { echo "FALHA: erro de script"; fail=1; }
[ $fail = 0 ] && echo "co-op ok" || echo "logs em $LOG"
exit $fail
