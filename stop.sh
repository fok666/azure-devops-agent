#!/bin/bash
set -e

# Azure DevOps Agent Stop Script
# Gracefully stops and removes all Azure DevOps agent containers

echo "Stopping Azure DevOps agents..."
echo ""

# Get list of running agent containers
AGENT_CONTAINERS=$(docker ps --filter "name=azp-agent-" --format "{{.Names}}" | sort)

if [ -z "$AGENT_CONTAINERS" ]; then
  echo "No running Azure DevOps agent containers found."
  exit 0
fi

CONTAINER_COUNT=$(echo "$AGENT_CONTAINERS" | wc -l | tr -d ' ')
echo "Found $CONTAINER_COUNT agent container(s)"
echo ""

# Stop each agent gracefully
for CONTAINER_NAME in $AGENT_CONTAINERS; do
  echo "Stopping $CONTAINER_NAME..."
  
  # Try graceful shutdown first (agent will unregister itself via start.sh cleanup)
  docker stop -t 30 "$CONTAINER_NAME" > /dev/null 2>&1 || true
  
  # Remove the container
  docker rm "$CONTAINER_NAME" > /dev/null 2>&1 || true
  
  echo "  $CONTAINER_NAME stopped and removed"
done

echo ""
echo "All Azure DevOps agents stopped successfully!"
exit 0
