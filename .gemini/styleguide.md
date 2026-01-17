# Shell & Docker Style Guide (Azure DevOps Agent)

## Shell Scripting (Bash)
- Follow the **Google Shell Style Guide**.
- Start scripts with a shebang: `#!/bin/bash`.
- Use `set -e` to ensure scripts fail on errors.
- Capitalize environment variables (e.g., `AZP_URL`, `AZP_TOKEN`).
- Quote variables to prevent word splitting issues: `"${VAR}"`.
- Use functions to modularize code.
- Add comments explaining complex logic or Azure-specific configurations.

## Docker
- Use explicit tags for base images (avoid `:latest` for production).
- Combine `RUN` commands where possible to reduce layer count.
- Clean up `apt-get` lists and temporary files in the same `RUN` instruction.
- Run the agent as a non-root user if possible, though Azure Agents often require root for Docker-in-Docker.
- Ensure `start.sh` handles signals (SIGINT/SIGTERM) correctly to deregister the agent gracefully.

## Azure Deviops Specifics
- Ensure the agent capabilities are clearly defined or discovered.
- Verify required tools (git, curl, jq) are installed in the Dockerfile.
