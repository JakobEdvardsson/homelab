#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="${REPO_DIR:-/mnt/user/appdata/homelab}"
BRANCH="${BRANCH:-main}"
STACKS_DIR="$REPO_DIR/docker"
ENV_FILE="$STACKS_DIR/.env"
SELECTED_STACKS="${SELECTED_STACKS:-}"

log() {
  printf '[deploy-selected] %s\n' "$*"
}

ensure_stack_env() {
  local stack="$1"
  if [[ ! -f "$ENV_FILE" ]]; then
    log "missing shared env file: $ENV_FILE"
    exit 1
  fi
  ln -sf ../.env "$STACKS_DIR/$stack/.env"
}

stack_needs_force_recreate() {
  local stack_dir="$1"
  grep -Eq '^[[:space:]]*network_mode:[[:space:]]*"container:' "$stack_dir/docker-compose.yml"
}

cd "$REPO_DIR"

log "starting on host=$(hostname) repo=$REPO_DIR branch=$BRANCH selected=${SELECTED_STACKS:-<empty>}"
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

if [[ -z "$(printf '%s' "$SELECTED_STACKS" | tr -d '[:space:],')" ]]; then
  log "no stacks were provided"
  exit 1
fi

declare -A requested=()
while IFS= read -r stack; do
  [[ -n "$stack" ]] || continue
  requested["$stack"]=1
done < <(printf '%s\n' "$SELECTED_STACKS" | tr ', ' '\n\n' | sed '/^$/d' | sort -u)

declare -A available=()
while IFS= read -r stack; do
  [[ -n "$stack" ]] || continue
  available["$stack"]=1
done < <(find "$STACKS_DIR" -mindepth 1 -maxdepth 1 -type d -exec test -f '{}/docker-compose.yml' ';' -print | xargs -r -n1 basename | sort)

missing=()
for stack in "${!requested[@]}"; do
  if [[ -z "${available[$stack]:-}" ]]; then
    missing+=("$stack")
  fi
done

if [[ ${#missing[@]} -gt 0 ]]; then
  log "unknown stacks: ${missing[*]}"
  log "available stacks: $(printf '%s ' "${!available[@]}" | xargs)"
  exit 1
fi

mapfile -t stacks < <(printf '%s\n' "${!requested[@]}" | sort)
log "selected stacks: ${stacks[*]}"

for stack in "${stacks[@]}"; do
  log "reconciling $stack"
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
