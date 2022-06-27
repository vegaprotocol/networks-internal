{{ $nodeIDX := add .Index 1 }}

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
  caddy_version = "2.5.1"
  // TODO Remove it and move it to the role
  aws_access_key_id = "AKIAVFM72G3TWXHWEFNB"
  aws_access_key_secret = "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"

  binaries_artifacts = {
    "/tmp/local/vega/bin/vega" = {
      path = "https://github.com/vegaprotocol/vega/releases/download/v0.52.0/vega-linux-amd64"
      mode = "file"
    }
    "/tmp/local/vega/bin/data-node" = {
      path = "https://vegacapsule-test.s3.amazonaws.com/bin/data-node-branch-unsafe_reset_all" # Temp binary with unsafe_reset_all
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

  caddy_config = <<EOCF
{
  renew_interval 12h
}

(cors) {
  @cors_preflight method OPTIONS
  @cors header Origin {args.0}

  handle @cors_preflight {
    header Access-Control-Allow-Origin "{args.0}"
    header Access-Control-Allow-Methods "GET, POST, PUT, PATCH, DELETE"
    header Access-Control-Allow-Headers "*"
    header Access-Control-Max-Age "3600"
    respond "" 204
  }

  handle @cors {
    header Access-Control-Allow-Origin "{args.0}"
    header Access-Control-Expose-Headers "Link"
  }
}

(corepaths) {
	# (gRPC is direct to 3002)

	# Prometheus
	route /core/metrics {
		uri strip_prefix /core
		reverse_proxy http://localhost:2112
	}

	# REST
	route /core/rest/* {
		uri strip_prefix /core/rest
		reverse_proxy http://localhost:3003
	}

  # REST (deprecated) Required for stats
	route /* {
		reverse_proxy http://localhost:3003
	}
}

(datanodepaths) {
	# GraphQL Playground
	route /datanode/gql/playground {
		uri strip_prefix /datanode/gql/playground
		reverse_proxy http://localhost:3008
	}
	route /datanode/gql/playground/* {
		uri strip_prefix /datanode/gql/playground
		reverse_proxy http://localhost:3008
	}
	# GraphQL
	route /datanode/gql/query {
		uri strip_prefix /datanode/gql
		reverse_proxy http://localhost:3008
	}

	# REST
	route /datanode/rest/* {
		uri strip_prefix /datanode/rest
		reverse_proxy http://localhost:3009
	}

	route /playground/* {
		uri strip_prefix /playground
		reverse_proxy http://localhost:3008
	}
}

(tendermintpaths) {
	route /tm {
		uri strip_prefix /tm
		reverse_proxy http://localhost:26657
	}
	route /tm/* {
		uri strip_prefix /tm
		reverse_proxy http://localhost:26657
	}
	# CORS headers for the Explorer
	header /tm Access-Control-Allow-Origin *
	header /tm Access-Control-Request-Method GET
	header /tm/* Access-Control-Allow-Origin *
	header /tm/* Access-Control-Request-Method GET
}

# Validators

n0{{ $nodeIDX }}.stagnet3.vega.xyz:443 {
  tls devops@vegaprotocol.io

	import datanodepaths
	import tendermintpaths
	import corepaths
}
EOCF
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
    value     = "n0{{ $nodeIDX }}" // TODO: Add support for more than 10 nodes
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
          source = artifact.value.path
          destination = artifact.key
          mode = lookup(artifact.value, "mode", "any")
        }
      }

      template {
        data = <<EOH
          #!/bin/bash
          set -x;
          echo "Template generated {{ now | date "Mon Jan 2 15:04:05 MST 2006" }}";

          rm -rf /tmp/tmp-bins || echo "OK";
          mkdir -p /tmp/tmp-bins && mv /local/vega/bin/* /tmp/tmp-bins;

          sudo chmod 755 /tmp/local/vega/bin/*;
          chown vega:vega /tmp/local/vega/bin/*;
          mkdir -p /local/vega/bin;
          cp /tmp/local/vega/bin/* /local/vega/bin/;
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

  group "caddy-server" {
    network {
      mode = "host"

      port "http" {
        static = 80
      }
      port "https" {
        static = 443
      }
    }

    volume "vega_home_volume" {
      type = "host"
      read_only = false
      source = "vega-home-volume"
    }

    task "binary-downloader" {
      lifecycle {
        hook = "prestart"
        sidecar = false
      }

      volume_mount {
        volume      = "vega_home_volume"
        destination = "local/vega"
      }

      artifact {
        source = format("https://github.com/caddyserver/caddy/releases/download/v%s/caddy_%s_linux_amd64.tar.gz",
          local.caddy_version,
          local.caddy_version
        )
        destination = "local/tmp"
      }

      template {
        data = <<EOH
          #!/bin/bash
          set -x;
          echo "Template generated {{ now | date "Mon Jan 2 15:04:05 MST 2006" }}";

          # Move current binaries if running
          rm -f /tmp/caddy-tmp-bin || echo "OK";
          mv /local/vega/caddy/bin/caddy /tmp/caddy-tmp-bin || echo "OK"

          mkdir -p /local/vega/caddy/bin;
          
          # Move downloaded binary to bin dir
          cp /local/tmp/caddy /local/vega/caddy/bin/caddy;
          chown vega:vega /local/vega/caddy/bin/caddy;
          chmod +x /local/vega/caddy/bin/caddy;
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

    task "update-config" {
      lifecycle {
        hook = "prestart"
        sidecar = false
      }

      volume_mount {
        volume      = "vega_home_volume"
        destination = "local/vega"
      }

      template {
        data = local.caddy_config
        destination = "local/Caddyfile.new"
        perms = "644"

        # change delimiter to avoid conflicts with vegacapsule templates
        left_delimiter = "{("
        right_delimiter = ")}"
      }

      template {
        data = <<EOH
          #!/bin/bash

          mkdir -p /local/vega/caddy;
          mkdir -p //local/vega/caddy/data;
          cat /local/Caddyfile.new > /local/vega/caddy/Caddyfile;
          chown vega:vega /local/vega/caddy/Caddyfile;
          chmod 644 /local/vega/caddy/Caddyfile;
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

    task "caddy2" {
      volume_mount {
        volume      = "vega_home_volume"
        destination = "local/vega"
      }

      driver = "exec"
      user = "root"

      env {
        # Required for data-dir: https://caddyserver.com/docs/conventions#data-directory
        XDG_DATA_HOME = "/local/vega/caddy/data"
      }

      config {
        command = "bash"
        args = [
          "-c",
          "cat /local/vega/caddy/Caddyfile && /local/vega/caddy/bin/caddy run --config /local/vega/caddy/Caddyfile"
        ]
      }

      resources {
        cpu    = 100
        memory = 100
        memory_max = 4000
      }
    }
  }
}