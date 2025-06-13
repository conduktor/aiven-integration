#!/bin/bash

export GATEWAYTOKEN=$(cat .gateway-token)

envsubst < shadowtraffic-retail.json > shadowtraffic-config.json

docker compose --profile shadowtraffic up -d