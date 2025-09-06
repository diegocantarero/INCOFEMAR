#!/usr/bin/env bash
# Non-interactive askpass using GH_PAT env var
prompt="$1"
if [[ "$prompt" == *"Username"* ]]; then
  # For GitHub HTTPS with PAT, username can be anything, commonly 'x-access-token'
  echo "x-access-token"
elif [[ "$prompt" == *"Password"* ]]; then
  if [[ -z "$GH_PAT" ]]; then
    exit 1
  fi
  echo "$GH_PAT"
else
  echo ""
fi

