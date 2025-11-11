# include guard
if [[ -n "$_GH_SH_INCLUDED" ]]; then
  return
fi
_GH_SH_INCLUDED=1

# absolute path to root folder
if [[ "${FOLDER_bash}" == "" ]]; then
    echo "FOLDER_bash not set"
    exit 1
fi

# includes
# ########

source "${FOLDER_bash}/system.sh"
source "${FOLDER_bash}/logging.sh"

# sanity
# ######

ensure_command gh

# functions
# #########

function gh_login() {

    log_info "Logging in to Github..."

    # defaults
    local pat=""
    local hostname="github.com"

    # Parse named arguments
    while [[ $# -gt 0 ]]; do
        key="$1"
        case $key in
            --pat)
            pat="$2"
            shift
            shift
            ;;
            --hostname)
            hostname="$2"
            shift
            shift
            ;;            
        esac
    done

    { \
        [[ ${pat} != "" ]] && \
        [[ ${hostname} != "" ]] \
    } || { log_error "Function argument missing"; }

    echo "${pat}" |run gh auth login --hostname "${hostname}" --with-token
    run gh auth status

    log_info "Logged in to Github successfully"
}

# Set or create an GitHub variable on a repo
function gh_repo_set_var() {

    # defaults
    local var_name=""
    local var_value=""
    local var_repo=""
    local var_secret="true"

    # Parse named arguments
    while [[ $# -gt 0 ]]; do
        key="$1"
        case $key in
            --name)
            var_name="$2"
            shift
            shift
            ;;
            --value)
            var_value="$2"
            shift
            shift
            ;;
            --repo)
            var_repo="$2"
            shift
            shift
            ;;
            --secret)
            var_secret="$2"
            shift
            shift
            ;;
        esac
    done

    { \
        [[ ${var_name} != "" ]] && \
        [[ ${var_value} != "" ]] && \
        [[ ${var_repo} != "" ]] && \
        [[ ${var_secret} != "" ]] \
    } || { log_error "Function argument missing"; }

    log_info "Setting GH var '${var_name}'"

    local gh_cmd="gh secret set"
    if [[ "${var_secret}" != "true" ]]; then
        gh_cmd="gh variable set"
    fi

    ${gh_cmd} \
        ${var_name} \
        --repo "${var_repo}" \
        --body "${var_value}" >/dev/null 2>&1

    [[ $? -eq 0 ]] || { log_error "Setting GH var '${var_name}' failed"; }
}
