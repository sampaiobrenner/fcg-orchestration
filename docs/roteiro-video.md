# Roteiro do video (ate 20 minutos)

Cobre os 5 pontos exigidos no enunciado da Fase 2. Tempo total previsto: cerca de 17 minutos.

## Preparacao (antes de gravar)
- Repositorios clonados lado a lado (ver README principal) e Docker Desktop com Kubernetes ligado (ou kind).
- `docker compose down -v` e `kubectl delete -f k8s/` para comecar do zero.
- Abas abertas: GitHub (os 6 repositorios), RabbitMQ Management (http://localhost:15672), terminal e `e2e/fcg.http`.

## 1. Arquitetura (2 min)
- Problema: monolito da Fase 1 vira 4 microsservicos orientados a eventos (Usuarios, Catalogo, Pagamentos, Notificacoes).
- Mostrar o diagrama do README principal: eventos `UserCreatedEvent`, `OrderPlacedEvent` e `PaymentProcessedEvent` pelo RabbitMQ.
- Um database por servico no PostgreSQL; JWT emitido pela UsersAPI e validado pelos demais.

## 2. Estrutura dos repositorios (3 min)
- Um repositorio por servico, cada um com sua `.sln`, `Dockerfile` multi-stage e pasta `k8s/` (Deployment, Service, ConfigMap, Secret).
- `fcg-contracts`: pacote NuGet com os eventos (contrato unico entre os servicos).
- `fcg-orchestration`: docker-compose, manifests de infraestrutura e o E2E.
- Mostrar rapidamente o pipeline (build, testes, Sonar, publicacao no GHCR).

## 3. Execucao com docker-compose (3 min)
```bash
cd fcg-orchestration
docker compose up -d --build
docker compose ps
```
- Mostrar os 6 containers saudaveis e o RabbitMQ Management com as exchanges `fcg.*.v1` e as filas dos consumidores.

## 4. Fluxos de cadastro e de compra (5 min)
Executar `e2e/fcg.http` passo a passo (ou `./e2e/e2e.sh`), mostrando os logs em outro terminal:
```bash
docker compose logs -f notifications-api
```
1. Cadastro -> log "Bem-vindo(a) a FIAP Cloud Games!" na NotificationsAPI.
2. Login, catalogo, pedido de compra (202 Pending) -> pedido `Completed`, jogo na biblioteca, pagamento `Approved`, log "Compra confirmada".
3. Administrador cadastra jogo de R$ 399,90 -> pedido `Rejected` com motivo e jogo fora da biblioteca.

## 5. Kubernetes local (4 min)
- Mostrar `k8s/` do orquestrador: Deployments (nenhum Pod isolado), Services, ConfigMaps (inclusive nomes de filas) e Secrets.
```bash
cd fcg-orchestration/k8s
kubectl apply -f .
kubectl get pods -w        # aguardar todos Running 1/1
kubectl get svc
```
- Opcional: `LOGS_CMD="kubectl logs -l app=notifications-api --tail=-1" ./e2e/e2e.sh` com port-forward das APIs.

## Encerramento (1 min)
- Recapitular: 4 servicos independentes, comunicacao assincrona, Docker multi-stage, Kubernetes com ConfigMap/Secret, testes e pipeline.
