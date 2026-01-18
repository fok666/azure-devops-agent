#!/bin/bash
set -e

# Azure DevOps Self-Hosted Agent Script
# Reference: https://learn.microsoft.com/en-us/azure/devops/pipelines/agents/docker

AGENT_IMAGE="$1"
AZP_URL="$2"
AZP_TOKEN="$3"
AZP_POOL="${4:-Default}"
AGENT_COUNT="${5}"

USAGE_HELP="Usage: $0 <AGENT_IMAGE> <AZP_URL> <AZP_TOKEN> [AZP_POOL] [AGENT_COUNT]

Parameters:
  AGENT_IMAGE     - Docker image name for Azure DevOps agent
  AZP_URL         - Azure DevOps organization URL
                    Example: https://dev.azure.com/yourorganization
  AZP_TOKEN       - Azure DevOps Personal Access Token (PAT)
                    Create at: User Settings > Personal access tokens
                    Required scopes: Agent Pools (Read & manage)
  AZP_POOL        - Agent pool name (default: 'Default')
                    Create/view at: Organization Settings > Agent pools
  AGENT_COUNT     - Number of agent instances (default: auto-detect from CPU count)

Example:
  $0 azp-agent:4.266.2 https://dev.azure.com/myorg **************** \"MyPool\" 4
"

# Validate required parameters
if [ -z "$AGENT_IMAGE" ]; then
  echo "Error: AGENT_IMAGE is required"
  echo "$USAGE_HELP"
  exit 1
fi

if [ -z "$AZP_URL" ]; then
  echo "Error: AZP_URL is required"
  echo "$USAGE_HELP"
  exit 1
fi

if [ -z "$AZP_TOKEN" ]; then
  echo "Error: AZP_TOKEN is required"
  echo "$USAGE_HELP"
  exit 1
fi

# Validate Azure DevOps URL format
if [[ ! "$AZP_URL" =~ ^https://dev\.azure\.com/[^/]+/?$ ]]; then
  echo "Error: Invalid AZP_URL format. Must be https://dev.azure.com/organization"
  exit 1
fi

# Get total CPU count from the system
CPU_COUNT=$(lscpu -p=CPU | grep -v "^#" | wc -l 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo "2")

# Set agent count (use provided value or default to CPU count)
AGENT_COUNT=${AGENT_COUNT:-$CPU_COUNT}

# Limit the number of vCPU count per agent to 2 when there are more than 1 vCPU available, cap it to 1 vCPU otherwise
MAX_CPU=$((CPU_COUNT > 1 ? 2 : 1))

# Get the Docker socket endpoint from current context
DOCKER_SOCK_ENDPOINT=$(docker context inspect 2>/dev/null | jq -r '.[]|.Endpoints.docker.Host' || echo "unix:///var/run/docker.sock")

# Extract socket path
DOCKER_SOCK_PATH=${DOCKER_SOCK_ENDPOINT#unix://}
DOCKER_SOCK_PATH=${DOCKER_SOCK_PATH:-/var/run/docker.sock}

echo "Starting $AGENT_COUNT Azure DevOps agent(s)..."
echo "Image: $AGENT_IMAGE"
echo "Organization: $AZP_URL"
echo "Agent Pool: $AZP_POOL"
echo "CPUs per agent: $MAX_CPU"
echo ""

# Launch agents
for R in $(seq 1 "$AGENT_COUNT"); do
  AGENT_NAME="azp-agent-$(hostname)-$R"
  WORK_DIR="/mnt/azp-agent${R}/_work"
  CONTAINER_NAME="azp-agent-$R"
  
  # Create work directory
  sudo mkdir -p "$WORK_DIR"
  
  echo "Starting agent $R/$AGENT_COUNT: $AGENT_NAME"
  
  # Check if container already exists
  if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "  Removing existing container: $CONTAINER_NAME"
    docker rm -f "$CONTAINER_NAME" > /dev/null 2>&1 || true
  fi
  
  # Run Azure DevOps agent container
  # SECURITY NOTE: --privileged mode grants extended privileges to the container.
  # This is required for Docker-in-Docker but poses security risks.
  # Consider using rootless Docker or Docker socket mounting as alternatives.
  # If --privileged is not needed for your use case, remove this flag.
  docker run \
    --privileged \
    --tty \
    --detach \
    --cpus="${MAX_CPU}" \
    -e AZP_URL="$AZP_URL" \
    -e AZP_TOKEN="$AZP_TOKEN" \
    -e AZP_POOL="$AZP_POOL" \
    -e AZP_AGENT_NAME="$AGENT_NAME" \
    -e AZP_WORK="/_work" \
    -v "$DOCKER_SOCK_PATH":/var/run/docker.sock \
    -v "$WORK_DIR":/_work \
    --restart unless-stopped \
    --name "$CONTAINER_NAME" \
    "$AGENT_IMAGE"
  
  echo "  Container $CONTAINER_NAME started successfully"
done

echo ""
echo "All agents started successfully!"
echo ""
echo "To check agent status:"
echo "  docker ps --filter name=azp-agent"
echo ""
echo "To view agent logs:"
echo "  docker logs -f azp-agent-1"
echo ""
echo "To verify agent registration in Azure DevOps:"
echo "  Go to Organization Settings > Agent pools > $AZP_POOL"
echo ""
echo "To stop all agents:"
echo "  ./stop.sh"
