#!/bin/bash
# Mede o co-op sob internet simulada: host e cliente sem janela, cada um atrasando o
# que manda em metade do "ping" pedido, com variação e perda.
#   tools/teste_rede.sh <ping_ms> <variacao_ms> <perda_%> [--sem-suavizar] [godot]
# Imprime a última linha de estatística do cliente (espera, congelados, saltos...).
PING=${1:-80}; JIT=${2:-15}; LOSS=${3:-1}; MODE=${4:-}; GODOT=${5:-godot}
[ "$MODE" = "-" ] && MODE=""
cd "$(dirname "$0")/.."
PORT=${PORT:-$((7800 + RANDOM % 1000))}
LOG=${COOP_LOG:-$(mktemp -d)}; mkdir -p "$LOG"
HALF=$((PING / 2)); HJ=$((JIT / 2))
FR=${FRAMES:-2700}
"$GODOT" --headless --path . --quit-after $((FR + 200)) -- --net-host --bot --log --hero=fire_knight --port=$PORT \
	--lag=$HALF --jitter=$HJ --loss=$LOSS $HOST_EXTRA > "$LOG/host.log" 2>&1 &
HOST=$!
sleep 2
"$GODOT" --headless --path . --quit-after $FR -- --net-join=127.0.0.1 --bot --log --hero=water_priestess --port=$PORT \
	--lag=$HALF --jitter=$HJ --loss=$LOSS $MODE $EXTRA > "$LOG/cliente.log" 2>&1
wait $HOST
grep "^\[CLIENTE\]" "$LOG/cliente.log" | tail -1 | sed 's/ | .*//'
grep -q "SCRIPT ERROR" "$LOG/host.log" "$LOG/cliente.log" && { echo "FALHA: erro de script (logs em $LOG)"; exit 1; }
exit 0
