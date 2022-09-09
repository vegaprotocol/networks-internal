# stagnet3

Here is the specification for the environment. To look up machine sizes please take a look into one of the following:

* [DigitalOcean](https://slugs.do-api.dev/)
* [AWS](https://aws.amazon.com/ec2/instance-types/)
* [GCP](https://gcpinstances.doit-intl.com/)

You can check networks status [here](https://stats.vega.trading/) under `stagnet3`

| Node DNS (reffer to `Caddyfile` for GRPC) | Tendermint DNS | API DNS (`/query` and `/graphql` endpoints) | Geographic Location | Hardware Setup | Cloud |
| ----------------------------------------- | -------------- | --------------------------------------------| ------------------- | -------------- | ----- |
| n00.stagnet3.vega.xyz | tm.n00.stagnet3.vega.xyz | api.n00.stagnet3.vega.xyz | fra1 | s-2vcpu-4gb | do |
| n01.stagnet3.vega.xyz | tm.n01.stagnet3.vega.xyz | api.n01.stagnet3.vega.xyz | northamerica-northeast1-a | n1-standard-4 | gcp |
| n02.stagnet3.vega.xyz | tm.n02.stagnet3.vega.xyz | api.n02.stagnet3.vega.xyz | asia-southeast1-a | n1-standard-4 | gcp |
| n03.stagnet3.vega.xyz | tm.n03.stagnet3.vega.xyz | api.n03.stagnet3.vega.xyz | sgp1 | s-4vcpu-8gb | do |
| n04.stagnet3.vega.xyz | tm.n04.stagnet3.vega.xyz | api.n04.stagnet3.vega.xyz | fra1 | s-4vcpu-8gb | do |
| n05.stagnet3.vega.xyz | tm.n05.stagnet3.vega.xyz | api.n05.stagnet3.vega.xyz | fra1 | s-4vcpu-8gb | do |
| n06.stagnet3.vega.xyz | tm.n06.stagnet3.vega.xyz | api.n06.stagnet3.vega.xyz | sfo3 | s-4vcpu-8gb | do |
| n07.stagnet3.vega.xyz | tm.n07.stagnet3.vega.xyz | api.n07.stagnet3.vega.xyz | fra1 | s-4vcpu-8gb | do |
| n08.stagnet3.vega.xyz | tm.n08.stagnet3.vega.xyz | api.n08.stagnet3.vega.xyz | sgp1 | s-4vcpu-8gb | do |
| n09.stagnet3.vega.xyz | tm.n09.stagnet3.vega.xyz | api.n09.stagnet3.vega.xyz | eu-west-2c | c5.large | aws |
