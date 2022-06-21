
{{ $nodeIDX := add .Index 1 }}
locals {
  caddy_version = "2.5.1"
  caddy_config = <<EOCF

renew_interval = 12h
auto_https = ignore_loaded_certs

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

https://n0{{ $nodeIDX }}.stagnet3.vega.xyz {
  tls devops@vegaprotocol.io

	import datanodepaths
	# import datanodepaths - not on validators
	import tendermintpaths
	# corepaths must be last due to the "/*" fallthrough
	import corepaths
}

http://n0{{ $nodeIDX }}.stagnet3.vega.xyz {

	import datanodepaths
	# import datanodepaths - not on validators
	import tendermintpaths
	# corepaths must be last due to the "/*" fallthrough
	import corepaths
}
EOCF
}

job "caddy-server-n0{{ add .Index 1 }}" {
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
          echo /local/Caddyfile.new > /local/vega/caddy/Caddyfile;
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
          "/local/vega/caddy/bin/caddy run --config /local/vega/caddy/Caddyfile"
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