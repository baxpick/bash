# include guard
if [[ -n "$_AZDO_SH_INCLUDED" ]]; then
  return
fi
_AZDO_SH_INCLUDED=1

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

ensure_command az
az extension show --name azure-devops >/dev/null 2>&1 || \
    { log_error "Azure DevOps extension for Azure CLI not installed. Please run 'az extension add --name azure-devops'"; }

# functions
# #########

function azdo_login() {

    log_info "Login to Azure DevOps..."

    # defaults
    local pat=""
    local organization=""
    local project=""

    # Parse named arguments
    while [[ $# -gt 0 ]]; do
        key="$1"
        case $key in
            --pat)
            pat="$2"
            shift
            shift
            ;;
            --organization)
            organization="$2"
            shift
            shift
            ;;
            --project)
            project="$2"
            shift
            shift
            ;;
        esac
    done

    { \
        [[ ${pat} != "" ]] && \
        [[ ${organization} != "" ]] && \
        [[ ${project} != "" ]] \
    } || { log_error "Function argument missing"; }

    export AZURE_DEVOPS_EXT_PAT="${pat}"

    az devops configure --defaults organization="${organization}" project="${project}"

    az devops project list >/dev/null 2>&1 || { log_error "Given PAT is not valid"; }

    log_info "Login to Azure DevOps finished successfully"
}

# Set or create an Azure DevOps pipeline variable
function azdo_pipeline_set_var() {

    # defaults
    local var_name=""
    local var_value=""
    local var_pipeline_id=""
    local var_secret="true"
    local var_override="true"

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
            --pipeline-id)
            var_pipeline_id="$2"
            shift
            shift
            ;;
            --secret)
            var_secret="$2"
            shift
            shift
            ;;
            --override)
            var_override="$2"
            shift
            shift
            ;;
        esac
    done

    { \
        [[ ${var_name} != "" ]] && \
        [[ ${var_value} != "" ]] && \
        [[ ${var_pipeline_id} != "" ]] && \
        [[ ${var_secret} != "" ]] && \
        [[ ${var_override} != "" ]] \
    } || { log_error "Function argument missing"; }

    log_info "Setting AZDO var '${var_name}'"

    az pipelines variable update \
        --pipeline-id "${var_pipeline_id}" \
        --name "${var_name}" \
        --value "${var_value}" \
        --allow-override "${var_override}" \
        --secret "${var_secret}" >/dev/null 2>&1 \
    || \
    az pipelines variable create \
        --pipeline-id "${var_pipeline_id}" \
        --name "${var_name}" \
        --value "${var_value}" \
        --allow-override "${var_override}" \
        --secret "${var_secret}" >/dev/null 2>&1

    [[ $? -eq 0 ]] || { log_error "Setting AZDO var '${var_name}' failed"; }
}
