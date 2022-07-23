#!/bin/bash

export NOMAD_ADDR="https://n00.stagnet3.vega.xyz:4646";
export NOMAD_CACERT="./certs/nomad-ca.pem";
export NOMAD_CLIENT_CERT="./certs/client.pem";
export NOMAD_CLIENT_KEY="./certs/client-key.pem";
export NOMAD_TLS_SERVER_NAME="server.global.nomad";

unset AWS_PROFILE;
export AWS_REGION="us-east-1";
export AWS_ACCESS_KEY_ID="AKIAVFM72G3TWXHWEFNB";
export AWS_SECRET_ACCESS_KEY="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";
export S3_BUCKET_NAME="vegacapsule-test";

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

if ! aws s3 ls > /dev/null 2>&1; then
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
echo "";

vegacapsule network destroy --home-path ./home || echo "[INFO] network is not stopped"
sleep 3;

echo "";
echo "[INFO] removing previous network chain data";
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>";
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
    ./home/ "s3://${S3_BUCKET_NAME}/stagnet3" && echo "done"
echo "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^";
echo "";
sleep 3;

echo "[INFO] starting the network";
echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>";
vegacapsule network start --home-path ./home
echo "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^";

# echo "[INFO] preparing multisig control"
# echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>";
# vegacapsule ethereum wait --home-path ./home --eth-address "ws://n02.pete-test.vega.xyz:8545"
# vegacapsule ethereum multisig init --home-path ./home --eth-address "ws://n02.pete-test.vega.xyz:8545"
# echo "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^";