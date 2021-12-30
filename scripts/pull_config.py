#!/usr/bin/env python3
from typing import Optional
import argparse
from pathlib import Path
import subprocess

pull_files = {
    "genesis.json": "/home/vega/.tendermint/config/genesis.json",
    "tendermint-config.toml": "/home/vega/.tendermint/config/config.toml",
}

root_dir = Path(__file__).parent.parent

config = {
    "devnet": {
        "host": "n01.d.vega.xyz",
        "target_dir": root_dir / "devnet",
    },
    "stagnet1": {
        "host": "n01.s.vega.xyz",
        "target_dir": root_dir / "stagnet1",
    },
    "stagnet2": {
        "host": "v01.stagnet2.vega.xyz",
        "target_dir": root_dir / "stagnet2",
    },
    "fairground": {
        "host": "n01.testnet.vega.xyz",
        "target_dir": root_dir / "fairground",
    },
}


def download_file(
    ssh_user: str,
    ssh_keyfile: Optional[str],
    host: str,
    remote_file: str,
    target_file: str,
):
    remote_shell = f"ssh -i {ssh_keyfile}" if ssh_keyfile else "ssh"

    print(f"Downloading file {remote_file} ... ", flush=True, end="")
    subprocess.call(
        [
            "rsync",
            "-avz",
            "--quiet",
            "-e",
            remote_shell,
            f"{ssh_user}@{host}:{remote_file}",
            str(target_file),
        ]
    )
    print("done")


def main(network: str, ssh_user: str, ssh_keyfile: Optional[str]):
    host: str = config[network]["host"]
    target_dir: Path = config[network]["target_dir"]

    for target_filename, remote_file in pull_files.items():
        target_file = target_dir / target_filename
        download_file(ssh_user, ssh_keyfile, host, remote_file, target_file)


def parse_args():
    parser = argparse.ArgumentParser(description="Pull remote config files")
    parser.add_argument(
        "--network",
        "-n",
        required=True,
        type=str,
        choices=config.keys(),
        help="Network",
    )
    parser.add_argument(
        "--ssh-user",
        "-u",
        required=True,
        type=str,
        help="ssh user",
    )
    parser.add_argument(
        "--ssh-keyfile",
        "-k",
        required=False,
        type=str,
        help="File with private ssh key",
    )

    return parser.parse_args()


if __name__ == "__main__":
    main(**vars(parse_args()))
