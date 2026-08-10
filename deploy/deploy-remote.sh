#!/bin/sh
set -eu

IMAGE_REPOSITORY='ghcr.io/ymngkhtd/dawn-router'
IMAGE_TAG=''
SERVER=''
DEPLOY_PATH='/opt/dawn-router'
SSH_PORT='22'
SSH_KEY="$HOME/.ssh/dawn-router-deploy"
SKIP_UPLOAD='0'

usage() {
  cat <<'EOF'
Usage:
  deploy-remote.sh --image-tag TAG --server SERVER [options]

Required:
  -t, --image-tag TAG       Immutable image tag: sha-<40 lowercase hex> or v...
  -s, --server SERVER       SSH destination, for example deploy@example.com

Options:
  -d, --deploy-path PATH    Remote deployment directory (default: /opt/dawn-router)
  -p, --ssh-port PORT       SSH port (default: 22)
  -i, --ssh-key PATH        SSH private key (default: ~/.ssh/dawn-router-deploy)
      --skip-upload         Do not upload the Compose or deployment script
  -h, --help                Show this help
EOF
}

die() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

require_option_value() {
  [ "$#" -ge 2 ] || die "Option $1 requires a value."
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -t|--image-tag)
      require_option_value "$@"
      IMAGE_TAG=$2
      shift 2
      ;;
    --image-tag=*)
      IMAGE_TAG=${1#*=}
      shift
      ;;
    -s|--server)
      require_option_value "$@"
      SERVER=$2
      shift 2
      ;;
    --server=*)
      SERVER=${1#*=}
      shift
      ;;
    -d|--deploy-path)
      require_option_value "$@"
      DEPLOY_PATH=$2
      shift 2
      ;;
    --deploy-path=*)
      DEPLOY_PATH=${1#*=}
      shift
      ;;
    -p|--ssh-port)
      require_option_value "$@"
      SSH_PORT=$2
      shift 2
      ;;
    --ssh-port=*)
      SSH_PORT=${1#*=}
      shift
      ;;
    -i|--ssh-key)
      require_option_value "$@"
      SSH_KEY=$2
      shift 2
      ;;
    --ssh-key=*)
      SSH_KEY=${1#*=}
      shift
      ;;
    --skip-upload|-u)
      SKIP_UPLOAD='1'
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown option: $1"
      ;;
  esac
done

[ -n "$IMAGE_TAG" ] || die 'Image tag is required. Use --image-tag.'
[ -n "$SERVER" ] || die 'Server is required. Use --server.'
[ -n "$DEPLOY_PATH" ] || die 'Deploy path must not be empty.'

if ! printf '%s\n' "$IMAGE_TAG" | grep -Eq '^(sha-[0-9a-f]{40}|v[0-9A-Za-z._-]+)$'; then
  die 'Image tag must match sha-<40 lowercase hex> or v<version>.'
fi

case "$SSH_PORT" in
  [0-9]|[0-9][0-9]|[0-9][0-9][0-9]|[0-9][0-9][0-9][0-9]|[0-9][0-9][0-9][0-9][0-9])
    ;;
  *)
    die 'SSH port must be a number from 1 to 65535.'
    ;;
esac

if [ "$SSH_PORT" -lt 1 ] || [ "$SSH_PORT" -gt 65535 ]; then
  die 'SSH port must be a number from 1 to 65535.'
fi

case "$SERVER" in
  -*|*" "*)
    die "Server must not start with a dash or contain spaces."
    ;;
esac

command -v ssh >/dev/null 2>&1 || die 'The ssh command was not found.'
if [ "$SKIP_UPLOAD" -eq 0 ]; then
  command -v scp >/dev/null 2>&1 || die 'The scp command was not found.'
fi

USE_SSH_KEY='0'
if [ -f "$SSH_KEY" ]; then
  USE_SSH_KEY='1'
else
  printf 'SSH private key was not found: %s\n' "$SSH_KEY" >&2
  printf 'Falling back to interactive password authentication.\n' >&2
fi

SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd "$SCRIPT_DIR/.." && pwd)
COMPOSE_FILE="$REPOSITORY_ROOT/docker-compose.prod.yml"
DEPLOY_SCRIPT="$SCRIPT_DIR/production-deploy.sh"

[ -f "$COMPOSE_FILE" ] || die "Production Compose file was not found: $COMPOSE_FILE"
[ -f "$DEPLOY_SCRIPT" ] || die "Production deploy script was not found: $DEPLOY_SCRIPT"

run_ssh() {
  if [ "$USE_SSH_KEY" -eq 1 ]; then
    ssh \
      -i "$SSH_KEY" \
      -p "$SSH_PORT" \
      -o BatchMode=yes \
      -o StrictHostKeyChecking=yes \
      "$@"
  else
    ssh \
      -p "$SSH_PORT" \
      -o BatchMode=no \
      -o PubkeyAuthentication=no \
      -o PreferredAuthentications=password,keyboard-interactive \
      -o StrictHostKeyChecking=yes \
      "$@"
  fi
}

run_scp() {
  if [ "$USE_SSH_KEY" -eq 1 ]; then
    scp \
      -i "$SSH_KEY" \
      -P "$SSH_PORT" \
      -o BatchMode=yes \
      -o StrictHostKeyChecking=yes \
      "$@"
  else
    scp \
      -P "$SSH_PORT" \
      -o BatchMode=no \
      -o PubkeyAuthentication=no \
      -o PreferredAuthentications=password,keyboard-interactive \
      -o StrictHostKeyChecking=yes \
      "$@"
  fi
}

remote_shell_quote() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

REMOTE_DEPLOY_PATH=$(remote_shell_quote "$DEPLOY_PATH")
REMOTE_ROOT="$SERVER:$DEPLOY_PATH"

if ! run_ssh "$SERVER" "test -f $REMOTE_DEPLOY_PATH/.env && test -f $REMOTE_DEPLOY_PATH/deploy/app.env"; then
  die 'Production environment files were not found on the server.'
fi

if [ "$SKIP_UPLOAD" -eq 0 ]; then
  if ! run_scp "$COMPOSE_FILE" "$REMOTE_ROOT/"; then
    die 'Uploading docker-compose.prod.yml failed.'
  fi

  if ! run_scp "$DEPLOY_SCRIPT" "$SERVER:$DEPLOY_PATH/deploy/"; then
    die 'Uploading production-deploy.sh failed.'
  fi
fi

REMOTE_IMAGE_TAG=$(remote_shell_quote "$IMAGE_TAG")
REMOTE_IMAGE_REPOSITORY=$(remote_shell_quote "$IMAGE_REPOSITORY")
REMOTE_COMMAND="cd $REMOTE_DEPLOY_PATH && chmod 700 deploy/production-deploy.sh && IMAGE_TAG=$REMOTE_IMAGE_TAG IMAGE_REPOSITORY=$REMOTE_IMAGE_REPOSITORY ./deploy/production-deploy.sh"

if ! run_ssh "$SERVER" "$REMOTE_COMMAND"; then
  die "Remote deployment failed for image tag: $IMAGE_TAG"
fi

printf 'Deployment completed: %s:%s\n' "$IMAGE_REPOSITORY" "$IMAGE_TAG"