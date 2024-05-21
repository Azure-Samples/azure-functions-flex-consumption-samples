#!/bin/bash

output=$(azd env get-values)

while IFS= read -r line; do
  name=$(echo $line | cut -d'=' -f1)
  value=$(echo $line | cut -d'=' -f2 | sed 's/^"\|"$//g')
  export $name=$value
done <<<$output

echo "Environment variables set."

commands=("az" "func")

for cmd in "${commands[@]}"; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: $cmd command is not available, check pre-requisites in README.md"
    exit 1
  fi
done

func azure functionapp publish $AZURE_FUNCTION_NAME --python

echo "Deployed successfully."
