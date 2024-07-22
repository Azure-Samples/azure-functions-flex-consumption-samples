# Scripts for Flex Consumption

## Overview

These scripts are no longer required using Azure Developer CLI 1.9.5 or higher.  That said this is useful working script if ever needed to override the `azd deploy` step, or for general scripting needs.

## Running scripts

These scripts can be called standalone from PowerShell or Bash command lines so long as the environment variables are set.

To call from AZD add the following `hooks` section to your `azure.yaml` file instead of having a services section. 

```yaml
# yaml-language-server: $schema=https://raw.githubusercontent.com/Azure/azure-dev/main/schemas/v1.0/azure.yaml.json

name: my-template
metadata:
  template: my-template@0.0.4-beta
hooks:
    postprovision:
      windows:
        shell: pwsh
        run: cd ./src;../scripts/deploy.ps1
        interactive: true
        continueOnError: false
      posix:
        shell: sh
        run: cd ./src;../scripts/deploy.sh
        interactive: true
        continueOnError: false
```
