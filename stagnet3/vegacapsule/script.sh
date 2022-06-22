#!/bin/bash
set -o pipefail

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

# pushd /Users/daniel/www/vega/vegacapsule/
# go build -o vegacapsule .
# cp vegacapsule /Users/daniel/www/vega/networks-internal/vegacapsule
# popd

# DO NOT CALL DESTROY FOR LONG LIVE NETWORK
# ./vegacapsule network stop --home-path ./stagnet3/vegacapsule/home \
#     && ./vegacapsule nodes unsafe-reset-all --remote --home-path ./stagnet3/vegacapsule/home \
#     && ./vegacapsule network destroy --home-path ./stagnet3/vegacapsule/home;

# GENERATE NETWORK
# ./vegacapsule network generate --force --config-path ./stagnet3/vegacapsule/config.hcl --home-path ./stagnet3/vegacapsule/home \
#     && aws s3 rm --recursive s3://vegacapsule-test/stagnet3 \
#     && aws s3 cp --recursive ./stagnet3/vegacapsule/home/ s3://vegacapsule-test/stagnet3/ \
#     && ./vegacapsule network start --home-path ./stagnet3/vegacapsule/home \
#     || echo " === FAILED === " 


# SYNC NETWORK HOME
# aws s3 sync s3://vegacapsule-test/stagnet3/ ./stagnet3/vegacapsule/home/

# JUST RESET NETWORK W/O Update
FULL_ALLOC_ID=$(nomad job allocs --json stagnet3-nodeset-full-0-full-cmd-runner | jq -r '.[0].ID')

./vegacapsule network stop --home-path ./stagnet3/vegacapsule/home \
    && ./vegacapsule nodes unsafe-reset-all --remote --home-path ./stagnet3/vegacapsule/home;
nomad exec "$FULL_ALLOC_ID" bash -c "rm -r /local/vega/.data-node/state/" || echo 'OK'
./vegacapsule network start --home-path ./stagnet3/vegacapsule/home

# UPDATE NETWORK CONFIGS
# ./vegacapsule network stop --home-path ./stagnet3/vegacapsule/home 
# ./vegacapsule nodes unsafe-reset-all --remote --home-path ./stagnet3/vegacapsule/home 

# ./vegacapsule template genesis \
#     --home-path ./stagnet3/vegacapsule/home \
#     --path ./stagnet3/vegacapsule/config/genesis.tmpl.json \
#     --update-network;

# ./vegacapsule template genesis \
#     --home-path ./stagnet3/vegacapsule/home \
#     --path ./stagnet3/vegacapsule/config/genesis.tmpl.json \
#     --update-network; 

# ./vegacapsule template node-sets \
#     --home-path ./stagnet3/vegacapsule/home \
#     --path ./stagnet3/vegacapsule/config/vega.validators.tmpl.toml \
#     --nodeset-group-name validators \
#     --type vega \
#     --update-network;

# ./vegacapsule template node-sets \
#     --home-path ./stagnet3/vegacapsule/home \
#     --path ./stagnet3/vegacapsule/config/tendermint.validators.tmpl.toml \
#     --nodeset-group-name validators \
#     --type tendermint \
#     --update-network;

# ./vegacapsule template node-sets \
#     --home-path ./stagnet3/vegacapsule/home \
#     --path ./stagnet3/vegacapsule/config/vega.full.tmpl.toml \
#     --nodeset-group-name full \
#     --type vega \
#     --update-network;

# ./vegacapsule template node-sets \
#     --home-path ./stagnet3/vegacapsule/home \
#     --path ./stagnet3/vegacapsule/config/tendermint.full.tmpl.toml \
#     --nodeset-group-name full \
#     --type tendermint \
#     --update-network;

# ./vegacapsule template node-sets \
#     --home-path ./stagnet3/vegacapsule/home \
#     --path ./stagnet3/vegacapsule/config/data_node.full.tmpl.toml \
#     --nodeset-group-name full \
#     --type data-node \
#     --update-network;

# Sync local files with remote state
# aws s3 rm --recursive s3://vegacapsule-test/stagnet3 \
#     && aws s3 cp --recursive ./stagnet3/vegacapsule/home/ s3://vegacapsule-test/stagnet3/ \
#     && ./vegacapsule network start --home-path ./stagnet3/vegacapsule/home




# Generate templates to be commited
# mkdir -p ./stagnet3/live-config

# ./vegacapsule template genesis \
#     --home-path ./stagnet3/vegacapsule/home \
#     --path ./stagnet3/vegacapsule/config/genesis.tmpl.json \
#     --out-dir ./stagnet3/live-config;

# ./vegacapsule template genesis \
#     --home-path ./stagnet3/vegacapsule/home \
#     --path ./stagnet3/vegacapsule/config/genesis.tmpl.json \
#     --out-dir ./stagnet3/live-config;

# ./vegacapsule template node-sets \
#     --home-path ./stagnet3/vegacapsule/home \
#     --path ./stagnet3/vegacapsule/config/vega.validators.tmpl.toml \
#     --nodeset-group-name validators \
#     --type vega \
#     --out-dir ./stagnet3/live-config;

# ./vegacapsule template node-sets \
#     --home-path ./stagnet3/vegacapsule/home \
#     --path ./stagnet3/vegacapsule/config/tendermint.validators.tmpl.toml \
#     --nodeset-group-name validators \
#     --type tendermint \
#     --out-dir ./stagnet3/live-config;

# ./vegacapsule template node-sets \
#     --home-path ./stagnet3/vegacapsule/home \
#     --path ./stagnet3/vegacapsule/config/vega.full.tmpl.toml \
#     --nodeset-group-name full \
#     --type vega \
#     --out-dir ./stagnet3/live-config;

# ./vegacapsule template node-sets \
#     --home-path ./stagnet3/vegacapsule/home \
#     --path ./stagnet3/vegacapsule/config/tendermint.full.tmpl.toml \
#     --nodeset-group-name full \
#     --type tendermint \
#     --out-dir ./stagnet3/live-config;

# ./vegacapsule template node-sets \
#     --home-path ./stagnet3/vegacapsule/home \
#     --path ./stagnet3/vegacapsule/config/data_node.full.tmpl.toml \
#     --nodeset-group-name full \
#     --type data-node \
#     --out-dir ./stagnet3/live-config;