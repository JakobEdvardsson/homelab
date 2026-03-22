#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="${REPO_DIR:-/mnt/user/appdata/homelab}"
BRANCH="${BRANCH:-main}"
BEFORE_SHA="${BEFORE_SHA:-}"
AFTER_SHA="${AFTER_SHA:-}"

log() {
  printf '[deploy] %s\n' "$*"
}

cd "$REPO_DIR"

log "starting on host=$(hostname) repo=$REPO_DIR branch=$BRANCH before=${BEFORE_SHA:-<empty>} after=${AFTER_SHA:-<empty>}"
git config --global --add safe.directory "$REPO_DIR"

log "checking for uncommitted changes"
if ! git diff --quiet || ! git diff --cached --quiet; then
  log "refusing to deploy: repo has local uncommitted changes"
  git status --short
  exit 1
fi

upstream_ref="origin/$BRANCH"
log "fetching latest branch state from $upstream_ref"
git fetch origin "$BRANCH"
log "checking out $BRANCH"
git checkout "$BRANCH"
if ! git merge-base --is-ancestor HEAD "$upstream_ref"; then
  log "local branch diverged from $upstream_ref; resetting deployment checkout to remote branch"
  git reset --hard "$upstream_ref"
fi
log "pulling latest changes"
git pull --ff-only origin "$BRANCH"

STACKS_DIR="$REPO_DIR/docker"
zero_sha='0000000000000000000000000000000000000000'
changed_files=()

log "building changed file list"
if [[ -n "$BEFORE_SHA" && -n "$AFTER_SHA" && "$BEFORE_SHA" != "$zero_sha" ]]; then
  while IFS= read -r line; do
    [[ -n "$line" ]] && changed_files+=("$line")
  done < <(git -C "$REPO_DIR" diff --name-only "$BEFORE_SHA" "$AFTER_SHA")
elif [[ -n "$AFTER_SHA" ]]; then
  while IFS= read -r line; do
    [[ -n "$line" ]] && changed_files+=("$line")
  done < <(git -C "$REPO_DIR" ls-tree -r --name-only "$AFTER_SHA" docker)
else
  log "missing BEFORE_SHA/AFTER_SHA; nothing to do"
  exit 0
fi

if [[ ${#changed_files[@]} -eq 0 ]]; then
  log "no changed files"
  exit 0
fi

log "changed files:\n$(printf '  - %s\n' "${changed_files[@]}")"

folderview_changed=false
for path in "${changed_files[@]}"; do
  if [[ "$path" == "folderview/docker.json" ]]; then
    folderview_changed=true
    break
  fi
done

declare -A stack_set=()
for path in "${changed_files[@]}"; do
  if [[ "$path" =~ ^docker/([^/]+)/ ]]; then
    stack="${BASH_REMATCH[1]}"
    if [[ -f "$REPO_DIR/docker/$stack/docker-compose.yml" ]]; then
      stack_set["$stack"]=1
    fi
  fi
done

if [[ ${#stack_set[@]} -eq 0 ]]; then
  log "no stack changes detected"
  if [[ "$folderview_changed" == "true" ]]; then
    src="$REPO_DIR/folderview/docker.json"
    dst="/boot/config/plugins/folder.view3/docker.json"
    if [[ -f "$src" ]]; then
      log "syncing folderview config to $dst"
      cp "$src" "$dst"
    fi
  fi
  exit 0
fi

is_true() {
  local raw
  raw="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | xargs)"
  [[ "$raw" == "true" ]]
}

stack_should_autostart() {
  local stack="$1"
  local file="$REPO_DIR/docker/$stack/autostart"
  [[ -f "$file" ]] && is_true "$(cat "$file")"
}

stack_is_running() {
  local stack="$1"
  (cd "$STACKS_DIR/$stack" && docker compose ps --status running -q 2>/dev/null | grep -q .)
}

ensure_stack_env() {
  local stack="$1"
  local stack_dir="$STACKS_DIR/$stack"
  ln -sf ../.env "$stack_dir/.env"
}

mapfile -t stacks < <(printf '%s\n' "${!stack_set[@]}" | sort)
log "changed stacks: ${stacks[*]}"

for stack in "${stacks[@]}"; do
  autostart=false
  running=false
  if stack_should_autostart "$stack"; then
    autostart=true
  fi
  if stack_is_running "$stack"; then
    running=true
  fi

  if [[ "$autostart" != "true" && "$running" != "true" ]]; then
    log "skipping $stack (autostart=false and not running)"
    continue
  fi

  log "reconciling $stack (autostart=$autostart running=$running)"
  ensure_stack_env "$stack"
  (
    cd "$STACKS_DIR/$stack"
    log "$stack: docker compose --ansi never --profile '*' pull --quiet"
    docker compose --ansi never --profile '*' pull --quiet || true
    log "$stack: docker compose --ansi never up -d"
    docker compose --ansi never up -d
    log "$stack: docker compose ps"
    docker compose ps --format json || docker compose ps
  )
done

if [[ "$folderview_changed" == "true" ]]; then
  src="$REPO_DIR/folderview/docker.json"
  dst="/boot/config/plugins/folder.view3/docker.json"
  if [[ -f "$src" ]]; then
    log "syncing folderview config to $dst"
    cp "$src" "$dst"
  fi
fi

log "complete"
