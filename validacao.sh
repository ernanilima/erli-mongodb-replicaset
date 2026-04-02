#!/usr/bin/env bash
set -euo pipefail

PRIMARY_CONTAINER="mongodb-principal"
SECONDARIES=("mongodb-filho-1" "mongodb-filho-2")

DB_NAME="replicacao_teste"
COLLECTION_NAME="eventos"
TEST_ID="$(date +%s)"
TEST_JSON="{ _id: ${TEST_ID}, descricao: 'teste-replicacao', criadoEm: new Date() }"

log() {
  echo
  echo "=================================================="
  echo "$1"
  echo "=================================================="
}

run_mongo() {
  local container="$1"
  local js="$2"
  docker exec -i "$container" mongosh --quiet --eval "$js"
}

log "1. Inserindo registro no mongo principal"
run_mongo "$PRIMARY_CONTAINER" "
  use('${DB_NAME}');
  db.getCollection('${COLLECTION_NAME}').insertOne(${TEST_JSON});
"

echo "Registro inserido com _id=${TEST_ID} no ${PRIMARY_CONTAINER}"

log "2. Verificando se o valor replicou para os filhos"
for secondary in "${SECONDARIES[@]}"; do
  echo "Verificando ${secondary}..."
  run_mongo "$secondary" "
    rs.secondaryOk();
    use('${DB_NAME}');
    const doc = db.getCollection('${COLLECTION_NAME}').findOne({ _id: ${TEST_ID} });
    if (!doc) {
      print('ERRO - documento NAO encontrado em ${secondary}');
      quit(1);
    }
    print('OK - documento encontrado em ${secondary}: ' + JSON.stringify(doc));
  "
done

log "3. Derrubando o mongo principal"
docker stop "$PRIMARY_CONTAINER"

log "4. Aguardando cluster estabilizar sem primary"
sleep 20

log "5. Verificando novamente se os filhos ainda conseguem ler o valor"
for secondary in "${SECONDARIES[@]}"; do
  echo "Verificando leitura em ${secondary} com principal parado..."
  run_mongo "$secondary" "
    rs.secondaryOk();
    use('${DB_NAME}');
    const doc = db.getCollection('${COLLECTION_NAME}').findOne({ _id: ${TEST_ID} });
    if (!doc) {
      print('ERRO - documento NAO encontrado em ${secondary}');
      quit(1);
    }
    print('OK - leitura continua funcionando em ${secondary}: ' + JSON.stringify(doc));
  "
done

log "6. Verificando status do replica set em cada filho"
for secondary in "${SECONDARIES[@]}"; do
  echo "Status em ${secondary}..."
  run_mongo "$secondary" '
    const status = rs.status();
    print("set: " + status.set);
    print("myState: " + status.myState);
    status.members.forEach(m => {
      print(" - " + m.name + " | stateStr=" + m.stateStr + " | health=" + m.health);
    });
  '
done

log "7. Garantindo que nenhum filho virou PRIMARY"
for secondary in "${SECONDARIES[@]}"; do
  echo "Checando em ${secondary}..."
  run_mongo "$secondary" '
    const hello = db.hello();
    print("isWritablePrimary: " + hello.isWritablePrimary);
    print("secondary: " + hello.secondary);
    print("primary: " + hello.primary);

    if (hello.isWritablePrimary === true) {
      print("ERRO - este noh virou primary");
      quit(1);
    }

    const status = rs.status();
    const primaryMembers = status.members.filter(m => m.stateStr === "PRIMARY");
    print("Quantidade de primary vista por este noh: " + primaryMembers.length);

    if (primaryMembers.length > 0) {
      print("ERRO - existe primary eleito: " + primaryMembers.map(m => m.name).join(", "));
      quit(1);
    }

    print("OK - nenhum primary eleito");
  '
done

log "8. Tentando inserir em cada filho - deve falhar"
for secondary in "${SECONDARIES[@]}"; do
  echo "Tentando insert em ${secondary}..."

  set +e
  output=$(docker exec -i "$secondary" mongosh --quiet --eval "
    use('${DB_NAME}');
    db.getCollection('${COLLECTION_NAME}').insertOne({ _id: ${TEST_ID}999, origem: '${secondary}' });
  " 2>&1)
  exit_code=$?
  set -e

  echo "$output"

  if [ $exit_code -eq 0 ]; then
    echo "ERRO - insert funcionou em ${secondary}, mas deveria falhar"
    exit 1
  fi

  echo "OK - insert falhou em ${secondary} como esperado"
done

log "TESTE FINALIZADO COM SUCESSO"
echo "Resumo:"
echo "- inseriu no principal"
echo "- replicou para os filhos"
echo "- principal derrubado"
echo "- filhos continuaram lendo"
echo "- nenhum filho assumiu como primary"
echo "- inserts nos filhos falharam como esperado"