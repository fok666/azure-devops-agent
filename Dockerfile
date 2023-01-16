FROM ubuntu:20.04
# To make it easier for build and release pipelines to run apt-get,
# configure apt to not require confirmation (assume the -y argument by default)
ENV DEBIAN_FRONTEND=noninteractive
RUN echo "APT::Get::Assume-Yes \"true\";" > /etc/apt/apt.conf.d/90assumeyes

# Install Docker-in-Docker
RUN apt-get update && apt-get install -y --no-install-recommends \
  apt-transport-https \
  software-properties-common \
  ca-certificates \
  curl \
  zip \
  unzip \
  jq \
  git \
  iputils-ping \
  libcurl4 \
  libicu66 \
  libunwind8 \
  libxcb1 \
  libnss3 \
  netcat \
  wget \
  libssl1.0 \
  docker.io \
  awscli \
&& apt clean

# Install latest Azure CLI
RUN curl -LsS https://aka.ms/InstallAzureCLIDeb | bash \
&& apt clean \
&& az config set extension.use_dynamic_install=yes_without_prompt \
&& az extension add --name azure-devops

# Install latest PowerShell
RUN wget -q https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb \
&& dpkg -i packages-microsoft-prod.deb \
&& apt-get update \
&& add-apt-repository universe \
&& apt-get install -y powershell \
&& apt clean

# Install Kubectl - https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/
RUN curl -sLO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
    && rm -f kubectl

# Install YQ - https://github.com/mikefarah/yq
RUN curl -sLO "https://github.com/mikefarah/yq/releases/download/v$(curl -sI https://github.com/mikefarah/yq/releases/latest | grep '^location:' | grep -Eo '[0-9]+[.][0-9]+[.][0-9]+')/yq_linux_amd64" \
    && install -o root -g root -m 0755 yq_linux_amd64 /usr/local/bin/yq \
    && rm -f yq_linux_amd64

# Install Terraform
RUN wget -qO - terraform.gpg https://apt.releases.hashicorp.com/gpg |  gpg --dearmor -o /usr/share/keyrings/terraform-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/terraform-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/terraform.list \
    && apt update \
    && apt install -y terraform \
    && apt clean

# Install latest Azure Powershell Modules
RUN pwsh -Command "Install-Module -Name 'Az' -Scope CurrentUser -Repository PSGallery -Force"

# Install Azure DevOps Agent
ARG TARGETARCH=amd64
ARG AGENT_VERSION=2.214.2
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
