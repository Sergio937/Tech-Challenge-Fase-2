# ToggleMaster — README Completo

Este projeto contém múltiplos microserviços escritos em **Go** e **Python**, utilizando **Redis** como storage principal e **AWS SQS/DynamoDB** para eventos e análises.

O guia abaixo ensina como rodar tudo localmente via **Docker Compose**.

---

## 📦 Tecnologias Necessárias

Antes de rodar, você precisa ter instalado:

* **Docker**
* **Docker Compose**
* *(Opcional)* **AWS CLI** caso queira testar SQS/DynamoDB com LocalStack
* **Kubernetes**

---

## 🛠 Docker Hub
https://hub.docker.com/repository/docker/marcelosilva404/auth-service/general
https://hub.docker.com/repository/docker/marcelosilva404/evaluation-service/general
https://hub.docker.com/repository/docker/marcelosilva404/flag-service/general
https://hub.docker.com/repository/docker/marcelosilva404/analytics-service/general
https://hub.docker.com/repository/docker/marcelosilva404/targeting-service/general

## 🛠 Pipelines
https://gitlab.com/marceloeduardo244/desafio-tech-fase-2-togglemaster/-/pipelines

## 🛠 Serviços incluídos

* **LocalStack:** Simula AWS (SQS + DynamoDB) localmente.
* **Redis:** Armazenamento em cache.
* **Auth Service:** Backend de autenticação com PostgreSQL.
* **Flag Service:** Gerenciamento de feature flags.
* **Targeting Service:** Regras de segmentação.
* **Evaluation Service:** Avalia flags de usuários e envia eventos para SQS.
* **Analytics Service:** Worker que consome eventos da fila SQS e grava em DynamoDB.

---

## 🚀 Subindo o projeto com Docker Compose

Na raiz do repositório, execute:

```bash
docker-compose up --build -d
```

Isso vai subir todos os serviços com seus bancos e filas simuladas pelo LocalStack.

---

## 🚀 Subindo o projeto com Kubernetes

Na raiz do repositório, execute:

```bash
criar host no arquivo /etc/hosts com o valor: 127.0.0.1    meuaplicativo.local

kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml

kubectl apply -f ./kubernetes/local/namespace.yaml
kubectl apply -f ./kubernetes/local/localcloud/localstack/
kubectl apply -f ./kubernetes/local/localcloud/redis/
kubectl apply -f ./kubernetes/local/auth/database/
kubectl apply -f ./kubernetes/local/flag/database/
kubectl apply -f ./kubernetes/local/targeting/database/
kubectl apply -f ./kubernetes/local/auth/
kubectl apply -f ./kubernetes/local/flag/
kubectl apply -f ./kubernetes/local/targeting/
kubectl apply -f ./kubernetes/local/evaluation/
kubectl apply -f ./kubernetes/local/analytics/

kubectl apply -f ./kubernetes/local/ingress.yaml

sudo -E kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 80:80
```

Isso vai subir todos os serviços com seus bancos e filas simuladas pelo LocalStack.

---

## 🚀 Removendo o projeto com Kubernetes

Na raiz do repositório, execute:

```bash
kubectl delete namespace --all
kubectl delete deployment --all
kubectl delete configmap --all
kubectl delete secret --all
kubectl delete service --all
kubectl delete pvc --all
kubectl delete hpa --all
kubectl delete pod --all
kubectl delete ingress --all
```

Isso vai subir todos os serviços com seus bancos e filas simuladas pelo LocalStack.

---

## 🌐 Healthchecks

Cada serviço expõe um endpoint de saúde:

```bash
curl http://localhost:<PORT>/health
```

* Auth Service: `8001`
* Flag Service: `8002`
* Targeting Service: `8003`
* Evaluation Service: `8004`
* Analytics Service: `8005`

Saída esperada:

```json
{"status":"ok"}
```

---

## 📌 Configuração de SQS/DynamoDB no LocalStack

### LocalStack URLs

* **Evaluation Queue:** `http://localstack:4566/000000000000/evaluation-events`
* **Analytics Queue:** `http://localstack:4566/000000000000/analytics-queue`
* **DynamoDB Table:** `ToggleMasterAnalytics`

### Variáveis de ambiente principais (exemplo .env ou docker-compose):

```env
AWS_ACCESS_KEY_ID=test
AWS_SECRET_ACCESS_KEY=test
AWS_REGION=us-east-1
AWS_SQS_URL=http://localstack:4566/000000000000/evaluation-events
AWS_DYNAMODB_TABLE=ToggleMasterAnalytics
AWS_DYNAMODB_ENDPOINT=http://localstack:4566
```

> ⚠️ Certifique-se de que as credenciais (`AWS_ACCESS_KEY_ID` e `AWS_SECRET_ACCESS_KEY`) estejam iguais às configuradas no LocalStack.

---

## 🔧 Testando o Evaluation Service

1. Faça uma requisição para avaliar uma flag:

```bash
curl "http://localhost:8004/evaluate?user_id=test-user-1&flag_name=enable-new-dashboard"
curl "http://localhost:8004/evaluate?user_id=test-user-2&flag_name=enable-new-dashboard"
```

2. Observe os logs do serviço — você verá mensagens sendo enviadas para a fila SQS:

```
Cache MISS para flag 'enable-new-dashboard'
Evento de avaliação enviado para SQS (Flag: enable-new-dashboard)
Cache HIT para flag 'enable-new-dashboard'
```

---

## 🔧 Testando o Analytics Service

O Analytics Service consome eventos da fila SQS e grava no DynamoDB:

1. Verifique se o worker está rodando:

```bash
curl http://localhost:8005/health
```

2. Após gerar eventos pelo Evaluation Service, veja os logs:

```
INFO: Recebidas 2 mensagens.
INFO: Processando mensagem ID: ...
INFO: Evento ... salvo no DynamoDB.
```

3. Verifique a tabela `ToggleMasterAnalytics` no LocalStack/DynamoDB.

---

## ⚡ Dicas de execução local

* Use **LocalStack** como endpoint AWS para testes, evitando acesso real à AWS.
* A URL das filas SQS deve ser **exata** como exibida nos logs do container LocalStack.
* Se houver erro `InvalidClientTokenId`, verifique as credenciais AWS no serviço e no docker-compose.
* Healthchecks permitem que o Docker Compose monitore se os containers estão prontos antes de iniciar dependentes.

---

## 🧪 Observações

* O Analytics Service não expõe API pública, apenas `/health`.
* O Evaluation Service envia eventos para a fila SQS, que são consumidos pelo Analytics Service.
* Todos os bancos PostgreSQL têm scripts `init.sql` para criar schemas e tabelas iniciais.
* Redis é usado apenas pelo Evaluation Service para cache de flags.

---

Pronto! Agora você consegue subir todo o ecossistema ToggleMaster localmente, gerar eventos e validar fluxos de SQS e DynamoDB via LocalStack.