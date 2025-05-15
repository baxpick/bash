# include guard
if [[ -n "$_AWS_SH_INCLUDED" ]]; then
  return
fi
_AWS_SH_INCLUDED=1

# absolute path to root folder
if [[ "${FOLDER_bash}" == "" ]]; then
    echo "FOLDER_bash not set"
    exit 1
fi

# includes
# ########

source "${FOLDER_bash}/logging.sh"

# functions
# #########

function aws_login() {

    log_info "Logging in to AWS..."

    local ACCESS_KEY_ID=${1}
    local SECRET_ACCESS_KEY=${2}
    local DEFAULT_REGION=${3}

    { \
        [[ ${ACCESS_KEY_ID} != "" ]] && \
        [[ ${SECRET_ACCESS_KEY} != "" ]] && \
        [[ ${DEFAULT_REGION} != "" ]] \
    } || { log_error "Function argument missing"; }

    ensure_command "aws"

    if \
        aws configure set aws_access_key_id $ACCESS_KEY_ID && \
        aws configure set aws_secret_access_key $SECRET_ACCESS_KEY && \
        aws configure set default.region $DEFAULT_REGION && \
        aws sts get-caller-identity; then

        log_info "Logged in to AWS successfully"
    else
        log_error "You are not signed in to AWS"
    fi   
}
