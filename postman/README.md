# Colecao Postman - testes de API

`fcg.postman_collection.json` testa todos os endpoints dos 4 microsservicos e os fluxos entre eles (80 requisicoes, 157 asserções).

| Pasta | O que cobre |
|---|---|
| 00 Health | `/health/live` e `/health/ready` dos 4 servicos |
| 01 UsersAPI | cadastro (201, 400, 409), login (claims do JWT, 401), perfil, administracao de usuarios (403 para User, 404), troca de papel e desativacao |
| 02 CatalogAPI - Jogos e GraphQL | catalogo publico com filtros, CRUD de jogos (401, 403, 404, 409, 400) e query GraphQL |
| 03 CatalogAPI - Promocoes | promocao de 50% refletida no preco efetivo e validacoes |
| 04 Compra aprovada | pedido 202, 409 de pedido repetido, espera do `Completed`, acesso por dono/outro usuario/admin, biblioteca e pagamento `Approved` na PaymentsAPI |
| 05 Compra rejeitada | jogo de R$ 399,90, pedido `Rejected` com motivo, pagamento `Rejected` e jogo fora da biblioteca |
| 06 Limpeza | desativacao de promocao e jogos |

A NotificationsAPI so expoe health; os e-mails que ela registra sao conferidos pelo `../e2e/e2e.sh`, que le os logs.

## Como rodar

Com a aplicacao no ar (`docker compose up -d` ou port-forward do Kubernetes nas portas 5101 a 5104):

**Postman:** importe a colecao e o ambiente `fcg-local.postman_environment.json`, selecione o ambiente e rode a colecao inteira pelo **Runner** (as pastas dependem das anteriores: tokens e ids ficam em variaveis da colecao).

**Terminal (newman):**

```bash
npx newman run postman/fcg.postman_collection.json -e postman/fcg-local.postman_environment.json
```

Cada execucao cria usuarios e jogos com sufixo unico, entao pode ser repetida sem limpar o banco.

## Execucao automatica

O workflow [`api-tests.yml`](../.github/workflows/api-tests.yml) sobe a aplicacao no GitHub Actions com as imagens `latest` do GHCR e roda esta colecao e o `e2e/e2e.sh`:

- todo dia as 06:00 (Brasilia), para pegar regressoes das imagens publicadas pelos servicos;
- a cada push ou PR que mude `postman/`, `e2e/` ou o `docker-compose.yml`;
- sob demanda em **Actions > Testes de API > Run workflow**.

O resumo (requisicoes, assercoes e falhas) aparece na pagina da execucao; o artefato `resultados-testes-api` traz o relatorio JUnit, o JSON do newman e, em caso de falha, os logs dos containers.
