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

source "${FOLDER_bash}/sanity.sh"
source "${FOLDER_bash}/logging.sh"

# sanity
# ######

ensure_command docker

# functions
# #########

function docker_restart() {

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
