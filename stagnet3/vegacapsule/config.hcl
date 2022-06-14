# Used to generate config locally
vega_binary_path = "vega-v0.50.0"

network "stagnet3" {
	ethereum {
    chain_id   = "3"
    network_id = "3"
    endpoint   = "https://ropsten.infura.io/v3/63f0f9cb9e6d4c67aeb84d3a2134e719"
  }

  pre_start {
  }
  
  genesis_template_file = "./genesis.tmpl.json"

  node_set "validators" {
    count = 7
    mode = "validator"
    node_wallet_pass = "n0d3w4ll3t-p4ssphr4e3"
    vega_wallet_pass = "w4ll3t-p4ssphr4e3"
    ethereum_wallet_pass = "ch41nw4ll3t-3th3r3um-p4ssphr4e3"
    nomad_job_template_file = "./jobs/node_set.tmpl.nomad"

    config_templates {
      vega_file       = "./config/vega.validators.tmpl.toml"
      tendermint_file = "./config/tendermint.validators.tmpl.toml"
    }

    remote_command_runner {
      nomad_job_template_file = "./jobs/command_runner.tmpl.nomad"

      paths_mapping {
        tendermint_home = "/local/vega/.tendermint/"
        vega_home       = "/local/vega/.vega/"
        vega_binary     = "/local/vega/bin/vega"
      }
    }
  }

  node_set "full" {
    count = 1
    mode = "full"
	  data_node_binary = "data-node"
    nomad_job_template_file = "./jobs/node_set.tmpl.nomad"

    config_templates {
      vega_file       = "./config/vega.full.tmpl.toml"
      data_node_file  = "./config/data_node.full.tmpl.toml"
      tendermint_file = "./config/tendermint.full.tmpl.toml"
    }

    remote_command_runner {
      nomad_job_template_file = "./jobs/command_runner.tmpl.nomad"

      paths_mapping {
        tendermint_home = "/local/vega/.tendermint/"
        vega_home       = "/local/vega/.vega/"
        vega_binary     = "/local/vega/bin/vega"

        data_node_home   = "/local/vega/.data-node/"
        data_node_binary = "/local/vega/bin/data-node"  
      }
    }
  }

  smart_contracts_addresses_file = "./smartcontracts_addresses.json"
}
