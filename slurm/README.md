# create a Slurm Cluster quick and dirty

## Creation
1. Use `vpc-base` template to create VPCs, and set value for the `vpc-id` parameter;
2. Apply this terraform template. note the output variable called `NODE_HOST_LIST`, `HEAD_NODE`, and the output in `/out` directory;
3. SSH to the head node, and set environment variable for all compute hosts:
```sh
export NODE_HOST_LIST="ip-147-206-9-163 ip-147-206-23-30 ip-147-206-9-153 ip-147-206-21-126"
```
4. From head node, push munge key to all compute notes:
```sh
for NODE_HOST in $NODE_HOST_LIST; do
  ssh-keyscan -H $NODE_HOST >> ~/.ssh/known_hosts && sudo cp /etc/munge/munge.key ~ && sudo chown slurm:slurm ~/munge.key && scp ~/munge.key $NODE_HOST: && ssh $NODE_HOST "sudo mv munge.key /etc/munge/munge.key && sudo chown munge:munge /etc/munge/munge.key && sudo systemctl restart munge"
done
```
5. On GPU node only, as slurm user:
a. install NVIDIA driver:
```sh
sudo apt update && sudo apt install -y nvidia-driver-550 nvidia-dkms-550
sudo nvidia-smi
```
b. Add this file
```sh
cat <<EOF > /etc/slurm/gres.conf
Name=gpu Type=tesla File=/dev/nvidia0
EOF
```
6. Back on the control node, populate the file `/etc/slurm/slurm.conf`, based on the file `./out/slurm.conf`, and make the following tweaks:
a. adjust default partition;
b. add this line: `GresTypes=gpu`
c. update configuration for all nodes, using output from below:
```sh
for NODE_HOST in $NODE_HOST_LIST; do
  ssh $NODE_HOST "slurmd -C | head -1"
done
```
d. for lines for GPU nodes, add `Gres=gpu:1` before CPU attribute. For example:
```
NodeName=node01 Gres=gpu:1 CPUs=16 RealMemory=64000
```
e. very important, restart the controller service:
```sh
sudo systemctl restart slurmctld
```
f. push out slurm configuration to all compute nodes:
```sh
for NODE_HOST in $NODE_HOST_LIST; do
  scp /etc/slurm/slurm.conf $NODE_HOST:/etc/slurm/ && ssh $NODE_HOST sudo systemctl restart slurmd
done
```

## Review and Test
1. review all nodes:
```sh
sinfo -Nel  # ensure all nodes are up;
scontrol show nodes  # ensure that those with GPU nodes displays Gres=gpu:1
```
2. test a regular job:
```
cat <<EOF > test.sh
#! /bin/bash
hostname
EOF

chmod +x test.sh

sbatch test.sh

scontrol --details show job=1
```
Go to the assigned node and check output

3. Test a job on GPU nodes:
```sh
cat <<EOF >gpu_job.slurm
#!/bin/bash
#SBATCH --job-name=gpu-test
#SBATCH --output=gpu-test.out
#SBATCH --error=gpu-test.err
#SBATCH --partition=ng_2             # Or whatever the GPU partition is called
#SBATCH --gres=gpu:1                # Request 1 GPU
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --time=00:30:00             # Max job time

# Load required modules (example)
module load cuda/12.0

# Print some system info
echo "Running on host: $(hostname)"
echo "CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES"

# Run your GPU-enabled code
nvidia-smi

# Example GPU computation with PyTorch
#python my_gpu_script.py
EOF
```

4. Submit the job and examine the details
```sh
sbatch gpu_job.slurm
scontrol -dd show job 2
```
Get on the assigned node to watch output



## Troubleshooting
https://slurm.schedmd.com/troubleshoot.html
###  Common points to check
- `/var/log/slurm/slurmd.log` on each compute node
- `/var/log/slurm/slurmctld.log` on head node.



### useful commands and references

https://uwaterloo.ca/math-faculty-computing-facility/services/service-catalogue-teaching-linux/monitoring-slurm-system-nodes-partitions-jobs

http://minglog.hzbmmc.com/2023/05/29/Slurm%E9%9B%86%E7%BE%A4%E7%AE%A1%E7%90%86%E7%B3%BB%E7%BB%9F%E6%90%AD%E5%BB%BA/

https://web.archive.org/web/20250214154502/https://www.run.ai/guides/slurm

https://web.archive.org/web/20250208164258/https://www.run.ai/guides/

https://web.archive.org/web/20250122001730/https://www.run.ai/guides/slurm/slurm-deep-learning

https://web.archive.org/web/20250208150725/https://www.run.ai/guides/slurm/slurm-vs-lsf-vs-kubernetes-scheduler-which-is-right-for-you