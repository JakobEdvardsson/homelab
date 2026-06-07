#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="${REPO_DIR:-/mnt/user/appdata/homelab}"
BRANCH="${BRANCH:-main}"
STACKS_DIR="$REPO_DIR/docker"
ENV_ARCHIVE="${ENV_ARCHIVE:-$REPO_DIR/.deploy-env.tgz}"
ENV_STAGE_DIR=""

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

# Per-stack envs are decrypted in CI and shipped as a tar of flat <stack>.env
# files (each = common.env + the stack's own secrets). Extract once, then
# install the right one into each stack dir. Stacks without their own secrets
# fall back to common.env.
ensure_stack_env() {
  local stack="$1"
  if [[ -z "$ENV_STAGE_DIR" ]]; then
    if [[ ! -f "$ENV_ARCHIVE" ]]; then
      log "missing env archive: $ENV_ARCHIVE"
      exit 1
    fi
    ENV_STAGE_DIR="$(mktemp -d)"
    tar -xzf "$ENV_ARCHIVE" -C "$ENV_STAGE_DIR"
    # Remove the legacy shared env (plaintext copy of every secret) left by
    # older deploys; secrets are now per-stack.
    rm -f "$STACKS_DIR/.env"
  fi
  local src="$ENV_STAGE_DIR/$stack.env"
  [[ -f "$src" ]] || src="$ENV_STAGE_DIR/common.env"
  if [[ ! -f "$src" ]]; then
    log "missing env for stack $stack (no $stack.env or common.env in archive)"
    exit 1
  fi
  # Drop any pre-existing file/symlink first: older deploys symlinked .env to
  # ../.env, and install would otherwise write through that symlink.
  rm -f "$STACKS_DIR/$stack/.env"
  install -m 600 "$src" "$STACKS_DIR/$stack/.env"
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
