# devnet2

Here is the specification for the environment. To look up machine sizes please take a look into one of the following:

* [DigitalOcean](https://slugs.do-api.dev/)
* [AWS](https://aws.amazon.com/ec2/instance-types/)
* [GCP](https://gcpinstances.doit-intl.com/)

You can check networks status [here](https://stats.vega.trading/) under `devnet2`

| Node DNS (reffer to `Caddyfile` for GRPC) | Tendermint DNS | API DNS (`/query` and `/graphql` endpoints) | Geographic Location | Hardware Setup | Cloud |
| ----------------------------------------- | -------------- | --------------------------------------------| ------------------- | -------------- | ----- |
| n00.devnet.vega.xyz | tm.n00.devnet.vega.xyz | api.n00.devnet.vega.xyz | fra1 | s-2vcpu-4gb | do |
| n01.devnet.vega.xyz | tm.n01.devnet.vega.xyz | api.n01.devnet.vega.xyz | sfo3 | s-4vcpu-8gb | do |
| n02.devnet.vega.xyz | tm.n02.devnet.vega.xyz | api.n02.devnet.vega.xyz | sgp1 | s-4vcpu-8gb | do |
| n03.devnet.vega.xyz | tm.n03.devnet.vega.xyz | api.n03.devnet.vega.xyz | fra1 | s-4vcpu-8gb | do |
| n04.devnet.vega.xyz | tm.n04.devnet.vega.xyz | api.n04.devnet.vega.xyz | fra1 | s-4vcpu-8gb | do |
