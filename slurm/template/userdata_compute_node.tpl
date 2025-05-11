#! /bin/bash
echo "Entering script $0"

runuser -l slurm -c '
  ssh-keygen -t rsa -b 4096 -N "" -f ~/.ssh/id_rsa -q && \
  echo "${pubkey_content}" > ~/.ssh/authorized_keys && \
  echo export AWS_REGION=${aws_region} >> ~/.bashrc
'

echo "Leaving script $0"