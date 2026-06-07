#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="${REPO_DIR:-/mnt/user/appdata/homelab}"
BRANCH="${BRANCH:-main}"
BEFORE_SHA="${BEFORE_SHA:-}"
AFTER_SHA="${AFTER_SHA:-}"
STACKS_DIR="$REPO_DIR/docker"
ENV_ARCHIVE="${ENV_ARCHIVE:-$REPO_DIR/.deploy-env.tgz}"
ENV_STAGE_DIR=""

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
  # A change to common secrets or the sops config affects every stack.
  # Per-stack secret files (secrets/<stack>.yaml) are handled in the loop below.
  if [[ "$path" == ".sops.yaml" || "$path" == "secrets/common.yaml" ]]; then
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
    stack=""
    if [[ "$path" =~ ^docker/([^/]+)/ ]]; then
      stack="${BASH_REMATCH[1]}"
    elif [[ "$path" =~ ^secrets/([^/]+)\.yaml$ ]]; then
      stack="${BASH_REMATCH[1]}"
    fi
    if [[ -n "$stack" && -f "$REPO_DIR/docker/$stack/docker-compose.yml" ]]; then
      stack_set["$stack"]=1
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
