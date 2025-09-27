#!/bin/sh
set -eu

if [ -z "$INPUT_REMOTE_HOST_FINGERPRINT" ]; then
  echo "Warning: No remote_host_fingerprint provided. SSH strict host key checking is disabled."
  SSH_STRICT_OPTION="-o StrictHostKeyChecking=no"
else
  echo "Info: remote_host_fingerprint provided. SSH strict host key checking is enabled."
  SSH_STRICT_OPTION="-o StrictHostKeyChecking=yes"
fi

execute_ssh() {
  echo "Execute SSH command: $*"
  ssh -t -i "$HOME/.ssh/id_rsa" \
    -o UserKnownHostsFile=/dev/null \
    -p "$INPUT_REMOTE_DOCKER_PORT" \
    "$SSH_STRICT_OPTION" "$INPUT_REMOTE_DOCKER_HOST" "$@" 2>&1
  exit_code=$?
  if [ $exit_code -ne 0 ]; then
    echo "Error: SSH command failed with exit code $exit_code."
    exit $exit_code
  fi
}

if [ -z "$INPUT_REMOTE_DOCKER_HOST" ]; then
  echo "Error: remote_docker_host input is required!"
  exit 1
fi

if [ -z "$INPUT_REMOTE_DOCKER_PORT" ]; then
  INPUT_REMOTE_DOCKER_PORT=22
fi

if [ -z "$INPUT_SSH_PUBLIC_KEY" ]; then
  echo "Error: ssh_public_key input is required!"
  exit 1
fi

if [ -z "$INPUT_SSH_PRIVATE_KEY" ]; then
  echo "Error: ssh_private_key input is required!"
  exit 1
fi

if [ -z "$INPUT_SERVICE_NAME" ]; then
  echo "Error: service_name input is required!"
  exit 1
fi

if [ -z "$INPUT_DEPLOY_PATH" ]; then
  echo "Error: deploy_path input is required!"
  exit 1
fi

if [ -z "$INPUT_ARGS" ]; then
  echo "Error: args input is required!"
  exit 1
fi

if [ -z "$INPUT_PULL_IMAGES_FIRST" ]; then
  INPUT_PULL_IMAGES_FIRST=false
fi

if [ -z "$INPUT_STACK_FILE_NAME" ]; then
  INPUT_STACK_FILE_NAME=docker-compose.yml
fi

SSH_HOST=${INPUT_REMOTE_DOCKER_HOST#*@}

echo "Registering SSH keys..."

# register the private key with the agent.
mkdir -p "$HOME/.ssh"
printf '%s\n' "$INPUT_SSH_PRIVATE_KEY" > "$HOME/.ssh/id_rsa"
chmod 600 "$HOME/.ssh/id_rsa"
eval "$(ssh-agent)"
ssh-add "$HOME/.ssh/id_rsa"
echo "Adding known hosts..."
printf '%s %s\n' "$SSH_HOST" "$INPUT_SSH_PUBLIC_KEY" > /etc/ssh/ssh_known_hosts
chmod 644 /etc/ssh/ssh_known_hosts

# --- FINGERPRINT CHECK (before any SSH command) ---
if [ -z "$INPUT_REMOTE_HOST_FINGERPRINT" ]; then
  echo "Warning: No fingerprint provided. Skipping fingerprint check."
else
  echo "Checking remote host fingerprint..."
  HOST_ONLY=$(echo "$INPUT_REMOTE_DOCKER_HOST" | awk -F'@' '{print $2}')
  ACTUAL_FINGERPRINT=$(ssh-keyscan -p "$INPUT_REMOTE_DOCKER_PORT" "$HOST_ONLY" 2>/dev/null | ssh-keygen -lf - | awk '{print $2}')
  if [ "$ACTUAL_FINGERPRINT" != "$INPUT_REMOTE_HOST_FINGERPRINT" ]; then
    echo "Error: Fingerprint mismatch! Expected: $INPUT_REMOTE_HOST_FINGERPRINT, Found: $ACTUAL_FINGERPRINT"
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
ssh-agent -k
