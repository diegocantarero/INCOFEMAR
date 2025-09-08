#!/usr/bin/env bash
case "$1" in
  *sername* ) echo "x-access-token" ;;
  *assword* ) echo "${GH_PAT:-}" ;;
  * ) echo "${GH_PAT:-}" ;;
esac
