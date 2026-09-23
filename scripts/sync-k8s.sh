#!/usr/bin/env bash
# Copia os manifests de cada microsservico (pasta k8s/ do repositorio irmao) para k8s/ deste repositorio,
# com o prefixo do servico, para que `cd k8s && kubectl apply -f .` suba a aplicacao completa.
# A fonte de verdade continua sendo o k8s/ de cada servico.
#   ./scripts/sync-k8s.sh          copia
#   ./scripts/sync-k8s.sh --check  falha se alguma copia estiver desatualizada
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
services=(users-api catalog-api payments-api notifications-api)
check=false
[[ "${1:-}" == "--check" ]] && check=true
status=0

for svc in "${services[@]}"; do
  src="$root/../fcg-$svc/k8s"
  if [[ ! -d "$src" ]]; then
    echo "ERRO: $src nao encontrado. Clone fcg-$svc ao lado de fcg-orchestration." >&2
    exit 1
  fi
  for file in "$src"/*.yaml; do
    dest="$root/k8s/$svc-$(basename "$file")"
    if $check; then
      if ! cmp -s "$file" "$dest"; then
        echo "desatualizado: k8s/$(basename "$dest")"
        status=1
      fi
    else
      cp "$file" "$dest"
      echo "copiado: k8s/$(basename "$dest")"
    fi
  done
done

exit $status
