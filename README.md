# MongoDB Replica Set (Primary fixo + Secondaries read-only)

## 📌 Objetivo

Simular um ambiente onde:

- Existe **1 MongoDB principal (PRIMARY)**
- Existem **N MongoDB filhos (SECONDARY)**
- **Apenas o principal aceita escrita**
- **Filhos são somente leitura**
- **Se o principal cair:**
    - ❌ ninguém assume como primary
    - ✅ leitura continua funcionando nos filhos

---

## 🚀 Subir a aplicação

### 1. Subir containers

`docker compose up -d`

### 2. Resetar ambiente (quando necessário)

`docker compose down --remove-orphans`  
`docker rm -f mongodb-principal mongodb-filho-1 mongodb-filho-2 mongo-rs-init 2>/dev/null || true`  
`docker compose up -d`

---

## ⚙️ O que é criado

| Serviço           | Porta Host | Papel     |
|-------------------|------------|-----------|
| mongodb-principal | 27010      | PRIMARY   |
| mongodb-filho-1   | 27021      | SECONDARY |
| mongodb-filho-2   | 27022      | SECONDARY |

---

## 🔗 Conexões

### 🟢 Escrita (PRIMARY)

`mongodb://localhost:27010/?directConnection=true`

---

### 🔵 Leitura (SECONDARY)

`mongodb://localhost:27021/?directConnection=true&readPreference=secondaryPreferred`

`mongodb://localhost:27022/?directConnection=true&readPreference=secondaryPreferred`

---

## 🧪 Script de validação

Arquivo:

`./validacao.sh`

### ▶️ Executar

`chmod +x validacao.sh`  
`./validacao.sh`

---

## 🔍 O que o script faz

- Insere um documento no `mongodb-principal`
- Confirma se o dado apareceu nos filhos
- Derruba o `mongodb-principal` simulando falha do servidor
- Confirma que leitura continua funcionando nos filhos
- Garante que:
    - nenhum filho virou primary
    - cluster está sem primary
- Tenta inserir nos filhos esperando falha `not primary / read only`

---

## 🎯 Resumo

Este projeto demonstra:

- Replica set sem failover automático
- Primary fixo
- Secondaries somente leitura
- Continuidade de leitura mesmo com falha do primary

---

Se precisar evoluir para produção (auth, keyfile, cluster real), adaptar configuração.

---

## Documentações importantes

[Read Preference](https://www.mongodb.com/pt-br/docs/manual/core/read-preference)

[Write Concern](https://www.mongodb.com/pt-br/docs/manual/reference/write-concern)

[Replication](https://www.mongodb.com/pt-br/docs/manual/replication)