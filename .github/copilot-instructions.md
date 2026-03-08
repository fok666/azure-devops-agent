# GitHub Copilot Instructions for Azure DevOps Self-Hosted Agent

## Project Overview

This project builds and publishes multi-profile Docker images for running **Azure DevOps self-hosted pipeline agents** on Linux (Ubuntu 24.04). Images are multi-architecture (amd64/arm64), built using a multi-stage Dockerfile optimized for maximum layer reusability, and published to both Docker Hub and GitHub Container Registry (GHCR).

**Key files:**

| File | Purpose |
|------|---------|
| `Dockerfile` | Multi-stage build definition (all profiles) |
| `run.sh` | Launches N agent containers on a VM |
| `start.sh` | Entrypoint executed inside the container |
| `stop.sh` | Graceful agent deregistration |
| `test-tools.sh` | Smoke-tests installed tools at build time |
| `vmss_monitor.sh` | Handles Azure VMSS termination events |
| `ec2_monitor.sh` | Handles AWS EC2 spot-interruption notices |
| `checkAgentVersion.sh` | Fetches latest Azure Pipelines Agent release version |
| `ARCHITECTURE.md` | Deep-dive into multi-stage build design |

## Repository Structure

```
.
├── Dockerfile              # Multi-stage build (base → common → … → profiles)
├── run.sh                  # VM-side launcher
├── start.sh                # Container entrypoint
├── stop.sh                 # Graceful shutdown / deregistration
├── test-tools.sh           # Tool smoke tests
├── vmss_monitor.sh         # Azure VMSS termination handler
├── ec2_monitor.sh          # AWS EC2 spot termination handler
├── checkAgentVersion.sh    # Latest version helper
├── ARCHITECTURE.md         # Build architecture documentation
└── .github/
    ├── copilot-instructions.md
    ├── dependabot.yml
    └── workflows/
        ├── docker-image.yml        # Main CI: build, test, push multi-arch images
        ├── docker-hub-release.yml  # Publish release tags to Docker Hub
        ├── docker-automate.yaml    # Port.io-triggered automation workflow
        └── version-check.yml      # Scheduled upstream version checker
```

## Docker Image Profiles

| Profile | Size | Description | Included Tools |
|---------|------|-------------|----------------|
| **minimal** | ~550 MB | Essential tools only | Azure DevOps Agent, sudo |
| **k8s** | ~850 MB | Kubernetes-focused | + Docker, kubectl, kubelogin, kustomize, Helm, jq, yq |
| **iac** | ~1.75 GB | Infrastructure as Code (bash) | + Docker, Azure CLI (+ devops & resource-graph extensions), AWS CLI, Terraform, OpenTofu, Terraspace, jq, yq |
| **iac-pwsh** | ~2.25 GB | IaC with PowerShell | + PowerShell (Az + AWS modules) |
| **full** | ~2.45 GB | All tools | k8s + iac-pwsh combined |

### Multi-Stage Build Layer Hierarchy

```
base (Ubuntu 24.04 + Azure DevOps Agent)
└── common (+ sudo)
    ├── minimal  ← PROFILE
    └── docker-tools (+ Docker, jq, yq)
        ├── k8s-tools (+ kubectl, kubelogin, kustomize, Helm)
        │   └── k8s  ← PROFILE
        └── cloud-tools (+ Azure CLI, AWS CLI)
            └── iac-tools (+ Terraform, OpenTofu, Terraspace)
                ├── iac  ← PROFILE
                └── pwsh-tools (+ PowerShell + Az/AWS modules)
                    ├── iac-pwsh  ← PROFILE
                    └── full-tools (+ k8s tools copied)
                        └── full  ← PROFILE
```

The Azure Pipelines agent binary is extracted from the Microsoft download CDN and `installdependencies.sh` is called during the `base` stage — do not move this to a later stage.

## Common Commands

```bash
# Build a specific profile locally
docker build --target minimal -t azure-devops-agent:minimal .
docker build --target full   -t azure-devops-agent:full .

# Multi-arch build (requires buildx)
docker buildx build --platform linux/amd64,linux/arm64 --target full \
  -t ghcr.io/fok666/azure-devops-agent:latest-full .

# Run agents on a VM (auto-detects CPU count)
./run.sh <IMAGE> <AZP_URL> <AZP_TOKEN> [POOL] [COUNT]
# Example:
./run.sh azure-devops-agent:4.266.2 https://dev.azure.com/myorg myPAT "Default" 4

# Check latest upstream agent version
./checkAgentVersion.sh

# Smoke-test tools inside a running container
docker exec <CONTAINER> /test-tools.sh
```

## Architecture Patterns & Coding Standards

### Dockerfile Guidelines

- **Stage naming**: use lowercase kebab-case (`base`, `common`, `docker-tools`, etc.)
- **Final profile stages** are named after the profile: `minimal`, `k8s`, `iac`, `iac-pwsh`, `full`
- **COPY --from**: use named stages, never numeric indices
- **ARG scope**: re-declare `ARG TARGETARCH` in any stage that references it; Azure Pipelines agent uses `x64` for amd64
- **Version pinning**: all tool versions are controlled via `ARG` at the top of the `base` stage
- **Cleanup**: always end `RUN` blocks that call `apt-get` with `&& apt clean && rm -rf /var/lib/apt/lists/*`
- **WORKDIR**: the agent is installed to `/azp`; do not change — `start.sh` relies on it
- **Azure CLI**: always install the `azure-devops` and `resource-graph` extensions after Azure CLI installation

