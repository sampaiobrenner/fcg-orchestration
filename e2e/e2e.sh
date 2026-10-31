#!/usr/bin/env bash
# Teste ponta a ponta da FCG Fase 2: cadastro, compra aprovada e compra rejeitada.
#
# Docker (padrao):   ./e2e/e2e.sh
# Kubernetes local:  ./scripts/port-forward.sh (em outro terminal) e
#                    LOGS_CMD="kubectl logs -l app=notifications-api --tail=-1" ./e2e/e2e.sh
set -euo pipefail

USERS_URL="${USERS_URL:-http://localhost:5101}"
CATALOG_URL="${CATALOG_URL:-http://localhost:5102}"
PAYMENTS_URL="${PAYMENTS_URL:-http://localhost:5103}"
LOGS_CMD="${LOGS_CMD:-docker logs fcg-notifications-api}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@cloudgames.com}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-Admin@123}"
TIMEOUT="${TIMEOUT:-60}"

GREEN='\033[0;32m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
step() { printf "\n${BOLD}== %s${NC}\n" "$*"; }
ok()   { printf "${GREEN}  OK${NC} %s\n" "$*"; }
fail() { printf "${RED}  FALHOU${NC} %s\n" "$*" >&2; exit 1; }

# request METODO URL [TOKEN] [JSON] -> imprime o corpo; HTTP_STATUS fica no arquivo $STATUS_FILE
STATUS_FILE="$(mktemp)"; trap 'rm -f "$STATUS_FILE"' EXIT
request() {
  local method=$1 url=$2 token=${3:-} body=${4:-}
  local args=(-s -o /dev/stdout -w '%{http_code}' -X "$method" "$url" -H 'Content-Type: application/json')
  [[ -n "$token" ]] && args+=(-H "Authorization: Bearer $token")
  [[ -n "$body" ]] && args+=(-d "$body")
  local out; out="$(curl "${args[@]}")"
  echo "${out: -3}" > "$STATUS_FILE"
  printf '%s' "${out%???}"
}
status() { cat "$STATUS_FILE"; }
expect_status() { [[ "$(status)" == "$1" ]] || fail "$2 (esperado HTTP $1, recebido $(status))"; }

# wait_until "descricao" comando... -> repete ate o comando ter sucesso ou estourar o TIMEOUT
wait_until() {
  local what=$1; shift
  for ((i = 0; i < TIMEOUT; i++)); do
    if "$@" >/dev/null 2>&1; then return 0; fi
    sleep 1
  done
  fail "tempo esgotado aguardando: $what"
}

login() {
  local body; body="$(request POST "$USERS_URL/api/v1/auth/login" "" "$(jq -nc --arg e "$1" --arg p "$2" '{email:$e,password:$p}')")"
  expect_status 200 "login de $1"
  jq -r '.accessToken' <<<"$body"
}

order_status() { request GET "$CATALOG_URL/api/v1/orders/$1" "$2" | jq -r '.status'; }
order_is() { [[ "$(order_status "$1" "$2")" == "$3" ]]; }
log_contains() { $LOGS_CMD 2>&1 | grep -q -- "$1"; }

step "0. Servicos no ar"
for url in "$USERS_URL" "$CATALOG_URL" "$PAYMENTS_URL"; do
  wait_until "$url/health/ready" curl -sf "$url/health/ready"
  ok "$url/health/ready"
done

SUFFIX="$(date +%s)"
EMAIL="e2e.$SUFFIX@fcg.dev"
PASSWORD="Senha@123"

step "1. Fluxo de cadastro"
body="$(request POST "$USERS_URL/api/v1/auth/register" "" "$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" '{name:"Usuario E2E",email:$e,password:$p}')")"
expect_status 201 "cadastro"
USER_ID="$(jq -r '.id' <<<"$body")"
ok "usuario $EMAIL criado ($USER_ID)"
wait_until "e-mail de boas-vindas no log da NotificationsAPI" log_contains "$EMAIL"
ok "NotificationsAPI registrou o e-mail de boas-vindas para $EMAIL"

