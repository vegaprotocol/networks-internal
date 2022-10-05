#!/bin/bash


unset AWS_PROFILE;
export AWS_REGION="eu-west-2";
export AWS_ACCESS_KEY_ID="AKIAVFM72G3TXBYO3P73";
export AWS_SECRET_ACCESS_KEY="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";
export S3_BUCKET_NAME="vegacapsule-20220722172637220400000001";

export NOMAD_ADDR="https://n00.stagnet3.vega.xyz:4646";
export NOMAD_CACERT="./certs/nomad-ca.pem";
export NOMAD_CLIENT_CERT="./certs/client.pem";
export NOMAD_CLIENT_KEY="./certs/client-key.pem";
export NOMAD_TLS_SERVER_NAME="server.global.nomad";
export VEGACAPSULE_S3_RELEASE_TARGET="bin/develop"

if ! aws --version > /dev/null 2>&1; then 
    echo "[ERROR] awscli is missing. Install it by following this docs: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html";
    return 1;
fi;

if ! vegacapsule --help > /dev/null 2>&1; then 
    echo "[ERROR] vegacapsule command is missing. Please install it in your PATH" ;
    exit 1;
fi;

if ! vega version > /dev/null 2>&1; then 
    echo "[ERROR] vega command is missing. Please install it in your PATH" ;
    exit 1;
fi;

if ! data-node version > /dev/null 2>&1; then 
    echo "[ERROR] data-node command is missing. Please install it in your PATH" ;
    exit 1;
fi;

if ! aws s3 ls "s3://${S3_BUCKET_NAME}" > /dev/null 2>&1; then
    echo "[ERROR] aws cli has no permissions for S3";
    exit 1;
fi;

if ! nomad version > /dev/null 2>&1; then 
    echo "[ERROR] the nomad command is missing. Please install it in your PATH" ;
    exit 1;
fi;

vega_version=$(vega version);
data_node_version=$(data-node version);

echo "[INFO] vega version: ${vega_version}";
echo "[INFO] data-node version: ${data_node_version}";
echo "";

echo "[INFO] Running garbage collection for nomad";
nomad system gc;
nomad job status --short \
    | grep -v Type \
    | egrep "(running|pending)" \
    | awk '{ print $1 }' \
    | xargs -L 1 nomad job stop -purge \
    || echo 'OK';
echo "";

vegacapsule network destroy --home-path ./home || echo "[INFO] network is not stopped"
sleep 3;

echo "";
echo "[INFO] removing previous network chain data";
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>";
nomad job status --short \
    | grep -v Type \
    | egrep '(running|pending)' \
    | awk '{ print $1 }' \
    | xargs -L 1 nomad job stop \
    || echo 'OK' 
for node in $(seq 1 9); do 
    ssh \
        -o "StrictHostKeyChecking=no" \
        "n0${node}".stagnet3.vega.xyz \
            sudo rm -r /home/vega/.vega /home/vega/.tendermint /home/vega/.data-node 2> /dev/null;
    echo "n0${node} done";
done;
echo "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^";
echo "";
sleep 3;

echo "[INFO] generating network configuration";
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>";
vegacapsule network generate \
    --force \
    --config-path ./config.hcl \
    --home-path ./home || exit 1;
echo "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^";
echo "";
sleep 3;



echo "[INFO] importing validators keys to the networks";
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>";
vegacapsule network keys import --keys-file-path  ./network.json --home-path ./home

# vegacapsule template node-sets --with-merge \
#     --home-path ./home \
#     --path ./config/tendermint.validators.tmpl.toml \
#     --nodeset-group-name validators \
#     --type tendermint \
#     --update-network;
echo "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^";
echo "";
sleep 3;

echo "[INFO] uploading local configuration to the S3";
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>";
aws s3 rm \
    --recursive \
    --only-show-errors \
    "s3://${S3_BUCKET_NAME}/stagnet3";
aws s3 cp \
    --recursive \
    --only-show-errors \
    --no-progress \
    ./home/ "s3://${S3_BUCKET_NAME}/stagnet3" && echo "done"  || exit 1;
echo "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^";
echo "";
sleep 3;

echo "[INFO] starting the network";
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>";
vegacapsule network start --home-path ./home --do-not-stop-on-failure
echo "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^";

# # echo "[INFO] preparing multisig control"
# # echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>";
# # vegacapsule ethereum wait --home-path ./home --eth-address "ws://n02.pete-test.vega.xyz:8545"
# # vegacapsule ethereum multisig init --home-path ./home --eth-address "ws://n02.pete-test.vega.xyz:8545"
# # echo "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^";