```dockerfile
# Pattern for mapping TARGETARCH to agent arch convention
RUN AGENT_ARCH=$([ "${TARGETARCH}" = "amd64" ] && echo "x64" || echo "arm64") && \
    curl -LsS "https://download.agent.dev.azure.com/agent/${AGENT_VERSION}/vsts-agent-linux-${AGENT_ARCH}-${AGENT_VERSION}.tar.gz" | tar -xz \
    && ./bin/installdependencies.sh
```

### Shell Script Guidelines

- Always start with `#!/bin/bash` and `set -e`
- Validate all required parameters before using them; print `USAGE_HELP` and `exit 1` on failure
- AZP URL validation: must match `^https://dev\.azure\.com/[^/]+/?$`
- Auto-detect CPU count; cap CPUs per agent at 2 (`MAX_CPU=$((CPU_COUNT > 1 ? 2 : 1))`)
- Use `jq` to safely construct JSON payloads — never string-concatenate JSON
- Agent PAT is short-lived after first use for registration; `stop.sh` handles deregistration

### Workflow Guidelines

- Use specific action versions (`@v6`, `@v4`, etc.) — never `@latest`
- Set `timeout-minutes` on all jobs
- Use `>> $GITHUB_OUTPUT` (not `set-output`) for step outputs
- Matrix strategy for profiles and platforms:
  - **PR builds**: `full` profile only, both `linux/amd64` + `linux/arm64`
  - **Push to main**: all profiles, `linux/amd64` only
- Always use `actions/checkout@v6` as the first step

```yaml
# Correct output pattern
- name: Extract version
  id: ver
  run: echo "version=4.266.2" >> $GITHUB_OUTPUT

- run: echo "Version is ${{ steps.ver.outputs.version }}"
```

## Test-Tools Smoke Test Pattern

`test-tools.sh` uses `command -v <tool>` guards so it is safe to run in any profile:

```bash
if command -v az &> /dev/null; then
    echo "Testing Azure CLI..."
    az version --output tsv | head -n1
    echo "Azure CLI: OK"
fi
```

When adding a new tool, add a corresponding guarded test block to `test-tools.sh`.

## Versioning & Release

- Agent version is controlled by `ARG AGENT_VERSION=<version>` in the Dockerfile
- To release a new version: update `AGENT_VERSION` in the Dockerfile **or** pass it as a workflow input/repository variable
- Image tags follow the pattern: `latest-<profile>`, `<version>-<profile>`, `<version>-<profile>-<date>`
- `checkAgentVersion.sh` fetches the latest version from the GitHub Releases redirect for `microsoft/azure-pipelines-agent`

## VMSS / EC2 Termination Handling

- `vmss_monitor.sh`: polls Azure IMDS (`169.254.169.254`) for `Terminate` scheduled events; calls `stop.sh` and acknowledges the event using `jq`-built JSON
- `ec2_monitor.sh`: polls AWS IMDS for spot-interruption notices; calls `stop.sh`
- `stop.sh`: removes the agent from the Azure DevOps agent pool and stops the container gracefully
- These scripts are designed to run from a cron job or systemd timer on the host VM

## Common Pitfalls

- **TARGETARCH vs agent arch**: Azure Pipelines agent archives use `x64` (not `amd64`) — always map with `$([ "${TARGETARCH}" = "amd64" ] && echo "x64" || echo "arm64")`
- **AZP URL format**: must be exactly `https://dev.azure.com/<org>` — trailing slashes and FQDN variants will fail validation
- **PAT scopes**: the PAT used for `run.sh` needs at minimum **Agent Pools (Read & manage)** scope
- **Layer order**: put the heaviest stable layers earliest (AWS CLI, Azure CLI before Terraform)
- **Do not add tools to `base`**: the base stage is 100% shared; tool installation belongs in dedicated intermediate stages
- **Do not hardcode credentials**: use `${{ secrets.* }}` in workflows; environment variables in shell scripts
- **GHCR visibility**: ensure the package is set to public in GitHub settings
- **Port.io workflow** (`docker-automate.yaml`): requires `PORT_CLIENT_ID` and `PORT_CLIENT_SECRET` repository secrets

## Adding a New Tool

1. Decide which existing stage to build on (usually `docker-tools` or `cloud-tools`)
2. Create a new intermediate stage (e.g., `my-tool`)
3. Rebuild dependent profile stages referencing the new stage as their base
4. Add a guarded test block in `test-tools.sh`
5. Update profile size estimates in `README.md` and `ARCHITECTURE.md`
6. Update the workflow matrix in `docker-image.yml` to include/test the new tool flag

## Security Considerations

- Never open SSH in Docker images — access via `docker exec` or Azure Bastion
- `NOPASSWD:ALL` sudo is a conscious trade-off for CI/CD automation; document any changes
- Use `--no-install-recommends` in all `apt-get install` calls to minimize attack surface
- Prefer downloading binaries from official Microsoft/AWS/HashiCorp sources over third-party PPAs
- All tokens must come from environment variables or GitHub Secrets — never bake them into images
- Rotate Azure DevOps PATs regularly; short-lived tokens are recommended

## References

- [Azure Pipelines Agent](https://github.com/microsoft/azure-pipelines-agent)
- [Azure DevOps Self-Hosted Agents (Docker)](https://learn.microsoft.com/azure/devops/pipelines/agents/docker)
- [Docker Hub: fok666/azuredevops](https://hub.docker.com/r/fok666/azuredevops)
- [GitHub Container Registry](https://ghcr.io/fok666/azure-devops-agent)
- [Azure VMSS Scheduled Events](https://learn.microsoft.com/en-us/azure/virtual-machines/linux/scheduled-events)
- [AWS EC2 Spot Interruption Notices](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/spot-interruptions.html)
