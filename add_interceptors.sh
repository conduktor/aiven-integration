#!/bin/bash

# cli a resource file via conduktor CLI
login_cli () {
  local FILENAME=$1
  docker run --rm \
    -e CDK_USER=$CDK_USER \
    -e CDK_PASSWORD=$CDK_PASSWORD \
    -e CDK_BASE_URL=http://conduktor-console:8080 \
    --network integrations \
    --volume $PWD/resources:/resources $CONDUKTOR_CLI_IMAGE "$@"
}

# cli a resource file via conduktor CLI
cli () {
  local FILENAME=$1
  docker run --rm \
    -e CDK_API_KEY=$CDK_API_KEY \
    -e CDK_BASE_URL=http://conduktor-console:8080 \
    -e CDK_GATEWAY_BASE_URL=http://conduktor-gateway-multi-tenancy:8888 \
    -e CDK_GATEWAY_USER=admin \
    -e CDK_GATEWAY_PASSWORD=conduktor \
    -e GATEWAY_ADMIN_TOKEN=$GATEWAYTOKEN \
    --network integrations \
    --volume $PWD/resources:/resources $CONDUKTOR_CLI_IMAGE "$@"
}

export CONDUKTOR_CLI_IMAGE=conduktor/conduktor-ctl:latest
export CDK_USER=admin@demo.dev
export CDK_PASSWORD=adminP4ss!
export CDK_API_KEY="1"

# generate a random string
export CONSUMER_GROUP=$(openssl rand -base64 32 | head -c 5 )

login_cli login


export CDK_API_KEY=$(login_cli login)

export GATEWAYTOKEN=$(cat .gateway-token)

# lets add some interceptors

cli delete Interceptor decrypt-orders-json --vcluster=passthrough

echo "Let's demonstrate field level encryption"

# cli delete -f resources/orders-topic.yaml
# cli apply -f resources/orders-topic.yaml

echo "Remember our dataset?"
# cat customer-data.json

echo "Let's make sure that PII (i.e. creditCardNumber) data is encrypted"

cli apply -f resources/interceptors/encrypt-orders.yaml

sleep 15

echo "Let's make sure messages are encrypted"

docker compose exec kafka-client \
    kafka-console-consumer \
        --bootstrap-server conduktor-gateway-multi-tenancy:6969 \
        --consumer.config /clientConfig/kafka-admin.properties \
        --topic orders \
        --from-beginning \
        --max-messages 3 | jq

echo "'creditCardNumber' field is encrypted"

echo "Let's add decryption to make it transparent for the clients"

sleep 3

cli apply -f resources/interceptors/decrypt-orders.yaml

echo "Let's make sure messages are now decrypted"

docker compose exec kafka-client \
    kafka-console-consumer \
        --bootstrap-server conduktor-gateway-multi-tenancy:6969 \
        --consumer.config /clientConfig/kafka-admin.properties \
        --topic orders \
        --from-beginning \
        --max-messages 3 | jq

echo "'creditCardNumber' field is decrypted. Again, we did't have to modify the clients!"

# echo "now lets add the partnerzones"
# # add the partner zone
# cli apply -f resources/customers_partnerzone.yaml