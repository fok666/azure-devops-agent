FROM ubuntu:latest
# To make it easier for build and release pipelines to run apt-get,
# configure apt to not require confirmation (assume the -y argument by default)
ENV DEBIAN_FRONTEND=noninteractive
RUN echo "APT::Get::Assume-Yes \"true\";" > /etc/apt/apt.conf.d/90assumeyes

# Install Docker-in-Docker
RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  jq \
  git \
  iputils-ping \
  libcurl4 \
  libicu66 \
  libunwind8 \
  netcat \
  libssl1.0 \
  docker.io \
&& rm -rf /var/lib/apt/lists/*

# Install latest Azure CLI
RUN curl -LsS https://aka.ms/InstallAzureCLIDeb | bash \
&& rm -rf /var/lib/apt/lists/*

# Install latest PowerShell
RUN apt-get update \
&& apt-get install -y wget apt-transport-https software-properties-common \
&& wget -q https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb \
&& dpkg -i packages-microsoft-prod.deb \
&& apt-get update \
&& add-apt-repository universe \
&& apt-get install -y powershell

# Install latest Azure Powershell Modules
RUN pwsh -Command "Install-Module -Name 'Az' -Scope CurrentUser -Repository PSGallery -Force"

# Install Azure DevOps Agent
ARG TARGETARCH=amd64
ARG AGENT_VERSION=2.196.0
WORKDIR /azp
RUN if [ "$TARGETARCH" = "amd64" ]; then \
	AZP_AGENTPACKAGE_URL=https://vstsagentpackage.azureedge.net/agent/${AGENT_VERSION}/vsts-agent-linux-x64-${AGENT_VERSION}.tar.gz; \
  else \
	AZP_AGENTPACKAGE_URL=https://vstsagentpackage.azureedge.net/agent/${AGENT_VERSION}/vsts-agent-linux-${TARGETARCH}-${AGENT_VERSION}.tar.gz; \
  fi; \
  curl -LsS "$AZP_AGENTPACKAGE_URL" | tar -xz

# Agent Startup script
COPY ./start.sh .
RUN chmod +x start.sh
ENTRYPOINT [ "./start.sh" ]
