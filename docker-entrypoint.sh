#!/bin/sh
set -eu

execute_ssh() {
  echo "Execute SSH command: $*"
  ssh -q -t -i "$HOME/.ssh/id_rsa" \
    -o UserKnownHostsFile=/dev/null \
    -p "$INPUT_REMOTE_DOCKER_PORT" \
    -o StrictHostKeyChecking=no "$INPUT_REMOTE_DOCKER_HOST" "$*"
}

if [ -z "$INPUT_REMOTE_DOCKER_HOST" ]; then
  echo "Input remote_docker_host is required!"
  exit 1
fi

if [ -z "$INPUT_REMOTE_DOCKER_PORT" ]; then
  INPUT_REMOTE_DOCKER_PORT=22
fi

if [ -z "$INPUT_SSH_PUBLIC_KEY" ]; then
  echo "Input ssh_public_key is required!"
  exit 1
fi

if [ -z "$INPUT_SSH_PRIVATE_KEY" ]; then
  echo "Input ssh_private_key is required!"
  exit 1
fi

if [ -z "$INPUT_SERVICE_NAME" ]; then
  echo "Input service_name is required!"
  exit 1
fi

if [ -z "$INPUT_DEPLOY_PATH" ]; then
  echo "Input input_deploy_path is required!"
  exit 1
fi

if [ -z "$INPUT_ARGS" ]; then
  echo "Input input_args is required!"
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
echo "Add known hosts"
printf '%s %s\n' "$SSH_HOST" "$INPUT_SSH_PUBLIC_KEY" > /etc/ssh/ssh_known_hosts

if [ -n "$INPUT_PULL_IMAGES_FIRST" ] && [ "$INPUT_PULL_IMAGES_FIRST" = 'true' ]; then
  execute_ssh "cd $INPUT_DEPLOY_PATH && docker-compose pull $INPUT_SERVICE_NAME"
fi

execute_ssh "cd $INPUT_DEPLOY_PATH && docker-compose -f $INPUT_STACK_FILE_NAME $INPUT_ARGS $INPUT_SERVICE_NAME 2>&1"
