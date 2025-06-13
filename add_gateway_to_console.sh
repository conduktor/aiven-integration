#!/bin/bash


# apply a resource file via conduktor CLI
login_cli () {
  local FILENAME=$1
  docker run --rm \
    -e CDK_USER=$CDK_USER \
    -e CDK_PASSWORD=$CDK_PASSWORD \
    -e CDK_BASE_URL=http://conduktor-console:8080 \
    --network integrations \
    --volume $PWD/resources:/resources $CONDUKTOR_CLI_IMAGE "$@"
}

# apply a resource file via conduktor CLI
cli () {
  local FILENAME=$1
  docker run --rm \
    -e CDK_API_KEY=$CDK_API_KEY \
    -e CDK_BASE_URL=http://conduktor-console:8080 \
    -e CDK_GATEWAY_BASE_URL=http://conduktor-gateway-multi-tenancy:8888 \
    -e CDK_GATEWAY_USER=admin \
    -e CDK_GATEWAY_PASSWORD=conduktor \
    -e GATEWAYTOKEN=$GATEWAYTOKEN \
    --network integrations \
    --volume $PWD/resources:/resources $CONDUKTOR_CLI_IMAGE "$@"
}

export CONDUKTOR_CLI_IMAGE=conduktor/conduktor-ctl:v0.4.0
export CDK_USER=admin@demo.dev
export CDK_PASSWORD=adminP4ss!
export CDK_API_KEY="1"

login_cli login


export CDK_API_KEY=$(login_cli login)


cli apply -f resources/exchange/pz_admin_sa.yaml

cli run generateServiceAccountToken --life-time-seconds 999999 --username admin --v-cluster passthrough | jq -r ".token"
export GATEWAYTOKEN=$(cli run generateServiceAccountToken --life-time-seconds 999999 --username admin --v-cluster passthrough | jq -r ".token")

echo $GATEWAYTOKEN > .gateway-token

# generate credentials for clients
set +v
echo  """
security.protocol=SASL_PLAINTEXT
sasl.mechanism=PLAIN
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="admin" password="$GATEWAYTOKEN";
""" > security/kafka-admin.properties
set -v

echo $GATEWAYTOKEN

cli apply -f resources/exchange/partner_gateway.yaml