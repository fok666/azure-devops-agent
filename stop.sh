#!/bin/bash

# Graceful agent shutdown

for R in `seq 1 $(lscpu -p=CPU | grep -v "^#" | wc -l)`; do
  sudo docker exec -ti \
  -e VSTS_AGENT_INPUT_AUTH="pat" \
  -e VSTS_AGENT_INPUT_URL="$1" \
  -e VSTS_AGENT_INPUT_TOKEN="$2" \
  -e AGENT_ALLOW_RUNASROOT=1 \
  agent$R \
  ./config.sh remove --unattended \
  && sudo docker stop agent$R \
  && sudo docker rm agent$R
done
