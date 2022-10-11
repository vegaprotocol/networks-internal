
## Restart a single node

1. Go to [Jenkins](https://jenkins.ops.vega.xyz/) and navigate `[private]` -> `Deployments` -> `/network/` e.g. fairground -> `Restart-Node` (not network) -> `Build with Parameters`

2. From options
  - pick a node
  - choose the way to restart
    - `restart-node` - standard restart that applies config changes, but do not delete "one time setup"
    - `quick-restart-node` - just stop start node, without applying any config changes - this action should be much quicker than regular restart
    - `create-node` - use when creating a new node, or hard reseting config/setup. It deletes all home directories and perform every setup up step
  - `UNSAFE_RESET_ALL` - select if you want to restart without local snapshot and local tendermint data, i.e. from block 0. un-select to use lcoal snapshot data
  - `RELEASE_VERSION` - vega version to start the node with. This need to be published release version. Required for `create-node` option.
  - rest leave empty

3. Click `Build`

## Restart a network

This will restart network from block 0. 

1. Go to [Jenkins](https://jenkins.ops.vega.xyz/) and navigate `[private]` -> `Deployments` -> `/network/` e.g. fairground -> `Restart-Network` (not node) -> `Build with Parameters`

2. From options
  - choose the way to restart
    - `restart-network` - standard restart that applies config changes, but do not delete "one time setup"
    - `quick-restart-network` - just stop start nodes, without applying any config changes - this action should be much quicker than regular restart
    - `create-network` - use when creating a new network, or hard reseting config/setup. It deletes all home directories and perform every setup up step
  - `RELEASE_VERSION` - vega version to start the node with. This need to be published release version. Required for `create-network` option.
  - `VEGA_VERSION` - leave empty

3. Click `Build`
