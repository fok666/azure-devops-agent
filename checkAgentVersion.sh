#!/bin/bash

# Check latest agent release version
curl -sS "https://github.com/Microsoft/azure-pipelines-agent/releases.atom" | grep "<id>tag" | head -2 | tail -1 | grep -Eo "[0-9]+[.][0-9]+[.][0-9]+"
