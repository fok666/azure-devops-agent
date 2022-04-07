#!/bin/bash

# Check latest agent release version
curl -sSI "https://github.com/microsoft/azure-pipelines-agent/releases/latest" | grep "^location:" | grep -Eo "[0-9]+[.][0-9]+[.][0-9]+"
