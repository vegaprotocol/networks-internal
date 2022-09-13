{{ $initScripts := list "01-init-db.sql" "02-init-schema.sh" }}

job "postgres-n09" {
  // Currently impossible to wildcard datacenters so we have to list all our DCs
  // Ref: https://github.com/hashicorp/nomad/issues/9024
  datacenters = [
    "sgp1 (DO)",
    "fra1 (DO)",
    "sfo3 (DO)",
    "ams3 (DO)"
  ]

  // Pin particular task on particular nomad node
  constraint {
    attribute = "${meta.node}"
    value     = "09"
  }

  group "postgres" {
    network {
      mode = "host"

      port "postgres" {
        static = 5432
        to = 5432
      }
    }

    task "docker-container" {
      driver = "docker"

      {{ range $fileName := $initScripts }}
      template {
        data        = file("{path.folder}/../config/init/postgres/{{- $fileName -}}")
        destination = "local/{{- $fileName -}}"
      }
      {{ end }}

      env {
        POSTGRES_USER = "vega"
        POSTGRES_PASSWORD = "ec27af68a52b74665860889db70fe327"
        POSTGRES_DBS = "vega0"
      }

      config {
        image = "vegaprotocol/timescaledb:2.7.1-pg14-patch1"
        command = "postgres"
        args = []
        ports = ["postgres"]
        auth_soft_fail = true

        {{ range $fileName := $initScripts }}
        mount {
          type   = "bind"
          source = "local/{{- $fileName -}}"
          target = "/docker-entrypoint-initdb.d/{{- $fileName -}}"
        }
        {{ end }}
      }

      resources {
        cpu    = 7000
        memory = 7000
        memory_max = 12288
      }
    }
  }
}