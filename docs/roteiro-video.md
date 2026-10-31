# Roteiro do video (ate 20 minutos)

Cobre os 5 pontos exigidos no enunciado da Fase 2. Tempo total previsto: cerca de 19 minutos e meio.

| Exigencia do enunciado | Bloco |
|---|---|
| Estrutura dos diferentes repositorios | 2 |
| Servicos com docker-compose a partir do repositorio de orquestracao | 3 |
| Fluxo de cadastro e fluxo de compra completos | 4 e 5 |
| Manifestos no repositorio de orquestracao (Deployment, Service, ConfigMap, Secret) | 6 |
| Deploy no Kubernetes local (`kubectl apply -f .`) e `kubectl get pods` | 7 |
| (extra) Fluxos rodando dentro do cluster, via port-forward | 7 |

## Preparacao (antes de gravar)

- Nao Perturbe ligado, Teams/Outlook/Slack/WhatsApp fechados, OBS em 1920x1080, terminal com fonte grande.
- Ambiente limpo (as imagens ficam em cache, nada demora para baixar no video):

```bash
cd ~/fcg-orchestration
git pull
pkill -f port-forward
docker compose down -v
docker compose pull
kubectl config use-context docker-desktop
kubectl delete -f k8s/ --ignore-not-found
```

- Postman: importe `postman/fcg.postman_collection.json` e selecione o ambiente **FCG local**.
- Abas abertas: repositorios no GitHub, README do orquestrador, `fcg-users-api` (codigo e Actions), SonarCloud, RabbitMQ (http://localhost:15672, fcg/fcg, depois do compose up), tres terminais (comandos, logs e port-forward) e o VS Code na pasta `k8s/`.

## 1. Abertura e arquitetura (0:00 - 2:00)

- Grupo e integrantes. Monolito da Fase 1 vira 4 microsservicos orientados a eventos (Users, Catalog, Payments, Notifications), um database por servico.
- Diagrama do README: `UserCreatedEvent` (Users -> Notifications), `OrderPlacedEvent` (Catalog -> Payments), `PaymentProcessedEvent` (Payments -> Catalog e Notifications), via RabbitMQ com MassTransit e outbox. JWT emitido pela UsersAPI e validado pelos demais.

## 2. Estrutura dos repositorios (2:00 - 5:00)

- Lista dos repositorios: 4 servicos, `fcg-contracts` e `fcg-orchestration`.
- `fcg-users-api`: `src/` (Domain, Application, Infrastructure, WebApi), `test/`, `Dockerfile` multi-stage (`sdk AS build` -> `aspnet AS runtime`), `k8s/` e a tabela de variaveis de ambiente do README.
- `fcg-contracts`: pacote NuGet com eventos, filas e claims. `fcg-orchestration`: compose, `k8s/`, `postman/` e `e2e/`.
- Actions (build, testes, Sonar, publicacao no GHCR) e SonarCloud.

## 3. docker compose (5:00 - 7:00)

```bash
cd ~/fcg-orchestration
docker compose up -d
docker compose ps
```

- Em outro terminal: `docker compose logs -f notifications-api` (fica visivel nos blocos 4 e 5).
- RabbitMQ Management: exchanges `fcg.*.v1` e filas `notifications.user-created`, `notifications.payment-processed`, `payments.order-placed`, `catalog.payment-processed`.

## 4. Fluxo de cadastro (7:00 - 8:30)

No Postman (Send em cada requisicao, mostrando resposta e Test Results):

1. `01 UsersAPI > Cadastro - sucesso` (201) -> log "Bem-vindo(a) a FIAP Cloud Games!" na NotificationsAPI.
2. `01 UsersAPI > Login - usuario` (200 com o JWT).

## 5. Fluxo de compra (8:30 - 12:30)

Aprovada:

3. `01 UsersAPI > Login - administrador`
4. `02 CatalogAPI > Listar catalogo (publico)`
5. `02 CatalogAPI > Cadastrar jogo - administrador` (R$ 120,00)
6. `03 CatalogAPI - Promocoes > Criar promocao de 50% - administrador`
7. `04 Compra aprovada > Pedido - jogo com promocao (202)` -> `Pending`, R$ 60,00
8. `04 Compra aprovada > Aguardar pedido Completed` (Send de novo se ainda estiver `Pending`)
9. `04 Compra aprovada > Biblioteca com o jogo comprado`
10. `04 Compra aprovada > Pagamento Approved` -> log "Compra confirmada" na NotificationsAPI

Rejeitada (limite de R$ 300 em `Payments__ApprovalLimit`):

11. `05 Compra rejeitada > Cadastrar jogo de R$ 399,90`
12. `05 Compra rejeitada > Pedido do jogo caro (202)`
13. `05 Compra rejeitada > Aguardar pedido Rejected` (com motivo)
14. `05 Compra rejeitada > Pagamento Rejected`
15. `05 Compra rejeitada > Jogo rejeitado fora da biblioteca`

## 6. Manifestos (12:30 - 14:00)

Na pasta `k8s/` do orquestrador: `users-api-deployment.yaml` (Deployment com 2 replicas, `envFrom` de ConfigMap e Secret, probes), `users-api-service.yaml` (ClusterIP), `payments-api-configmap.yaml` (limite de aprovacao e nome da fila), `users-api-secret.yaml` (connection string, RabbitMQ, chave JWT, senha do admin) e os manifestos de PostgreSQL e RabbitMQ.

## 7. Kubernetes local e fluxos no cluster (14:00 - 18:45)

```bash
docker compose down
cd ~/fcg-orchestration/k8s
kubectl apply -f .
kubectl get pods -w        # Ctrl+C quando todos estiverem 1/1 Running
kubectl get pods
kubectl get deploy,svc,configmap,secret
```

As APIs podem reiniciar 1 ou 2 vezes enquanto PostgreSQL e RabbitMQ sobem; o Kubernetes reinicia ate a dependencia responder.

Os Services sao ClusterIP, entao para acessar de fora abra o port-forward em outro terminal (fica aberto ate o fim):

```bash
cd ~/fcg-orchestration
./scripts/port-forward.sh
```

Com ele aberto, as APIs respondem nas mesmas portas do compose:

- Logs do cluster: `kubectl logs -l app=notifications-api -f --max-log-requests 2`.
- Postman: colecao > **Run** -> 157 testes verdes contra os Pods; nos logs aparecem os e-mails de boas-vindas e de compra confirmada.

## 8. Encerramento (18:45 - 19:30)

Recapitular: 4 servicos independentes com banco proprio, comunicacao assincrona por eventos, Docker multi-stage, pipeline com testes e SonarCloud, docker compose e Kubernetes com ConfigMap e Secret.

## Depois de gravar

- Conferir duracao (ate 20:00) e audio; subir no YouTube como **Nao listado**.
- Colocar o link em [`relatorio-entrega.md`](relatorio-entrega.md) e postar a entrega na plataforma da FIAP.
- Ctrl+C no port-forward e limpar o cluster: `kubectl delete -f ~/fcg-orchestration/k8s/`.
