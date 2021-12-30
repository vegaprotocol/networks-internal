# networks-internal
The configuration for vega operated testnets

## Update config files

To pull latest config files from a network you need to have `python3` and `rsync` installed.

Then you can run:

```bash
./scripts/pull_config.py -u [ssh username] -n (devnet|stagnet1|stagnet2|fairground)
```

You can also specify ssh key file:

```bash
./scripts/pull_config.py -u [ssh username] -k [path to ssh private key] -n (devnet|stagnet1|stagnet2|fairground)
```
