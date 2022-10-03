{{ $nodeIDX := add .Index 1 }}
{{ $prefixedNodeIDX := nospace (cat "n0" (add .Index 1)) }}
{{ $postgresqlInitScripts := list "01-init-db.sql" "02-init-schema.sh" }}


##
 # Assumptions:
 #   - exec driver run tasks in isolation mode which implies:
 #       - processes, networks, files are isolated
 #       - task shares files with host only via volumes
 #
 # With raw_exec sometimes processes are orphaned by nomad and they are running without any control
 # More over there is no isolation for raw_exec.
 #
locals {
  caddy_version = "2.5.1"
  // TODO Remove it and move it to the role
  aws_access_key_id = "{{ env "AWS_ACCESS_KEY_ID" }}"
  aws_access_key_secret = "{{ env "AWS_SECRET_ACCESS_KEY" }}"
  aws_region = "{{ env "AWS_REGION" }}"
  s3_bucket_name = "{{ env "S3_BUCKET_NAME" }}"

  binaries_artifacts = {
    "/tmp/local/vega/bin/vegacapsule" = {
      path = "https://github.com/vegaprotocol/vegacapsule/releases/download/v0.2.3/vegacapsule-linux-amd64.zip"
      mode = "file"
    }
  }

  s3_binaries_artifacts = {
     "/tmp/local/vega/bin/vega" = {
       path = "{{ env "VEGACAPSULE_S3_RELEASE_TARGET" }}/vega"
       mode = "file"
     }
     "/tmp/local/vega/bin/data-node" = {
       path = "{{ env "VEGACAPSULE_S3_RELEASE_TARGET" }}/data-node"
       mode = "file"
     }
  }

  tendermint_artifacts = {
    "/tmp/local/vega/.tendermint/config" = {
      path = "stagnet3/tendermint/node{{ .Index }}/config"
      mode = "dir"
    }
    "/tmp/local/vega/.tendermint/data/priv_validator_state.json" = {
      path = "stagnet3/tendermint/node{{ .Index }}/data/priv_validator_state.json"
      mode = "file"
    }
  }

  tendermint_validator_artifacts = {}

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
      local.tendermint_validator_artifacts,
      local.vega_validator_artifacts)
  {{ end }}

  caddy_config = replace(file("{path.folder}/../config/Caddyfile"), "{node_idx}", "{{ $prefixedNodeIDX }}")

  resources = {
    default = {
      vega_cpu = 1001
      data_node_cpu = 1002
      vega_explorer_cpu = 300
      vega_memory = 1003
      data_node_memory = 1004
      max_memory = 12288
      vega_explorer_memory = 401
      psql_cpu = 1000
      psql_memory = 2000
    }

    nodes = {
      n01 = {
        vega_cpu = 2500
        data_node_cpu = 2500
        vega_memory = 5000
        data_node_memory = 5200
        psql_cpu = 1500
        psql_memory = 2000
        max_memory = 14000
        psql_max_memory = 9000
      }
      n02 = {
        vega_cpu = 7800
        vega_memory = 12500
        max_memory = 13500
      }
      n03 = {
        vega_cpu = 8000
        vega_memory = 6500
      }
      n04 = {
        vega_cpu = 3000
        vega_memory = 2800
      }
      n05 = {
        vega_cpu = 8000
        vega_memory = 6500
      }
      n06 = {
        vega_cpu = 3000
        vega_memory = 6500
      }
      n07 = {
        vega_cpu = 8000
        vega_memory = 6500
      }
      n08 = {
        vega_cpu = 3000
        vega_memory = 2800
      }
    }
  }

  current_node_resources = lookup(local.resources.nodes, "{{$prefixedNodeIDX}}", local.resources.default)
}

