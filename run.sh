#!/bin/bash

CPU_COUNT=$(lscpu -p=CPU | grep -v "^#" | wc -l)
MAX_CPU=$(($CPU_COUNT>1 ? 2 : 1))

for R in `seq 1 $CPU_COUNT`; do
  sudo mkdir -p /mnt/agent${R}/w
  sudo docker run --privileged -td --cpus="${CPU_COUNT}" \
  -e AZP_URL="$2" \
  -e AZP_TOKEN="$3" \
  -e AZP_POOL="$4" \
  -e AZP_AGENT_NAME=sha-`hostname`-$R \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /mnt/agent${R}/w:/_work \
  --name agent$R \
  --restart always \
  $1
done
