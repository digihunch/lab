#! /bin/bash

echo "Entering script myuserdata"
useradd -r -m slurm
echo aws_region=${aws_region}
apt update
apt install -y slurm-wlm munge


runuser -l slurm -c '
  ssh-keygen -t rsa -b 4096 -N "" -f ~/.ssh/id_rsa -q && \
  echo "${pubkey_content}" > ~/.ssh/authorized_keys && \
  echo export AWS_REGION=${aws_region} >> ~/.bashrc && \
  echo export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text) >> ~/.bashrc
'
sed -i 's/Bootstrapping in progress/Bootstrapping completed/g' /etc/motd
echo "Leaving script myuserdata"