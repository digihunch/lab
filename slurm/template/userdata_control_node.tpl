#! /bin/bash

echo "Entering script $0"

runuser -l slurm -c '
  mkdir -p ~/.ssh && chmod 700 ~/.ssh && \
  echo "${pubkey_content}" > ~/.ssh/id_rsa.pub && \
  echo "${privkey_content}" > ~/.ssh/id_rsa && \
  echo "${authkey_content}" > ~/.ssh/authorized_keys && \
  chmod 600 ~/.ssh/id_rsa && \
  echo export AWS_REGION=${aws_region} >> ~/.bashrc
'

echo "Leaving script $0"