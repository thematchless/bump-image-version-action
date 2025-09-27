#!/bin/sh
set -eu

trap 'ssh-agent -k > /dev/null 2>&1' EXIT

if [ -z "$INPUT_REMOTE_HOST_FINGERPRINT" ]; then
  echo "Warning: No remote_host_fingerprint provided. SSH strict host key checking is disabled." >&2
  SSH_STRICT_OPTIONS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
else
  echo "Info: remote_host_fingerprint provided. SSH strict host key checking is enabled."
  SSH_STRICT_OPTIONS="-o StrictHostKeyChecking=yes -o UserKnownHostsFile=$HOME/.ssh/known_hosts"
fi

execute_ssh() {
  echo "Execute SSH command: $*"
  # shellcheck disable=SC2086
  ssh -i "$HOME/.ssh/id_rsa" $SSH_STRICT_OPTIONS -p "$INPUT_REMOTE_DOCKER_PORT" "$INPUT_REMOTE_DOCKER_HOST" "$@" 2>&1
  exit_code=$?
  if [ $exit_code -ne 0 ]; then
    echo "Error: SSH command failed with exit code $exit_code." >&2
    exit $exit_code
  fi
}

# Input validation
if [ -z "$INPUT_REMOTE_DOCKER_HOST" ]; then
  echo "Error: remote_docker_host input is required!" >&2
  exit 1
fi

if [ -z "$INPUT_REMOTE_DOCKER_PORT" ]; then
  INPUT_REMOTE_DOCKER_PORT=22
fi

if [ -z "$INPUT_SSH_PUBLIC_KEY" ]; then
  echo "Error: ssh_public_key input is required!" >&2
  exit 1
fi

if [ -z "$INPUT_SSH_PRIVATE_KEY" ]; then
  echo "Error: ssh_private_key input is required!" >&2
  exit 1
fi

if [ -z "$INPUT_SERVICE_NAME" ]; then
  echo "Error: service_name input is required!" >&2
  exit 1
fi

if [ -z "$INPUT_DEPLOY_PATH" ]; then
  echo "Error: deploy_path input is required!" >&2
  exit 1
fi

if [ -z "$INPUT_ARGS" ]; then
  echo "Error: args input is required!" >&2
  exit 1
fi

if [ -z "$INPUT_PULL_IMAGES_FIRST" ]; then
  INPUT_PULL_IMAGES_FIRST=false
fi

if [ -z "$INPUT_STACK_FILE_NAME" ]; then
  INPUT_STACK_FILE_NAME=docker-compose.yml
fi

# Register the private key with the agent
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
printf '%s\n' "$INPUT_SSH_PRIVATE_KEY" > "$HOME/.ssh/id_rsa"
chmod 600 "$HOME/.ssh/id_rsa"
eval "$(ssh-agent)"
ssh-add "$HOME/.ssh/id_rsa"

# --- KNOWN HOSTS HANDLING ---
if [ -n "$INPUT_REMOTE_HOST_FINGERPRINT" ]; then
  echo "Adding server host key to known_hosts..."
  HOST_ONLY=$(echo "$INPUT_REMOTE_DOCKER_HOST" | awk -F'@' '{print $2}')
  ssh-keyscan -p "$INPUT_REMOTE_DOCKER_PORT" "$HOST_ONLY" > "$HOME/.ssh/known_hosts"
  chmod 644 "$HOME/.ssh/known_hosts"
fi
# --- END KNOWN HOSTS HANDLING ---

# --- FINGERPRINT CHECK (before any SSH command) ---
if [ -z "$INPUT_REMOTE_HOST_FINGERPRINT" ]; then
  echo "Warning: No fingerprint provided. Skipping fingerprint check." >&2
else
  echo "Checking remote host fingerprint..."
  HOST_ONLY=$(echo "$INPUT_REMOTE_DOCKER_HOST" | awk -F'@' '{print $2}')
  ACTUAL_FINGERPRINT=$(ssh-keyscan -p "$INPUT_REMOTE_DOCKER_PORT" "$HOST_ONLY" 2>/dev/null | ssh-keygen -lf - | awk '{print $2}')
  # Trim actual fingerprint
  ACTUAL_FINGERPRINT=$(echo "$ACTUAL_FINGERPRINT" | tr -d ' \t\n\r')
  found_match=false
  # Replace commas and newlines with spaces, then iterate
  for fp in $(echo "$INPUT_REMOTE_HOST_FINGERPRINT" | tr ',\n' '  '); do
    fp_trimmed=$(echo "$fp" | tr -d ' \t\n\r')
    [ -z "$fp_trimmed" ] && continue
    if [ "$ACTUAL_FINGERPRINT" = "$fp_trimmed" ]; then
      found_match=true
      break
    fi
  done
  if [ "$found_match" = false ]; then
    echo "Error: Fingerprint mismatch! Expected one of (with hex and length):"
    for fp in $(echo "$INPUT_REMOTE_HOST_FINGERPRINT" | tr ',\n' '  '); do
      fp_trimmed=$(echo "$fp" | tr -d ' \t\n\r')
      [ -z "$fp_trimmed" ] && continue
      fp_len=$(printf '%s' "$fp_trimmed" | wc -c | awk '{print $1-1}')
      echo "  '$fp_trimmed' (len: $fp_len) hex: $(printf '%s' "$fp_trimmed" | od -An -tx1)"
    done
    af_len=$(printf '%s' "$ACTUAL_FINGERPRINT" | wc -c | awk '{print $1-1}')
    echo "Found: '$ACTUAL_FINGERPRINT' (len: $af_len) hex: $(printf '%s' "$ACTUAL_FINGERPRINT" | od -An -tx1)" >&2
    exit 1
  fi
  echo "Fingerprint matches: $ACTUAL_FINGERPRINT"
fi
# --- END FINGERPRINT CHECK ---

if [ -n "$INPUT_PULL_IMAGES_FIRST" ] && [ "$INPUT_PULL_IMAGES_FIRST" = 'true' ]; then
  execute_ssh "cd \"$INPUT_DEPLOY_PATH\" && docker compose pull \"$INPUT_SERVICE_NAME\" && echo 'Pull finished.'"
fi

execute_ssh "cd \"$INPUT_DEPLOY_PATH\" && docker compose -f \"$INPUT_STACK_FILE_NAME\" $INPUT_ARGS \"$INPUT_SERVICE_NAME\" 2>&1 && echo 'Deploy finished.'"

shred -u "$HOME/.ssh/id_rsa"
echo "Deployment successful."
