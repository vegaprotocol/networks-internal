##
 # Assumptions:
 #   - exec driver run tasks in isolation mode which implies:
 #       - processes, networks, files are isolated
 #       - task shares files with host only via volumes 
 #
 # With raw_exec sometimes processes are orphaned by nomad and they are running without any control
 # More over there is no isolation for raw_exec. 
 ##
locals {
  // TODO Remove it and move it to the role
  aws_access_key_id = "AKIAVFM72G3TWXHWEFNB"
  aws_access_key_secret = "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"

  binaries_artifacts = {
    "/tmp/local/vega/bin/vega" = {
      path = "bin/vega-linux-amd64-v0.50.2"
      mode = "file" # https://www.nomadproject.io/docs/job-specification/artifact#mode
    }
    "/tmp/local/vega/bin/data-node" = {
      path = "bin/data-node-linux-amd64-v0.50.3"
      mode = "file"
    }
  }

  tendermint_artifacts = {
    "/tmp/local/vega/.tendermint/config" = {
      path = "stagnet3/tendermint/node{{ .Index }}/config"
      mode = "dir"
    }
    
    // TODO: Fix it, as it may change in meantime
    "/tmp/local/vega/.tendermint/data/priv_validator_state.json" = {
      path = "stagnet3/tendermint/node{{ .Index }}/data/priv_validator_state.json"
      mode = "file"
    }
  }

  data_node_artifacts = {
    "/tmp/local/vega/.data-node/config" = {
      path = "stagnet3/data/node{{ .Index }}/config"
      mode = "dir"
    }
  }

  vega_artifacts = {
    "/tmp/local/vega/.vega/config" = {
      path = "stagnet3/vega/node{{ .Index }}/config"
      mode = "dir"
    }

    "/tmp/local/vega/.vega/data" = {
      path = "stagnet3/vega/node{{ .Index }}/data"
      mode = "dir"
    }

    "/tmp/local/vega/.vega/node-vega-wallet-pass.txt" = {
      path = "stagnet3/vega/node{{ .Index }}/node-vega-wallet-pass.txt"
      mode = "file"
    }
  }

  vega_validator_artifacts = {
    "/tmp/local/vega/.vega/ethereum-vega-wallet-pass.txt" = {
      path = "stagnet3/vega/node{{ .Index }}/ethereum-vega-wallet-pass.txt"
      mode = "file"
    }

    "/tmp/local/vega/.vega/vega-wallet-pass.txt" = {
      path = "stagnet3/vega/node{{ .Index }}/vega-wallet-pass.txt"
      mode = "file"
    }
  }

  {{ if .DataNode }}
    configuration_artifacts = merge(
      local.tendermint_artifacts,
      local.vega_artifacts,
      local.data_node_artifacts)
  {{ else }} 
    configuration_artifacts = merge(
      local.tendermint_artifacts,
      local.vega_artifacts,
      local.data_node_artifacts,
      local.vega_validator_artifacts)
  {{ end }}
}

