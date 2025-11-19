# include guard
if [[ -n "$_SYSTEM_SH_INCLUDED" ]]; then
  return
fi
_SYSTEM_SH_INCLUDED=1

# absolute path to root folder
if [[ "${FOLDER_bash}" == "" ]]; then
    echo "FOLDER_bash not set"
    exit 1
fi

# includes
# ########

source "${FOLDER_bash}/logging.sh"

# variables
# #########

SUDO=""
if command -v sudo >/dev/null 2>&1; then
    SUDO=sudo
fi

# functions
# #########

# ensure/sanity functions
function ensure_debian() {
    [[ -f /etc/debian_version ]] || log_error "Only Debian systems are supported"
}

function ensure_command() {
    [[ "${1}" != "" ]] || log_error "empty argument"
    command -v "${1}" >/dev/null 2>&1 || log_error "Command '${1}' not found"
}

function ensure_file() {
    [[ "${1}" != "" ]] || log_error "empty argument"
    [[ -f "${1}" ]] || log_error "File '${1}' not found"
}

function ensure_folder() {
    [[ "${1}" != "" ]] || log_error "empty argument"
    [[ -d "${1}" ]] || log_error "Folder '${1}' not found"
}

# other
function debian_apt_update() {
    ensure_debian
    run ${SUDO} apt-get update
}

function debian_apt_install() {
    ensure_debian

    local PACKAGE=$1
    local COMMAND=$2 # optional command to check

    if [[ "${PACKAGE}" == "" ]] || [[ "$3" != "" ]]; then
        log_error "Only one package installation at a time is supported"
    fi

    # install
    log_info "Dependency: ${PACKAGE}..."
    run ${SUDO} apt-get install -y "${PACKAGE}"

    # check installation
    if [[ "${COMMAND}" != "" ]]; then
        ensure_command "${COMMAND}"
    fi
}

function get_cpu_cores() {
    local cores=1
    if [[ "$(uname)" == "Darwin" ]]; then
        cores=$(sysctl -n hw.ncpu 2>/dev/null || echo 1)
    elif [[ "$(uname)" == "Linux" ]]; then
        cores=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || nproc 2>/dev/null || echo 1)
    else
        cores=1
    fi
    echo "$cores"
}

function get_ip_address() {
    local IP=""

    ensure_command curl

    IP=$(curl -s https://api.ipify.org)
    [[ $IP =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] && \
        IFS='.' read -ra O <<< "$IP" && \
        ((O[0]<=255 && O[1]<=255 && O[2]<=255 && O[3]<=255)) || \
        IP=""
    
    echo "$IP"
}
