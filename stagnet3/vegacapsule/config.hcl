# Used to generate config locally
vega_binary_path = "vega-v0.50.0"

network "testnet" {
	ethereum {
    chain_id   = "3"
    network_id = "3"
    endpoint   = "https://ropsten.infura.io/v3/63f0f9cb9e6d4c67aeb84d3a2134e719"
  }
  
//   faucet "faucet-1" {
// 	  wallet_pass = "f4uc3tw4ll3t-v3g4-p4ssphr4e3"

// 	  template = <<-EOT
// [Node]
//   Port = 3002
//   IP = "0.0.0.0"
// EOT
//   }

//   wallet "wallet-1" {
//     binary = "vegawallet"
    
//     template = <<-EOT
// Name = "DV"
// Level = "info"
// TokenExpiry = "168h0m0s"
// Port = 1789
// Host = "0.0.0.0"

// [API]
//   [API.GRPC]
//     Hosts = [{{range $i, $v := .Validators}}{{if ne $i 0}},{{end}}"n0{{ add $i 1 }}.stagnet3.vega.xyz:3002"{{end}}]
//     Retries = 5
// EOT
//   }

  pre_start {
    // docker_service "ganache-1" {
    //   image = "vegaprotocol/ganache:latest"
    //   cmd = "ganache-cli"
    //   args = [
    //     "--blockTime", "1",
    //     "--chainId", "1440",
    //     "--networkId", "1441",
    //     "-h", "0.0.0.0",
    //     "-p", "8545",
    //     "-m", "ozone access unlock valid olympic save include omit supply green clown session",
    //     "--db", "/app/ganache-db",
    //   ]
    //   static_port {
    //     value = 8545
    //     to = 8545
    //   }
    //   auth_soft_fail = true
    // }
  }
  
  genesis_template_file = "./genesis.tmpl.json"

  node_set "validators" {
    count = 2
    mode = "validator"
    node_wallet_pass = "n0d3w4ll3t-p4ssphr4e3"
    vega_wallet_pass = "w4ll3t-p4ssphr4e3"
    ethereum_wallet_pass = "ch41nw4ll3t-3th3r3um-p4ssphr4e3"
    nomad_job_template_file = "./node_set.tmpl.nomad"

    config_templates {

// ============================
// ===== VegaNode Config ======
// ============================

      vega = <<-EOT
[API]
	Port = 3002
	[API.REST]
			Port = 3003

[Blockchain]
	[Blockchain.Tendermint]
		ClientAddr = "tcp://127.0.0.1:26657"
		ServerAddr = "0.0.0.0"
		ServerPort = 26608
	[Blockchain.Null]
		Port = 3101

[EvtForward]
	Level = "Info"
	RetryRate = "1s"
	{{if .FaucetPublicKey}}
	BlockchainQueueAllowlist = ["{{ .FaucetPublicKey }}"]
	{{end}}

[NodeWallet]
	[NodeWallet.ETH]
		Address = "https://ropsten.infura.io/v3/ffa591112b994ab29a076518f14768e1"

[Processor]
	[Processor.Ratelimit]
		Requests = 10000
		PerNBlocks = 1

[Admin.Server]
  SocketPath = "/local/vega/vega.sock"
  HttpPath = "/rpc"
  Enabled = true

[Metrics]
  Level = "Info"
  Timeout = "5s"
  Port = 2112
  Path = "/metrics"
  Enabled = true
EOT

// ============================
// ==== Tendermint Config =====
// ============================


// TODO: Add support for more than 9 nodes(n0X vs n1X)
	  tendermint = <<-EOT
log_level = "info"

proxy_app = "tcp://127.0.0.1:26608"
moniker = "n0{{ add .NodeNumber 1 }}.stagnet3.vega.xyz"

[rpc]
  laddr = "tcp://0.0.0.0:26657"
  unsafe = true
  cors_allowed_origins = ["*"]
  cors-allowed-methods = ["HEAD", "GET", "POST", ]
  cors-allowed-headers = ["Origin", "Accept", "Content-Type", "X-Requested-With", "X-Server-Time", ]

[p2p]
  laddr = "tcp://0.0.0.0:26656"
  external_address = "n0{{ add .NodeNumber 1 }}.stagnet3.vega.xyz:26656"
  addr_book_strict = false
  max_packet_msg_payload_size = 4096
  pex = false
  allow_duplicate_ip = true

  persistent_peers = "{{- range $i, $peer := .NodePeers -}}
	  {{- if ne $i 0 }},{{end -}}
	  {{- $peer.ID}}@n0{{ add $i 1 }}.stagnet3.vega.xyz:26656
  {{- end -}}"

[mempool]
  size = 10000
  cache_size = 20000

[consensus]
  skip_timeout_commit = false
EOT
    }
  }

  node_set "full" {
    count = 1
    mode = "full"
	  data_node_binary = "data-node"
    nomad_job_template_file = "./node_set.tmpl.nomad"

    config_templates {

// ============================
// ===== VegaNode Config ======
// ============================

// TODO: Add support for more than 9 nodes(n0X vs n1X)
      vega = <<-EOT
[Admin.Server]
  SocketPath = "/local/vega/vega.sock"
  Enabled = true

[API]
  Port = 3002
  IP = "0.0.0.0"
  [API.REST]
    Port = 3003

[Blockchain]
	[Blockchain.Tendermint]
		ClientAddr = "tcp://127.0.0.1:26657"
		ServerAddr = "0.0.0.0"
		ServerPort = 26608
	[Blockchain.Null]
		Port = 3101

[EvtForward]
	Level = "Info"
	RetryRate = "1s"

[NodeWallet]
	[NodeWallet.ETH]
		Address = "https://ropsten.infura.io/v3/ffa591112b994ab29a076518f14768e1"

[Processor]
	[Processor.Ratelimit]
		Requests = 10000
		PerNBlocks = 1

[Broker]
  [Broker.Socket]
    Port = 3005
    Enabled = true

[Metrics]
  Level = "Info"
  Timeout = "5s"
  Port = 2112
  Path = "/metrics"
  Enabled = true
EOT

// ============================
// ===== DataNode Config ======
// ============================

      data_node = <<-EOT
GatewayEnabled = true
[SqlStore]
  Port = 5032

[API]
  Level = "Info"
  Port = 3007
  CoreNodeGRPCPort = 3002

[Pprof]
  Level = "Info"
  Enabled = true
  Port = 6060
  ProfilesDir = "/local/vega/.data-node"

[Gateway]
  Level = "Info"
  [Gateway.Node]
    Port = 3007
  [Gateway.GraphQL]
    Port = 3008
  [Gateway.REST]
    Port = 3009
	
[Metrics]
  Level = "Info"
  Timeout = "5s"
  Port = 2102
  Enabled = false
[Broker]
  Level = "Info"
  UseEventFile = false
  [Broker.SocketConfig]
    Port = 3005

EOT

// ============================
// ==== Tendermint Config =====
// ============================

// TODO: Add support for more than 9 nodes(n0X vs n1X)
	  tendermint = <<-EOT
log_level = "debug"

proxy_app = "tcp://127.0.0.1:26608"
moniker = "n0{{ add .NodeNumber 1 }}.stagnet3.vega.xyz"

[rpc]
  laddr = "tcp://0.0.0.0:26657"
  unsafe = true
  cors_allowed_origins = ["*"]
  cors-allowed-methods = ["HEAD", "GET", "POST", ]
  cors-allowed-headers = ["Origin", "Accept", "Content-Type", "X-Requested-With", "X-Server-Time", ]

[p2p]
  laddr = "tcp://0.0.0.0:26656"
  external_address = "n0{{ add .NodeNumber 1 }}.stagnet3.vega.xyz:26656"
  addr_book_strict = false
  max_packet_msg_payload_size = 4096
  pex = false
  allow_duplicate_ip = true
  persistent_peers = "{{- range $i, $peer := .NodePeers -}}
	  {{- if ne $i 0 }},{{end -}}
	  {{- $peer.ID}}@n0{{ add $i 1 }}.stagnet3.vega.xyz:26656
  {{- end -}}"

[mempool]
  size = 10000
  cache_size = 20000

[consensus]
  skip_timeout_commit = false
EOT
    }
  }

  smart_contracts_addresses = <<-EOT
{
  "addr0": {
    "priv": "xxx",
    "pub": "xxx"
  },
  "MultisigControl": {
    "Ethereum": "0xDD2df0E7583ff2acfed5e49Df4a424129cA9B58F"
  },
  "ERC20_Asset_Pool": {
    "Ethereum": "0x82A557e31c7ac6B8F64704d740abE1f4c6f38Ca9"
  },
  "erc20_bridge_1": {
    "Ethereum": "0x11E84824Eb84ac2aa54E1336732d534F7A0E1E64"
  },
  "erc20_bridge_2": {
    "Ethereum": "0x0"
  },
  "VEGA": {
    "Ethereum": "0x123CB30f41Af7552561A4b9A6e920DEAA6b58810",
    "Vega": "0xb4f2726571fbe8e33b442dc92ed2d7f0d810e21835b7371a7915a365f07ccd9b"
  },
  "VEGAv1": {
    "Ethereum": "0x0",
    "Vega": "0xc1607f28ec1d0a0b36842c8327101b18de2c5f172585870912f5959145a9176c"
  },
  "erc20_vesting": {
    "Ethereum": "0x0"
  },
  "staking_bridge": {
    "Ethereum": "0xA7298dbC0C0Df4739Ca6a5E5440577cC39f37222"
  }
}
EOT
}