job "{{ .Name }}" {
  // Currently impossible to wildcard datacenters so we have to list all our DCs
  // Ref: https://github.com/hashicorp/nomad/issues/9024
  datacenters = [
    "eu-west-2c (AWS)",
    "northamerica-northeast1-a (GCP)",
    "sgp1 (DO)",
    "asia-southeast1-a (GCP)",
    "ap-northeast-2a (AWS)",
    "sfo3 (DO)",
    "fra1 (DO)"
  ]

  // Pin particular task on particular nomad node
  constraint {
    attribute = "${meta.node}"
    value     = "0{{ $nodeIDX }}" // TODO: Add support for more than 10 nodes
  }

  group "vega-node" {
    reschedule {
      attempts  = 0
      unlimited = false
    }

    restart {
      attempts = 0
    }

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


      dynamic "artifact" {
        for_each = local.s3_binaries_artifacts

        content {
          source = format("s3::https://s3-%s.amazonaws.com/%s/%s", local.aws_region, local.s3_bucket_name, artifact.value.path)
          destination = artifact.key
          mode = lookup(artifact.value, "mode", "any")

          options {
            aws_access_key_id     = local.aws_access_key_id
            aws_access_key_secret = local.aws_access_key_secret
            region = local.aws_region
          }
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
          source = format("s3::https://s3-%s.amazonaws.com/%s/%s", local.aws_region, local.s3_bucket_name, artifact.value.path)
          destination = artifact.key
          mode = lookup(artifact.value, "mode", "any")

          options {
            aws_access_key_id     = local.aws_access_key_id
            aws_access_key_secret = local.aws_access_key_secret
            region = local.aws_region
          }
        }
      }

      template {
        data        = file("{path.folder}/../config/blockexplorer.toml")
        destination = "/tmp/local/vega/.blockexplorer/config/.blockexplorer/config.toml"
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

          mkdir -p /local/vega/.blockexplorer/config/.blockexplorer;
          rsync \
            --ignore-times \
            -rvh \
              tmp//local/vega/.blockexplorer/config/.blockexplorer/ /local/vega/.blockexplorer/config/.blockexplorer/;


          chown vega:vega -R /local/vega/.data-node;
          chown vega:vega -R /local/vega/.blockexplorer;
          {{ end }}

          mkdir -p /local/vega/logs && chown vega:vega /local/vega/logs;

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
          join(" ", [
            // Hotfix for: https://github.com/vegaprotocol/vegacapsule/issues/229
            {{ if .DataNode }}
            "sleep 40;",
            {{ end }}
            // HOTFIX END
            "/local/vega/bin/vega",
              "node",
              "--home", "/local/vega/.vega",
              "--nodewallet-passphrase-file", "/local/vega/.vega/node-vega-wallet-pass.txt",
              "--tendermint-home", "/local/vega/.tendermint"
          ])
        ]
      }
    }

    task "logger" {
      volume_mount {
        volume      = "vega_home_volume"
        destination = "/local/vega"
        read_only = false
      }

      driver = "exec"
      user = "vega"

      config {
        command = "bash"
        args = [
          "-c",
          join(" ", [
            "/local/vega/bin/vegacapsule",
              "nomad", "logscollector",
              "--out-dir", "/local/vega/logs"
          ])
        ]
      }

      resources {
        cpu    = 100
        memory = 100
        memory_max = 300
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
      
      restart {
        attempts = 3
        delay    = "30s"
      }

      config {
        command = "bash"
        args = [
          "-c",
          "/local/vega/bin/data-node node --home /local/vega/.data-node"
        ]
      }

      resources {
        cpu    = lookup(
          local.current_node_resources,
          "data_node_cpu",
          local.resources.default.data_node_cpu
        )
        memory = lookup(
          local.current_node_resources,
          "data_node_memory",
          local.resources.default.data_node_memory
        )
        memory_max = lookup(
          local.current_node_resources,
          "max_memory",
          local.resources.default.max_memory
        )
      }
    }

    task "vega-blockexplorer" {
      volume_mount {
        volume      = "vega_home_volume"
        destination = "/local/vega"
        read_only = false
      }

      driver = "exec"
      user = "vega"

      config {
        command = "bash"
        args = [
          "-c",
          join(" ", [
            "/local/vega/bin/vega",
              "blockexplorer",
              "start",
              "--home", "/local/vega/.blockexplorer"
          ])
        ]
      }

      resources {
        cpu    = lookup(
          local.current_node_resources,
          "vega_explorer_cpu",
          local.resources.default.vega_explorer_cpu
        )
        memory = lookup(
          local.current_node_resources,
          "vega_explorer_memory",
          local.resources.default.vega_explorer_memory
        )
        memory_max = lookup(
          local.current_node_resources,
          "max_memory",
          local.resources.default.max_memory
        )
      }
    }
    {{ end }}
  }

  {{ if .DataNode }}
  group "postgres" {
    reschedule {
      attempts  = 0
      unlimited = false
    }
    
    restart {
      attempts = 0
    }

    network {
      mode = "bridge"

      port "postgres" {
        static = 5432
        to = 5432
      }
    }

    task "docker-container" {
      driver = "docker"

      {{ range $fileName := $postgresqlInitScripts }}
      template {
        data        = file("{path.folder}/../config/init/postgres/{{- $fileName -}}")
        destination = "local/{{- $fileName -}}"
      }
      {{ end }}

      env {
        POSTGRES_USER = "vega"
        POSTGRES_PASSWORD = "ec27af68a52b74665860889db70fe327"
        POSTGRES_DBS = "vega0"
        TS_TUNE_NUM_CPUS = "2"
        TS_TUNE_MEMORY = "500MB"
        TS_TUNE_MAX_BG_WORKERS = "10"
        TS_TUNE_MAX_CONNS = "100"
      }

      config {
        image = "vegaprotocol/timescaledb:2.8.0-pg14"
        command = "postgres"
        args = [
        ]
        volumes = [
          "local/pg_data:/var/lib/postgresql/data"
        ]
        ports = ["postgres"]
        auth_soft_fail = true

        {{ range $fileName := $postgresqlInitScripts }}
        mount {
          type   = "bind"
          source = "local/{{- $fileName -}}"
          target = "/docker-entrypoint-initdb.d/{{- $fileName -}}"
        }
        {{ end }}
      }

      resources {
        cpu    = lookup(
          local.current_node_resources, 
          "psql_cpu", 
          local.resources.default.psql_memory
        )
        memory = lookup(
          local.current_node_resources, 
          "psql_memory", 
          local.resources.default.psql_memory
        )
        memory_max = lookup(
          local.current_node_resources, 
          "psql_max_memory", 
          local.resources.default.max_memory
        )
      }
    }
  }
  {{ end }}

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