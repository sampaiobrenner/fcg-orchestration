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

Somente infraestrutura (para desenvolver um servico com `dotnet run`):

```bash
docker compose up -d
```

Aplicacao completa (infra + 4 APIs, build a partir dos repositorios irmaos):

```bash
docker compose --profile apps up -d --build
```

| Servico | URL |
|---|---|
| users-api | http://localhost:5101/scalar/v1 |
| catalog-api | http://localhost:5102/scalar/v1 |
| payments-api | http://localhost:5103/scalar/v1 |
| notifications-api | http://localhost:5104/scalar/v1 |
| RabbitMQ Management | http://localhost:15672 (fcg / fcg) |
| PostgreSQL | localhost:5432 (fcg / fcg) |

Variaveis opcionais: copie `.env.example` para `.env`.

## Kubernetes

Os manifests de cada servico ficam na pasta `k8s/` do respectivo repositorio. Os manifests de infraestrutura (PostgreSQL, RabbitMQ) e o passo a passo de deploy em cluster local (kind/minikube) serao adicionados na historia OR-02.
