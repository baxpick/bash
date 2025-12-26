# include guard
if [[ -n "$_ANSIBLE_SH_INCLUDED" ]]; then
  return
fi
_ANSIBLE_SH_INCLUDED=1

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

log_info "Dependency: Ansible..."
if ! command -v ansible-playbook >/dev/null 2>&1; then
    debian_apt_update
    debian_apt_install software-properties-common
    ${SUDO} add-apt-repository --yes --update ppa:ansible/ansible
    debian_apt_install ansible
fi
ensure_command ansible-playbook

# functions
# #########

# MAIN
# ####
