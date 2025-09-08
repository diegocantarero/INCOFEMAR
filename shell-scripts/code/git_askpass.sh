#!/usr/bin/env bash
case "$1" in
  *sername* ) echo "x-access-token" ;;   # usuario fijo para PAT en GitHub
  *assword* ) echo "${GH_PAT:-}" ;;      # PAT desde entorno
  * ) echo "${GH_PAT:-}" ;;
esac
