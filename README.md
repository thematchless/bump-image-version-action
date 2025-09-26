[![Build and publish Docker image](https://github.com/thematchless/bump-image-version-action/actions/workflows/build.yml/badge.svg)](https://github.com/thematchless/bump-image-version-action/actions/workflows/build.yml)

# Bump docker image version on a remote host
This repository contains an GitHub action to bump up a docker image version specified in your docker-compose stack.

## Requirements for this GitHub Action to work
- your remote server must be accessible via ssh and is reachable
- you have a ssh private and public key to authenticate via ssh
- you have saved your private and public key to the GitHub project secrets

## Configuration options for the action

|      required      | key                     | example                                                                                                                                                                          | default            | description                                                                                    |
|:------------------:|-------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------|------------------------------------------------------------------------------------------------|
| :white_check_mark: | remote_docker_host      | thematchless@fancyServer.de                                                                                                                                                      |                    | username@host                                                                                  |
| :white_check_mark: | ssh_private_key         | -----BEGIN OPENSSH PRIVATE KEY----<br>UgAAAAtzc2gtZWQyNTUxOQAAACALBUg<br>UgAAAAtzc2gtZWQyNTUxOQAAACALBUg<br>UgAAAAtzc2gtZWQyNTUxOQAAACALBUg<br>-----END OPENSSH PRIVATE KEY----- |                    | private key in PEM format                                                                      |
| :white_check_mark: | ssh_public_key          | ssh-ed25519 ABCDABCDu027374972309                                                                                                                                                |                    | public key of the PEM                                                                          |
| :white_check_mark: | service_name            | super-fancy-react-app                                                                                                                                                            |                    | name of the service inside of the compose file                                                 |
| :white_check_mark: | deploy_path             | /home/thematchless/stack-1                                                                                                                                                       |                    | path which contains your compose file on the remote host                                       |
| :white_check_mark: | args                    | up -d                                                                                                                                                                            |                    | arguments how to start your service                                                            |
|        :x:         | stack_file_name         | docker-compose.yaml                                                                                                                                                              | docker-compose.yml | name of the compose file                                                                       |
|        :x:         | remote_docker_port      | 1337                                                                                                                                                                             | 22                 | ssh port on the host                                                                           |
|        :x:         | pull_images_first       | true                                                                                                                                                                             | false              | flag to force the image pull before starting                                                   |
|        :x:         | remote_host_fingerprint | SHA256:abc123def456...                                                                                                                                                           |                    | (optional) SSH host key fingerprint for verification. Get it via `ssh-keyscan -p <port> <host> | ssh-keygen -lf -` and save as secret. |


## Example GitHub action task
```yaml
- name: Deploy on Remote Server
  uses: thematchless/bump-image-version-action@v6
  with:
    remote_docker_host: thematchless@fancyServer.de
    ssh_private_key: ${{ secrets.REMOTE_SSH_PRIVATE_KEY }}
    ssh_public_key: ${{ secrets.REMOTE_SSH_PUBLIC_KEY }}
    service_name: super-fancy-react-app
    deploy_path: /home/thematchless/stack-1
    args: up -d
    pull_images_first: true
    remote_host_fingerprint: ${{ secrets.REMOTE_HOST_FINGERPRINT }}
```

## How to get your SSH host fingerprint
You can get the fingerprint of your remote host by running:

```sh
ssh-keyscan -p <port> <host> | ssh-keygen -lf -
```
Copy the SHA256 fingerprint and save it as a GitHub secret (e.g. REMOTE_HOST_FINGERPRINT). This will be used to verify the identity of your remote server before any SSH command is executed.

## License
This project is licensed under the MIT license. See the [LICENSE](LICENSE) file for details.
