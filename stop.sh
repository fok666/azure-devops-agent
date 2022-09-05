#!/bin/bash

# Get URL and PAT from running instance:
eval $(sudo docker inspect agent1 | jq -r '. [] | . | .Config.Env[]' | grep "AZP_TOKEN\|AZP_URL")

# Graceful agent shutdown

for R in `seq 1 $(lscpu -p=CPU | grep -v "^#" | wc -l)`; do
  sudo docker exec -ti \
    -e VSTS_AGENT_INPUT_AUTH="pat" \
    -e VSTS_AGENT_INPUT_URL="$AZP_URL" \
    -e VSTS_AGENT_INPUT_TOKEN="$AZP_TOKEN" \
    -e AGENT_ALLOW_RUNASROOT=1 \
    agent$R \
    ./config.sh remove --unattended \
  && sudo docker stop agent$R \
  && sudo docker rm agent$R
done

exit 0
