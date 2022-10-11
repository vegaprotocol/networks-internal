# Fairground

For the latest info please visit one of the nodes, e.g. https://n01.testnet.vega.xyz

## 5 validators

`n01`, `n02`, `n03`, `n04` and `n05`

Each node is configured in the same way, e.g. for `n01`:
- n01.testnet.vega.xyz:3002 - Vega gRPC
- https://n01.testnet.vega.xyz - Vega REST
- https://tm.n01.testnet.vega.xyz - Tendermint REST
- tm.n01.testnet.vega.xyz:26658 - Tendermint gRPC

## non-validators with data-nodes

`n00`, `n06`, `n07`, `n08`, `n09`, `n10`, `n11` and `n12`

Each node is configured in the same way, e.g. `n06`:
- n06.testnet.vega.xyz:3002 - Vega gRPC
- https://n06.testnet.vega.xyz - Vega REST
- https://tm.n06.testnet.vega.xyz - Tendermint REST
- tm.n06.testnet.vega.xyz:26658 - Tendermint gRPC
- https://api.n06.testnet.vega.xyz - Data Node REST (see [docs](https://docs.fairground.vega.xyz/api/rest/trading_data_v2.html))
- https://api.n06.testnet.vega.xyz/graphql - GraphQL
- https://api.n06.testnet.vega.xyz/graphql/ - GraphQL Playground
- api.n06.testnet.vega.xyz:3007 - Data Node gRPC

Extra: `api.testnet.vega.xyz` points to `api.n00.testnet.vega.xyz`

## Config templates

- Genesis: https://github.com/vegaprotocol/networks-internal/blob/main/fairground/templates/genesis-template.json
- vegawallet config: https://github.com/vegaprotocol/networks-internal/blob/main/fairground/vegawallet-fairground.toml
- tendermint config template: https://github.com/vegaprotocol/ansible/blob/master/roles/barenode/templates/tm/config.toml.j2
- vega config template: https://github.com/vegaprotocol/ansible/blob/master/roles/barenode/templates/vega/config.toml.j2
- data-node config template: https://github.com/vegaprotocol/ansible/blob/master/roles/barenode/templates/datanode/config.toml.j2
- vegavisor startup command (i.e. command that starts vega and data-node): https://github.com/vegaprotocol/ansible/blob/master/roles/barenode/templates/vegavisor/run-config.toml.j2
- Smart-Contract addresses: https://github.com/vegaprotocol/networks-internal/blob/main/fairground/templates/smart_contracts.json
- Node pub keys, ids and metadata - https://github.com/vegaprotocol/networks-internal/blob/main/fairground/templates/nodes.json
- Caddy config template - https://github.com/vegaprotocol/ansible/blob/master/roles/barenode/templates/Caddyfile.j2

## Debugging

ssh into the machine
```bash
ssh [username]@n01.testnet.vega.xyz
```

## Actions

- Restart Node: https://jenkins.ops.vega.xyz/job/private/job/Deployments/job/Fairground/job/Restart-Node/
- Restart Network: https://jenkins.ops.vega.xyz/job/private/job/Deployments/job/Fairground/job/Restart-Network/
- Protocol Upgrade: https://jenkins.ops.vega.xyz/job/private/job/Deployments/job/Fairground/job/Protocol-Upgrade/
- Top Up bots: https://jenkins.ops.vega.xyz/job/private/job/Deployments/job/Fairground/job/Topup-Bots/

## Releases

We publish official releases to `vega` repo to: https://github.com/vegaprotocol/vega/releases

On top of that we build and publish every commit to develop on `vega` repo into: https://github.com/vegaprotocol/vega-dev-releases/releases

if you can't ssh then please add yourself to https://github.com/vegaprotocol/ansible/blob/master/roles/accounts/defaults/main.yaml and create a PR
