job "{{ .RemoteCommandRunner.Name }}" {
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

  group "command-runner" {
    network {
      mode = "host"
    }

    volume "vega_home_volume" {
      type = "host"
      read_only = false
      source = "vega-home-volume"
    }

    task "runner" {
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
          "for (( ; ; )); do sleep 3600; done;" # just run forever
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