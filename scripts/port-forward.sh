#!/usr/bin/env bash
# Expoe as 4 APIs e o RabbitMQ Management do cluster nas mesmas portas do docker compose,
# para usar a colecao Postman, o e2e/e2e.sh e o RabbitMQ sem mudar nada. Ctrl+C encerra todos.
#
#   ./scripts/port-forward.sh                 # namespace atual do kubectl
#   NAMESPACE=fcg ./scripts/port-forward.sh   # outro namespace
set -euo pipefail

NS_ARGS=()
[[ -n "${NAMESPACE:-}" ]] && NS_ARGS=(-n "$NAMESPACE")

FORWARDS=(
  "users-api 5101:80"
  "catalog-api 5102:80"
  "payments-api 5103:80"
  "notifications-api 5104:80"
  "rabbitmq 15672:15672"
)

trap 'kill $(jobs -p) 2>/dev/null' EXIT

for forward in "${FORWARDS[@]}"; do
  read -r service ports <<<"$forward"
  kubectl ${NS_ARGS[@]+"${NS_ARGS[@]}"} port-forward "svc/$service" "$ports" >/dev/null &
  echo "svc/$service -> localhost:${ports%%:*}"
done

echo "Port-forwards ativos. Ctrl+C para encerrar."
wait
