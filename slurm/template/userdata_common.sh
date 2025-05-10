#! /bin/bash

echo "Entering script $0"

useradd -r -m slurm
apt update
apt install -y slurm-wlm munge

echo "Leaving script $0"