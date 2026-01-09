# include guard
if [[ -n "$_DOCKER_SH_INCLUDED" ]]; then
  return
fi
_DOCKER_SH_INCLUDED=1

# absolute path to root folder
if [[ "${FOLDER_bash}" == "" ]]; then
    echo "FOLDER_bash not set"
    exit 1
fi

# includes
# ########

source "${FOLDER_bash}/system.sh"
source "${FOLDER_bash}/logging.sh"

# sanity / dependencies
# #####################

ensure_debian
debian_apt_update

if ! command -v docker; then
  log_info "Dependency: docker..."

  # Add Docker's official GPG key:
  debian_apt_install ca-certificates
  debian_apt_install curl
  ${SUDO} install -m 0755 -d /etc/apt/keyrings
  ${SUDO} curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  ${SUDO} chmod a+r /etc/apt/keyrings/docker.asc

  # Add the repository to Apt sources:
  ${SUDO} tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

  debian_apt_update

  # Install Docker Engine packages
  debian_apt_install docker-ce
  debian_apt_install docker-ce-cli
  debian_apt_install containerd.io
  debian_apt_install docker-buildx-plugin
  debian_apt_install docker-compose-plugin
fi
ensure_command docker

# functions
# #########

function docker_restart_colima() {
    
    ensure_macos

    # defaults
    local cpu=6
    local memory=10

    # Parse named arguments
    while [[ $# -gt 0 ]]; do
        key="$1"
        case $key in
            --cpu)
            cpu="$2"
            shift
            shift
            ;;
            --memory)
            memory="$2"
            shift
            shift
            ;;
        esac
    done

    log_title "Restart docker"

    log_info "Currently only supported for colima"
    ensure_command colima

    log_info "Stopping..."
    run colima stop

    log_info "Starting with CPU: ${cpu}, Memory: ${memory}GB..."
    run colima start --cpu "${cpu}" --memory "${memory}"
}

function docker_clean_dangling_images() {
  log_title "Cleanup of dangling docker images"
  docker images --filter "dangling=true" -q |xargs -r docker rmi -f
}

function docker_delete_all() {
  log_title "Cleanup of all docker resources"
  
  docker ps -q | xargs -r docker stop
  docker ps -aq | xargs -r docker rm
  docker images -q | xargs -r docker rmi -f
  docker volume ls -q | xargs -r docker volume rm
  docker network ls -q --filter type=custom | xargs -r docker network rm 2>/dev/null || true
  
  # Final cleanup
  docker system prune -af --volumes
}
