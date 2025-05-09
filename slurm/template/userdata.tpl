#! /bin/bash

echo "Entering script myuserdata"
echo aws_region=${aws_region}
yum update -y
yum install -y nc git jq


runuser -l ec2-user -c '
  echo export AWS_REGION=${aws_region} >> ~/.bashrc && \
  echo export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text) >> ~/.bashrc
'
sed -i 's/Bootstrapping in progress/Bootstrapping completed/g' /etc/motd
echo "Leaving script myuserdata"
