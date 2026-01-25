#!/usr/bin/env bash
set -euo pipefail

VAULT_FILE=${VAULT_FILE:-group_vars/runner-hosts/vault.yml}

usage() {
  echo "Usage: $0 [--repos repo1,repo2 | --repos repo1 repo2 ...]" >&2
}

repos_override=()
if [ $# -gt 0 ]; then
  case "$1" in
    --repos)
      shift
      if [ $# -eq 0 ]; then
        usage
        exit 1
      fi
      if [[ "$1" == *","* ]]; then
        IFS=',' read -r -a repos_override <<< "$1"
      else
        repos_override=("$@")
      fi
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 1
      ;;
  esac
fi

TOKEN=${GITHUB_TOKEN:-$(sed -n 's/^github_token: "\(.*\)"/\1/p' "$VAULT_FILE")}
USER=${GITHUB_USERNAME:-$(sed -n 's/^github_username: "\(.*\)"/\1/p' "$VAULT_FILE")}

if [ -z "$TOKEN" ] || [ -z "$USER" ]; then
  echo "Missing github_token or github_username (set env or update $VAULT_FILE)." >&2
  exit 1
fi

api_get() {
  curl -sS -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github+json" "$1"
}

repos=()
if [ ${#repos_override[@]} -gt 0 ]; then
  for r in "${repos_override[@]}"; do
    if [[ "$r" == */* ]]; then
      repos+=("$r")
    else
      repos+=("$USER/$r")
    fi
  done
else
  page=1
  per=100
  while :; do
    resp=$(api_get "https://api.github.com/user/repos?page=$page&per_page=$per&type=owner")
    names=$(echo "$resp" | jq -r '.[].full_name')
    if [ -z "$names" ]; then
      break
    fi
    while IFS= read -r name; do
      [ -n "$name" ] && repos+=("$name")
    done <<< "$names"
    page=$((page+1))
  done
fi

printf "%-45s %6s %6s %7s\n" "repo" "total" "online" "offline"
printf "%-45s %6s %6s %7s\n" "----" "-----" "------" "-------"

t_total=0
online_total=0
offline_total=0

for repo in "${repos[@]}"; do
  resp=$(api_get "https://api.github.com/repos/$repo/actions/runners")
  if ! echo "$resp" | jq -e '.runners' > /dev/null 2>&1; then
    msg=$(echo "$resp" | jq -r '.message // empty')
    printf "%-45s %6s %6s %7s\n" "$repo" "-" "-" "-"
    [ -n "$msg" ] && echo "  warning: $msg" >&2
    continue
  fi
  total=$(echo "$resp" | jq -r '.runners | length')
  online=$(echo "$resp" | jq -r '[.runners[] | select(.status=="online")] | length')
  offline=$(echo "$resp" | jq -r '[.runners[] | select(.status=="offline")] | length')

  t_total=$((t_total+total))
  online_total=$((online_total+online))
  offline_total=$((offline_total+offline))

  printf "%-45s %6s %6s %7s\n" "$repo" "$total" "$online" "$offline"
  # avoid hammering API
  sleep 0.2

done

printf "%-45s %6s %6s %7s\n" "TOTAL" "$t_total" "$online_total" "$offline_total"
