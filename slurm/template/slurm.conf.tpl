ClusterName=awscluster
ControlMachine=${controller_hostname}

%{ for nodehost in flatten([for ip in node_group_hostnames: ip]) ~}
NodeName=${nodehost} CPUs=2 Sockets=1 CoresPerSocket=2 State=UNKNOWN
%{ endfor }
%{ for k, v in node_group_hostnames ~}
PartitionName=${k} Nodes=${join(",",v)} Default=YES MaxTime=INFINITE State=UP
%{ endfor }

#CgroupAutomount=yes
#ConstrainCores=no
#ConstrainRAMSpace=no

# Logging and state
SlurmUser=slurm
SlurmdUser=slurm
StateSaveLocation=/var/spool/slurmctld
SlurmdSpoolDir=/var/spool/slurmd
SlurmctldLogFile=/var/log/slurm/slurmctld.log
SlurmdDebug=debug
SlurmdLogFile=/var/log/slurm/slurmd.log
ProctrackType=proctrack/pgid
ReturnToService=2
SlurmctldPidFile=/var/run/slurmctld.pid
SlurmdPidFile=/var/run/slurmd.pid

# Authentication
AuthType=auth/munge
CryptoType=crypto/munge
MpiDefault=none
SlurmctldPort=6817
SlurmdPort=6818

# Scheduling
SchedulerType=sched/backfill
SelectType=select/cons_res
SelectTypeParameters=CR_Core_Memory