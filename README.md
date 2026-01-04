# azure-devops-agent

Azure DevOps Self-Hosted Linux Agent. General purpose Docker image with pre-installed tools.

[![CodeQL](https://github.com/fok666/azure-devops-agent/actions/workflows/github-code-scanning/codeql/badge.svg)](https://github.com/fok666/azure-devops-agent/actions/workflows/github-code-scanning/codeql) [![Dependabot Updates](https://github.com/fok666/azure-devops-agent/actions/workflows/dependabot/dependabot-updates/badge.svg)](https://github.com/fok666/azure-devops-agent/actions/workflows/dependabot/dependabot-updates) [![Docker Image CI](https://github.com/fok666/azure-devops-agent/actions/workflows/docker-image.yml/badge.svg)](https://github.com/fok666/azure-devops-agent/actions/workflows/docker-image.yml)

Goals:

- Run anywhere
- Auto scalable
- Self-configurable
- Feature rich
- Customizable


## Features

Bundled tools:

- [Docker-in-Docker](https://learn.microsoft.com/azure/devops/pipelines/agents/docker)
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli-linux) (azure-devops & resource-graph extensions)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- [Powershell](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-linux)
- [Azure Powershell modules](https://learn.microsoft.com/powershell/azure/install-azps-linux)
- [AWS Tools for PowerShell (bundle)](https://aws.amazon.com/powershell/)
- [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)
- [Kubelogin](https://github.com/Azure/kubelogin/releases)
- [Kustomize](https://kubectl.docs.kubernetes.io/installation/kustomize/)
- [Helm](https://helm.sh/docs/intro/install/)
- [JQ](https://github.com/jqlang/jq) & [YQ](https://github.com/mikefarah/yq)
- [Terraform](https://developer.hashicorp.com/terraform/install)
- [OpenTofu](https://opentofu.org/docs/intro/install/)
- [Terraspace](https://terraspace.cloud/docs/install/)


## Build configuration

Supported `--build-arg` variables are listed below to easily configure the agent image based on your requirements. All options default to 1 (enabled).

- `ADD_DOCKER`: Installs Docker for Docker-in-Docker support
- `ADD_AZURE_CLI`: Installs Azure-CLI
- `ADD_AWS_CLI`:  Installs AWS-CLI
- `ADD_POWERSHELL`: Installs Powershell
- `ADD_AZURE_PWSH_CLI`: Installs Azure Powershell modules, if Powershell is also enabled
- `ADD_AWS_PWSH_CLI`: Installs AWS Powershell modules, if Powershell is also enabled
- `ADD_KUBECTL`: Installs Kubernetes `kubectl`
- `ADD_KUBELOGIN`: Installs Kubernetes `kubelogin` for Azure authentication
- `ADD_KUSTOMIZE`: Installs Kubernetes `kustomize` tool
- `ADD_HELM`: Installs `Helm` tool
- `ADD_JQ`: Installs `jq` tool
- `ADD_YQ`: Installs `yq` tool
- `ADD_TERRAFORM`: Installs `terraform` tool
- `ADD_OPENTOFU`: Installs `opentofu` tool
- `ADD_TERRASPACE`: Installs `terraspace` tool
- `ADD_SUDO`: Installs and enables `sudo` for the agent user group

# References


### Azure Pipelines Agent
https://github.com/Microsoft/azure-pipelines-agent/


### Docker Hub images
https://hub.docker.com/r/fok666/azuredevops


### Azure DevOps Self-Hosted Reference
https://docs.microsoft.com/azure/devops/pipelines/agents/docker?view=azure-devops


## Running

This agent is intended to run on virtual machines.  
To be able to build Docker images with the agent, docker must be installed on the host and allowed to run in [privileged](https://docs.docker.com/engine/reference/run/#runtime-privilege-and-linux-capabilities) mode.  


``` bash
# Docker install:
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=$(dpkg --print-architecture)] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Docker startup:
sudo systemctl start docker
sudo systemctl enable docker

# Get the agent startup, stop and monitor scripts and make them executable:
sudo curl -sO https://raw.githubusercontent.com/fok666/azure-devops-agent/main/run.sh
sudo curl -sO https://raw.githubusercontent.com/fok666/azure-devops-agent/main/monitor.sh
sudo curl -sO https://raw.githubusercontent.com/fok666/azure-devops-agent/main/stop.sh
sudo chmod +x *.sh

# Set the parameters from Azure DevOps:
export ORG_URL="https://dev.azure.com/YOUR_ORG"
export DEVOPS_PAT="xxxxxxxxxxxxxxxxxxxxxxxxxxx"
export AGENT_POOL_NAME="YourLinuxAgentPool"

# Start the agents in privileged mode, one agent for each vCPU, using the parameters above:
sudo ./run.sh fok666/azuredevops:latest $ORG_URL $DEVOPS_PAT $AGENT_POOL_NAME
```


## Azure VMSS support

This project is designed to use Azure Virtual Machine Scale Sets, but can be used with different settings.

- `monitor.sh`: Add this script to the host's cron to monitor VMSS shutdown events. Requires `curl` and `jq`.
- `stop.sh`: Add this script to `/opt/stop.sh` to enable graceful Agent shutdown. Requires SUDO.


# TO DO

- Add Google Compute Cloud (GCP) CLI bundles
- Add GKE auth support
