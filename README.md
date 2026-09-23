# fcg-orchestration

Orquestracao da plataforma **FIAP Cloud Games (FCG) - Fase 2**: docker-compose da aplicacao completa e guia de deploy no Kubernetes.

## Repositorios

| Repositorio | Responsabilidade |
|---|---|
| [fcg-contracts](https://github.com/sampaiobrenner/fcg-contracts) | Contratos de integracao (eventos, filas, claims JWT) |
| [fcg-users-api](https://github.com/sampaiobrenner/fcg-users-api) | Cadastro, autenticacao (JWT) e autorizacao |
| [fcg-catalog-api](https://github.com/sampaiobrenner/fcg-catalog-api) | Jogos, promocoes, biblioteca e inicio da compra |
| [fcg-payments-api](https://github.com/sampaiobrenner/fcg-payments-api) | Processamento (simulado) de pagamentos |
| [fcg-notifications-api](https://github.com/sampaiobrenner/fcg-notifications-api) | E-mails (simulados) de boas-vindas e confirmacao |
| **fcg-orchestration** | docker-compose, manifests de infraestrutura e guias |

## Arquitetura

```
             UserCreatedEvent
 users-api ─────────────────────────────────────────────┐
                                                        v
             OrderPlacedEvent            PaymentProcessedEvent
 catalog-api ───────────────> payments-api ─────────────┬──> notifications-api
      ^                                                 │
      └─────────────────────────────────────────────────┘
```

Comunicacao assincrona via RabbitMQ (MassTransit 8). Cada servico tem seu proprio database no PostgreSQL.

## Estrutura local esperada

Clone todos os repositorios lado a lado:

```bash
mkdir fcg && cd fcg
for repo in fcg-orchestration fcg-contracts fcg-users-api fcg-catalog-api fcg-payments-api fcg-notifications-api; do
  git clone https://github.com/sampaiobrenner/$repo.git
done
```

## Executando com Docker

Aplicacao completa (PostgreSQL, RabbitMQ e as 4 APIs, com build a partir dos repositorios irmaos):

```bash
docker compose up -d --build
```

Somente infraestrutura (para desenvolver um servico com `dotnet run`):

```bash
docker compose up -d postgres rabbitmq
```

| Servico | URL |
|---|---|
| users-api | http://localhost:5101/scalar/v1 |
| catalog-api | http://localhost:5102/scalar/v1 |
| payments-api | http://localhost:5103/scalar/v1 |
| notifications-api | http://localhost:5104/scalar/v1 |
| RabbitMQ Management | http://localhost:15672 (fcg / fcg) |
| PostgreSQL | localhost:5432 (fcg / fcg) |

Health de cada API: `/health/live` e `/health/ready`. Variaveis opcionais: copie `.env.example` para `.env`. Para parar: `docker compose down` (use `-v` para apagar os dados).

## Kubernetes

A pasta [`k8s/`](k8s) reune **todos** os manifests da aplicacao, para o deploy com um unico `kubectl apply -f .`:

| Arquivos | Conteudo |
|---|---|
| `postgres-*.yaml` | Secret (usuario/senha), ConfigMap (`init.sql` com os 4 databases), PVC, Deployment e Service `postgres:5432` |
| `rabbitmq-*.yaml` | Secret (usuario/senha), PVC, Deployment e Service `rabbitmq:5672` / `15672` |
| `<servico>-{deployment,service,configmap,secret}.yaml` | Copia dos manifests de cada microsservico |

A fonte dos manifests de cada microsservico e a pasta `k8s/` do proprio repositorio. Depois de alterar um deles, atualize a copia:

```bash
./scripts/sync-k8s.sh          # copia ../fcg-*-api/k8s/*.yaml para k8s/
./scripts/sync-k8s.sh --check  # so verifica se as copias estao atualizadas
```

Somente Deployments (nenhum Pod isolado), ConfigMaps para configuracao nao sensivel e Secrets para dados sensiveis. Os servicos se comunicam pelos nomes de Service (`postgres`, `rabbitmq`, `users-api`, ...).

### Deploy em cluster local

Funciona em kind, minikube, k3d ou Kubernetes do Docker Desktop.

1. Crie o cluster (exemplo com kind): `kind create cluster --name fcg`
2. Disponibilize as imagens. Elas sao publicadas no GHCR a cada push na `main` dos servicos, entao o cluster faz o pull sozinho. Para testar codigo local:
   ```bash
   docker compose build
   kind load docker-image ghcr.io/sampaiobrenner/fcg-users-api:latest ghcr.io/sampaiobrenner/fcg-catalog-api:latest \
     ghcr.io/sampaiobrenner/fcg-payments-api:latest ghcr.io/sampaiobrenner/fcg-notifications-api:latest
   ```
   (minikube: `minikube image load <imagem>`; Docker Desktop usa as imagens locais direto.)
3. Aplique tudo e acompanhe:
   ```bash
   cd k8s
   kubectl apply -f .
   kubectl get pods -w
   ```
   As APIs podem reiniciar uma vez enquanto PostgreSQL e RabbitMQ ficam prontos; em cerca de 2 minutos todos os Pods ficam `Running` e `1/1`.
4. Acesse pelos Services:
   ```bash
   kubectl port-forward svc/users-api 5101:80
   kubectl port-forward svc/catalog-api 5102:80
   kubectl port-forward svc/payments-api 5103:80
   kubectl port-forward svc/notifications-api 5104:80
   kubectl port-forward svc/rabbitmq 15672:15672
   ```
5. Para remover: `kubectl delete -f .` (e `kind delete cluster --name fcg`).

## Imagens no GHCR

Cada servico publica sua imagem em `ghcr.io/sampaiobrenner/fcg-<servico>` a cada push na `main` (tag `latest` e `sha-<commit>`) e a cada tag `v*` (tag semver). O build usa o workflow reutilizavel [`docker-publish.yml`](.github/workflows/docker-publish.yml) deste repositorio, chamado por `.github/workflows/docker.yml` em cada servico.

```bash
docker pull ghcr.io/sampaiobrenner/fcg-users-api:latest
```

