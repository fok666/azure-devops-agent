# azure-devops-agent
Azure Dev Ops Self-Hosted Linux Agent

## Azure Pipelines Agent
https://github.com/Microsoft/azure-pipelines-agent/

## Docker Hub:
https://hub.docker.com/r/fok666/azuredevops

## Reference:
https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/docker?view=azure-devops

## Running

``` bash
# Set the parameters from Azure DevOps:
export ORG_URL="https://dev.azure.com/YOUR_ORG"
export DEVOPS_PAT="xxxxxxxxxxxxxxxxxxxxxxxxxxx"
export AGENT_POOL_NAME="YourLinuxAgentPool"

# Docker install:
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=$(dpkg --print-architecture)] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Docker startup:
sudo systemctl start docker
sudo systemctl enable docker

# Get the agent startup script and make is executable:
sudo wget -q https://raw.githubusercontent.com/fok666/azure-devops-agent/main/run.sh
sudo chmod 0755 *.sh

# Start the agents in privileged mode, one agent for each vCPU, using the parameters above:
sudo ./run.sh fok666/azuredevops:latest $ORG_URL $DEVOPS_PAT $AGENT_POOL_NAME
```
