#!/bin/bash

export NOMAD_ADDR="https://n00.stagnet3.vega.xyz:4646" 
export NOMAD_CACERT="./stagnet3/vegacapsule/certs/nomad-ca.pem"
export NOMAD_CLIENT_CERT="./stagnet3/vegacapsule/certs/client.pem"
export NOMAD_CLIENT_KEY="./stagnet3/vegacapsule/certs/client-key.pem"
export NOMAD_TLS_SERVER_NAME="server.global.nomad"
export AWS_PROFILE=vega


# pushd /Users/daniel/www/vega/vega;
# GOOS=linux GOARCH=amd64 go build -o vega ./cmd/vega
# aws s3 cp vega s3://vegacapsule-test/bin/vega-linux-amd64-v0.50.2-build
# popd 

pushd /Users/daniel/www/vega/vegacapsule/
go build -o vegacapsule .
cp vegacapsule /Users/daniel/www/vega/networks-internal/vegacapsule
popd

./vegacapsule network destroy --home-path ./stagnet3/vegacapsule/home
./vegacapsule network generate --force --config-path ./stagnet3/vegacapsule/config.hcl --home-path ./stagnet3/vegacapsule/home \
    && aws s3 rm --recursive s3://vegacapsule-test/stagnet3 \
    && aws s3 cp --recursive ./stagnet3/vegacapsule/home/ s3://vegacapsule-test/stagnet3/ \
    && ./vegacapsule network start --home-path ./stagnet3/vegacapsule/home \
    || echo " === FAILED === " 


# Update nomad template
# ./vegacapsule network start --home-path ./stagnet3/vegacapsule/home