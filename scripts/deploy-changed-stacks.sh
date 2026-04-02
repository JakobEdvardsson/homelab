#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="${REPO_DIR:-/mnt/user/appdata/homelab}"
BRANCH="${BRANCH:-main}"
BEFORE_SHA="${BEFORE_SHA:-}"
AFTER_SHA="${AFTER_SHA:-}"
STACKS_DIR="$REPO_DIR/docker"
ENV_FILE="$STACKS_DIR/.env"

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
shared_env_changed=false
for path in "${changed_files[@]}"; do
  if [[ "$path" == "folderview/docker.json" ]]; then
    folderview_changed=true
  fi
  if [[ "$path" == "secrets.yaml" || "$path" == ".sops.yaml" ]]; then
    shared_env_changed=true
  fi
done

declare -A stack_set=()
if [[ "$shared_env_changed" == "true" ]]; then
  while IFS= read -r stack; do
    [[ -n "$stack" ]] || continue
    stack_set["$stack"]=1
  done < <(
    find "$STACKS_DIR" -mindepth 1 -maxdepth 1 -type d \
      -exec test -f '{}/docker-compose.yml' ';' -print \
      | xargs -r -n1 basename \
      | sort
  )
else
  for path in "${changed_files[@]}"; do
    if [[ "$path" =~ ^docker/([^/]+)/ ]]; then
      stack="${BASH_REMATCH[1]}"
      if [[ -f "$REPO_DIR/docker/$stack/docker-compose.yml" ]]; then
        stack_set["$stack"]=1
      fi
    fi
  done
fi

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

flag_file_value() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    return 1
  fi
  tr -d '\r' < "$path" | xargs
}

stack_should_autostart() {
  local stack="$1"
  local file="$REPO_DIR/docker/$stack/autostart"
  local value
  value="$(flag_file_value "$file")" || return 1
  is_true "$value"
}

stack_is_running() {
  local stack="$1"
  (cd "$STACKS_DIR/$stack" && docker compose ps --status running -q 2>/dev/null | grep -q .)
}

ensure_stack_env() {
  local stack="$1"
  local stack_dir="$STACKS_DIR/$stack"
  if [[ ! -f "$ENV_FILE" ]]; then
    log "missing shared env file: $ENV_FILE"
    exit 1
  fi
  ln -sf ../.env "$stack_dir/.env"
}

stack_needs_force_recreate() {
  local stack_dir="$1"
  grep -Eq '^[[:space:]]*network_mode:[[:space:]]*"container:' "$stack_dir/docker-compose.yml"
}

mapfile -t stacks < <(printf '%s\n' "${!stack_set[@]}" | sort)
if [[ "$shared_env_changed" == "true" ]]; then
  log "shared secrets changed; considering all stacks for reconciliation"
fi
log "changed stacks: ${stacks[*]}"

for stack in "${stacks[@]}"; do
  autostart=false
  running=false
  autostart_value="<missing>"
  if stack_should_autostart "$stack"; then
    autostart=true
  fi
  if value="$(flag_file_value "$REPO_DIR/docker/$stack/autostart")"; then
    autostart_value="$value"
  fi
  if stack_is_running "$stack"; then
    running=true
  fi

  if [[ "$autostart" != "true" && "$running" != "true" ]]; then
    log "skipping $stack (autostart=$autostart raw_autostart=$autostart_value running=$running)"
    continue
  fi

  log "reconciling $stack (autostart=$autostart raw_autostart=$autostart_value running=$running)"
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

if [[ "$folderview_changed" == "true" ]]; then
  src="$REPO_DIR/folderview/docker.json"
  dst="/boot/config/plugins/folder.view3/docker.json"
  if [[ -f "$src" ]]; then
    log "syncing folderview config to $dst"
    cp "$src" "$dst"
  fi
fi

log "complete"