job "{{ .Name }}" {
  // Currently impossible to wildcard datacenters so we have to list all our DCs
  // Ref: https://github.com/hashicorp/nomad/issues/9024
  datacenters = [
    "asia-southeast1-a",
    "ap-northeast-2",
    "northamerica-northeast1-a",
    "eu-west-1",
    "eu-west-2"
  ]

  // Pin particular task on particular nomad node
  constraint {
    attribute = "${meta.node}"
    value     = "n0{{ add .Index 1 }}" // TODO: Add support for more than 10 nodes
  }

  group "vega-node" {
    network {
      mode = "host"

      port "vega_api" {
        static = 3002
      }
      port "vega_api_rest" {
        static = 3003
      }
      port "vega_metrics" {
        static = 2112
      }

      port "tm_rpc" {
        static = 26657
      }
      port "tm_proxy_app" {
        static = 26608
      }
      port "tm_p2p" {
        static = 26656
      }
    }

    volume "vega_home_volume" {
      type = "host"
      read_only = false
      source = "vega-home-volume"
    }

    task "download-binaries" {
      lifecycle {
        hook = "prestart"
        sidecar = false
      }
      volume_mount {
        volume      = "vega_home_volume"
        destination = "local/vega"
      }

      dynamic "artifact" {
        for_each = local.binaries_artifacts

        content {
          source = format("s3::https://s3.amazonaws.com/vegacapsule-test/%s", artifact.value.path)
          destination = artifact.key
          mode = lookup(artifact.value, "mode", "any")

          options {
            aws_access_key_id     = local.aws_access_key_id
            aws_access_key_secret = local.aws_access_key_secret
          }
        }
      }

      template {
        data = <<EOH
          #!/bin/bash
          set -x;
          echo "Template generated {{ now | date "Mon Jan 2 15:04:05 MST 2006" }}";

          
        EOH

        destination = "pre-start.sh"
        perms = "755"
      }

      driver = "exec"
      user = "root"

      config {
        command = "bash"
        args = ["-c", "/pre-start.sh"]
      }
    }

    task "download-network-config" {
      lifecycle {
        hook = "prestart"
        sidecar = false
      }
      
      volume_mount {
        volume      = "vega_home_volume"
        destination = "local/vega"
      }

      dynamic "artifact" {
        for_each = local.configuration_artifacts

        content {
          source = format("s3::https://s3.amazonaws.com/vegacapsule-test/%s", artifact.value.path)
          destination = artifact.key
          mode = lookup(artifact.value, "mode", "any")

          options {
            aws_access_key_id     = local.aws_access_key_id
            aws_access_key_secret = local.aws_access_key_secret
          }
        }
      }

      // 1. No other option for set permissions for downloaded binary at the moment
      // Ref: https://github.com/hashicorp/nomad/issues/2625
      //
      // 2. Because the task driver mounts the volume, it is not possible to have artifact, 
      //    template, or dispatch_payload blocks write to a volume
      // Ref: https://www.nomadproject.io/docs/internals/filesystem#templates-artifacts-and-dispatch-payloads
      template {
        data = <<EOH
          #!/bin/bash
          set -x;
          echo "Template generated {{ now | date "Mon Jan 2 15:04:05 MST 2006" }}";

          mkdir -p /local/vega/.tendermint;
          rsync \
            --ignore-times \
            -rvh \
            /tmp/local/vega/.tendermint/ /local/vega/.tendermint/; # See point 2 in the comment above

          rsync \
            --ignore-times \
            -rvh \
              tmp/local/vega/.vega/ /local/vega/.vega/; # See point 2 in the comment above

          {{ if .DataNode }}
          rsync \
            --ignore-times \
            -rvh \
              /tmp/local/vega/.data-node/ /local/vega/.data-node/; # See point 2 in the comment above

          chown vega:vega -R /local/vega/.data-node;
          {{ end }}

          
          chown vega:vega -R /local/vega/.tendermint;
          chown vega:vega -R /local/vega/.vega;
        EOH

        destination = "pre-start.sh"
        perms = "755"
      }

      driver = "exec"
      user = "root"

      config {
        command = "bash"
        args = ["-c", "/pre-start.sh"]
      }
    }

    task "tendermint" {
      volume_mount {
        volume      = "vega_home_volume"
        destination = "local/vega"
      }

      driver = "exec"
      user = "vega"

      config {
        command = "bash"
        args = [
          "-c",
          "/local/vega/bin/vega tm node --home /local/vega/.tendermint"
        ]
      }

      resources {
        cpu    = 1000
        memory = 4000
        memory_max = 12288
      }
    }

    task "vega" {
      volume_mount {
        volume      = "vega_home_volume"
        destination = "/local/vega"
        read_only = false
      }

      driver = "exec"
      user = "vega"

      config {
        cap_add = ["audit_write", "chown", "dac_override", "fowner", "fsetid", "kill", "mknod",
                  "net_bind_service", "setfcap", "setgid", "setpcap", "setuid", "sys_chroot"] // TODO: Review if needed
        // pid_mode = "host"
        command = "bash"
        args = [
          "-c",
          "/local/vega/bin/vega node --home /local/vega/.vega --nodewallet-passphrase-file /local/vega/.vega/node-vega-wallet-pass.txt"
        ]
      }

      resources {
        cpu    = 1000
        memory = 4000
        memory_max = 12288
      }
    }
    
    {{ if .DataNode }}
    task "data-node" {
      driver = "exec"
      user = "vega"

      volume_mount {
        volume      = "vega_home_volume"
        destination = "local/vega"
      }

      config {
        command = "bash"
        args = [
          "-c",
          "/local/vega/bin/data-node node --home /local/vega/.data-node"
        ]
      }

      resources {
        cpu    = 1000
        memory = 4000
        memory_max = 12288
      }
    }
    {{ end }}
  }
}