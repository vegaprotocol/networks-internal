# fairground

Here is the specification for the environment. To look up machine sizes please take a look into one of the following:

* [DigitalOcean](https://slugs.do-api.dev/)
* [AWS](https://aws.amazon.com/ec2/instance-types/)
* [GCP](https://gcpinstances.doit-intl.com/)

You can check networks status [here](https://stats.vega.trading/) under `fairground`

| Node DNS (reffer to `Caddyfile` for GRPC) | Tendermint DNS | API DNS (`/query` and `/graphql` endpoints) | Geographic Location | Hardware Setup | Cloud |
| ----------------------------------------- | -------------- | --------------------------------------------| ------------------- | -------------- | ----- |
| n00.tmp.vega.xyz | tm.n00.tmp.vega.xyz | api.n00.tmp.vega.xyz | fra1 | s-4vcpu-8gb | do |
| n01.tmp.vega.xyz | tm.n01.tmp.vega.xyz | api.n01.tmp.vega.xyz | fra1 | s-4vcpu-8gb | do |
| n02.tmp.vega.xyz | tm.n02.tmp.vega.xyz | api.n02.tmp.vega.xyz | sfo3 | s-4vcpu-8gb | do |
| n03.tmp.vega.xyz | tm.n03.tmp.vega.xyz | api.n03.tmp.vega.xyz | sgp1 | s-4vcpu-8gb | do |
| n04.tmp.vega.xyz | tm.n04.tmp.vega.xyz | api.n04.tmp.vega.xyz | asia-east2-a | n1-standard-2 | gcp |
| n05.tmp.vega.xyz | tm.n05.tmp.vega.xyz | api.n05.tmp.vega.xyz | eu-west-2c | c5.large | aws |
| n06.tmp.vega.xyz | tm.n06.tmp.vega.xyz | api.n06.tmp.vega.xyz | fra1 | s-4vcpu-8gb | do |
| n07.tmp.vega.xyz | tm.n07.tmp.vega.xyz | api.n07.tmp.vega.xyz | asia-northeast1-a | n1-highmem-4 | gcp |
| n08.tmp.vega.xyz | tm.n08.tmp.vega.xyz | api.n08.tmp.vega.xyz | eu-west-2c | c5.large | aws |
| n09.tmp.vega.xyz | tm.n09.tmp.vega.xyz | api.n09.tmp.vega.xyz | sfo3 | s-4vcpu-8gb | do |
| n10.tmp.vega.xyz | tm.n10.tmp.vega.xyz | api.n10.tmp.vega.xyz | sgp1 | s-4vcpu-8gb | do |
| n11.tmp.vega.xyz | tm.n11.tmp.vega.xyz | api.n11.tmp.vega.xyz | fra1 | s-4vcpu-8gb | do |
| n12.tmp.vega.xyz | tm.n12.tmp.vega.xyz | api.n12.tmp.vega.xyz | fra1 | s-4vcpu-8gb | do |
