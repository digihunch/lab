#! /bin/bash

echo "Entering script $0"

useradd -r -m -s /bin/bash slurm
usermod -aG sudo slurm
echo "slurm ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/slurm-user
chmod 440 /etc/sudoers.d/slurm-user
apt update 
#apt-get remove -y unattended-upgrades
apt install -y slurm-wlm munge
chown -R slurm:slurm /etc/slurm
mkdir -p /var/spool/slurm
chown -R slurm:slurm /var/spool/slurm

echo "Leaving script $0"