USER_TOKEN="$(login "$EMAIL" "$PASSWORD")"
ADMIN_TOKEN="$(login "$ADMIN_EMAIL" "$ADMIN_PASSWORD")"
ok "login do usuario e do administrador"

step "2. Compra aprovada (preco ate R\$ 300)"
games="$(request GET "$CATALOG_URL/api/v1/games?pageSize=50")"
expect_status 200 "listagem de jogos"
GAME_ID="$(jq -r '[.[] | select(.effectivePrice <= 300)][0].id // empty' <<<"$games")"
[[ -n "$GAME_ID" ]] || fail "nenhum jogo com preco ate 300 no catalogo"
body="$(request POST "$CATALOG_URL/api/v1/orders" "$USER_TOKEN" "$(jq -nc --arg g "$GAME_ID" '{gameId:$g}')")"
expect_status 202 "pedido de compra"
ORDER_ID="$(jq -r '.orderId' <<<"$body")"
ok "pedido $ORDER_ID criado como $(jq -r '.status' <<<"$body") (R\$ $(jq -r '.price' <<<"$body"))"
wait_until "pedido $ORDER_ID Completed" order_is "$ORDER_ID" "$USER_TOKEN" Completed
ok "pedido concluido"
request GET "$CATALOG_URL/api/v1/library" "$USER_TOKEN" | jq -e --arg g "$GAME_ID" 'any(.[]; .gameId == $g)' >/dev/null || fail "jogo nao apareceu na biblioteca"
ok "jogo na biblioteca do usuario"
[[ "$(request GET "$PAYMENTS_URL/api/v1/payments/$ORDER_ID" "$USER_TOKEN" | jq -r '.status')" == "Approved" ]] || fail "pagamento nao esta Approved"
ok "pagamento Approved na PaymentsAPI"
wait_until "e-mail de confirmacao no log da NotificationsAPI" log_contains "$ORDER_ID"
ok "NotificationsAPI registrou o e-mail de confirmacao do pedido"

step "3. Compra rejeitada (preco acima de R\$ 300)"
body="$(request POST "$CATALOG_URL/api/v1/games" "$ADMIN_TOKEN" "$(jq -nc --arg t "Jogo Premium E2E $SUFFIX" '{title:$t,description:"Criado pelo teste E2E",genre:"Acao",price:399.90,releaseDate:null}')")"
expect_status 201 "cadastro de jogo pelo administrador"
EXPENSIVE_ID="$(jq -r '.id' <<<"$body")"
ok "jogo de R\$ 399,90 criado ($EXPENSIVE_ID)"
body="$(request POST "$CATALOG_URL/api/v1/orders" "$USER_TOKEN" "$(jq -nc --arg g "$EXPENSIVE_ID" '{gameId:$g}')")"
expect_status 202 "pedido do jogo caro"
REJECTED_ID="$(jq -r '.orderId' <<<"$body")"
wait_until "pedido $REJECTED_ID Rejected" order_is "$REJECTED_ID" "$USER_TOKEN" Rejected
reason="$(request GET "$CATALOG_URL/api/v1/orders/$REJECTED_ID" "$USER_TOKEN" | jq -r '.reason')"
[[ -n "$reason" && "$reason" != "null" ]] || fail "pedido rejeitado sem motivo"
ok "pedido rejeitado: $reason"
request GET "$CATALOG_URL/api/v1/library" "$USER_TOKEN" | jq -e --arg g "$EXPENSIVE_ID" 'all(.[]; .gameId != $g)' >/dev/null || fail "jogo rejeitado apareceu na biblioteca"
ok "jogo rejeitado fora da biblioteca"
sleep 3
if log_contains "$REJECTED_ID"; then
  $LOGS_CMD 2>&1 | grep -- "$REJECTED_ID" | grep -qi "confirmada" && fail "e-mail de confirmacao enviado para pedido rejeitado"
fi
ok "nenhum e-mail de confirmacao para o pedido rejeitado"

printf "\n${GREEN}${BOLD}Todos os cenarios passaram.${NC}\n"
