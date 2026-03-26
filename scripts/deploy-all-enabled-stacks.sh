#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="${REPO_DIR:-/mnt/user/appdata/homelab}"
BRANCH="${BRANCH:-main}"
STACKS_DIR="$REPO_DIR/docker"

log() {
  printf '[deploy-all] %s\n' "$*"
}

is_true() {
  local raw
  raw="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | xargs)"
  [[ "$raw" == "true" ]]
}

flag_file_value() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    return 1
  fi
  tr -d '\r' < "$path" | xargs
}

flag_file_true() {
  local path="$1"
  local value
  value="$(flag_file_value "$path")" || return 1
  is_true "$value"
}

stack_should_autostart() {
  local stack="$1"
  flag_file_true "$STACKS_DIR/$stack/autostart"
}

stack_is_enabled() {
  local stack="$1"
  flag_file_true "$STACKS_DIR/$stack/enabled"
}

stack_is_running() {
  local stack="$1"
  (cd "$STACKS_DIR/$stack" && docker compose ps --status running -q 2>/dev/null | grep -q .)
}

ensure_stack_env() {
  local stack="$1"
  ln -sf ../.env "$STACKS_DIR/$stack/.env"
}

stack_needs_force_recreate() {
  local stack_dir="$1"
  grep -Eq '^[[:space:]]*network_mode:[[:space:]]*"container:' "$stack_dir/docker-compose.yml"
}

cd "$REPO_DIR"

log "starting on host=$(hostname) repo=$REPO_DIR branch=$BRANCH"
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

if [[ ! -d "$STACKS_DIR" ]]; then
  log "missing stacks directory: $STACKS_DIR"
  exit 1
fi

mapfile -t stacks < <(
  find "$STACKS_DIR" -mindepth 1 -maxdepth 1 -type d \
    -exec test -f '{}/docker-compose.yml' ';' -print \
    | xargs -r -n1 basename \
    | sort
)

if [[ ${#stacks[@]} -eq 0 ]]; then
  log "no stacks found"
  exit 0
fi

log "all stacks: ${stacks[*]}"

for stack in "${stacks[@]}"; do
  autostart=false
  enabled=false
  running=false
  autostart_value="<missing>"
  enabled_value="<missing>"

  if stack_should_autostart "$stack"; then
    autostart=true
  fi
  if value="$(flag_file_value "$STACKS_DIR/$stack/autostart")"; then
    autostart_value="$value"
  fi
  if stack_is_enabled "$stack"; then
    enabled=true
  fi
  if value="$(flag_file_value "$STACKS_DIR/$stack/enabled")"; then
    enabled_value="$value"
  fi
  if stack_is_running "$stack"; then
    running=true
  fi

  if [[ "$autostart" != "true" && "$enabled" != "true" && "$running" != "true" ]]; then
    log "skipping $stack (autostart=$autostart raw_autostart=$autostart_value enabled=$enabled raw_enabled=$enabled_value running=$running)"
    continue
  fi

  log "reconciling $stack (autostart=$autostart raw_autostart=$autostart_value enabled=$enabled raw_enabled=$enabled_value running=$running)"
  ensure_stack_env "$stack"
  (
    cd "$STACKS_DIR/$stack"
    up_args=(-d)
    if stack_needs_force_recreate "$STACKS_DIR/$stack"; then
      up_args+=(--force-recreate)
      log "$stack: forcing recreate because it uses network_mode=container:*"
    fi
    log "$stack: docker compose --ansi never --profile '*' pull --quiet"
    docker compose --ansi never --profile '*' pull --quiet || true
    log "$stack: docker compose --ansi never up ${up_args[*]}"
    docker compose --ansi never up "${up_args[@]}"
    log "$stack: docker compose ps"
    docker compose ps --format json || docker compose ps
  )
done

src="$REPO_DIR/folderview/docker.json"
dst="/boot/config/plugins/folder.view3/docker.json"
if [[ -f "$src" ]]; then
  log "syncing folderview config to $dst"
  cp "$src" "$dst"
fi

log "complete"
