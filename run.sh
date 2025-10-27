#!/usr/bin/env bash

# Single entry point script

# absolute path to root folder
if [[ "${FOLDER_ROOT}" == "" ]]; then
    echo "FOLDER_ROOT not set"
    exit 1
fi

# includes
# ########
export FOLDER_bash="${FOLDER_ROOT}/bash"
source "${FOLDER_bash}/logging.sh"

IAAC_TOOL="terraform"
source "${FOLDER_bash}/iaac.sh"

source "${FOLDER_bash}/azure.sh"
source "${FOLDER_bash}/aws.sh"

[[ "${LOG_VERBOSE}" == "YES" ]] || { log_warning "NOTE: for more detailed output, export LOG_VERBOSE=YES"; }

full_cmd=$(ps -o args= -p $$ | sed 's/^ *//')
log_box "$full_cmd"

usage() {
    echo "Usage: $0 -e ENVIRONMENT -a ACTION -p PROJECT_NAME"
    echo "  -e ENVIRONMENT   Environment (dev|prod)"
    echo "  -a ACTION        Action"
    echo "    resourcesCreate   : Create and initialize all resources if needed"
    echo "    resourcesDelete   : Delete all resources"
    echo "  -p PROJECT_NAME  Name of the project"
    echo "  -s PHASES        IaaC phases to skip (comma-separated)"
    echo "    backend           : Skip backend-creation phase"
    echo "    cleanup           : Skip cleanup phase"
    echo "    init              : Skip init phase"
    echo "    validate          : Skip validate phase"
    echo "    refresh           : Skip refresh phase"
    echo "    apply             : Skip apply phase"
    echo "  -B BEFORE_SCRIPT    : Optional script to run before main execution"
    echo "  -A AFTER_SCRIPT     : Optional script to run after main execution"
    exit 1
}

# parse command line arguments
skip_arg=""
# defaults for skip flags
skip_backend="NO"
skip_cleanup="NO"
skip_init="NO"
skip_validate="NO"
skip_refresh="NO"
skip_apply="NO"
while getopts "e:a:p:s:B:A:h" opt; do
    case ${opt} in
        e )
            environment=$OPTARG
            ;;
        a )
            action=$OPTARG
            ;;
        p )
            projectName=$OPTARG
            ;;
        s )
            skip_arg=$OPTARG
            ;;
        B )
            before_script=$OPTARG
            ;;
        A )
            after_script=$OPTARG
            ;;
        h )
            usage
            ;;
    esac
done
# parse skip_arg comma-separated phases
if [[ -n "$skip_arg" ]]; then
  IFS=',' read -ra phases <<< "$skip_arg"
  for phase in "${phases[@]}"; do
    case "$phase" in
      backend)   skip_backend="YES";;
      cleanup)   skip_cleanup="YES";;
      init)      skip_init="YES";;
      validate)  skip_validate="YES";;
      refresh)   skip_refresh="YES";;
      apply)     skip_apply="YES";;
      *)         log_warning "Unknown skip phase: $phase";;
    esac
  done
fi

log_title "ARGUMENTS (check & set)"
# ###############################

log_info "environment..."
[[ ! -z "${environment}" ]] || environment=${ENVIRONMENT} # pass as: command line argument *or* environment var
[[ ! -z "${environment}" ]] || { log_error_no_exit "Environment not set"; usage; }
declare -a VALID_ENVIRONMENTS=(\
    "dev"\
    "prod"
)
[[ " ${VALID_ENVIRONMENTS[@]} " =~ " ${environment} " ]] || { log_error_no_exit "Invalid environment: '${environment}'"; usage; }
log_info "environment='${environment}'"

log_info "action..."
declare -a VALID_ACTIONS=(\
    "resourcesCreate"\
    "resourcesDelete"
)
[[ " ${VALID_ACTIONS[@]} " =~ " ${action} " ]] || { log_error_no_exit "Invalid action: '${action}'"; usage; }
log_info "action='${action}'"

log_info "projectName..."
[[ ! -z "${projectName}" ]] || { log_error_no_exit "Project name not set"; usage; }
# Basic validation: check if project folder exists
ensure_folder "${FOLDER_ROOT}/terraform/projects/${projectName}"
log_info "projectName='${projectName}'"

log_info "skip..."
log_info "skip='${skip_arg}'"

log_title "SANITY"
# ################

azure_login --clientId ${ARM_CLIENT_ID} --clientCertPath ${ARM_CLIENT_CERT_PATH} --clientCertBase64 ${ARM_CLIENT_CERT_BASE64} --tenantId ${ARM_TENANT_ID}
aws_login --accessKeyId ${AWS_ACCESS_KEY_ID} --secretAccessKey ${AWS_SECRET_ACCESS_KEY} --defaultRegion ${AWS_DEFAULT_REGION}

log_info "subscription..."
[[ ! -z "${ARM_SUBSCRIPTION_ID}" ]] || { log_error "Subscription id not set"; }
subscriptionId=$(az account show --query id --output tsv)
[[ "${subscriptionId}" == "${ARM_SUBSCRIPTION_ID}" ]] || { errorout "Logged to wrong subscription"; }
log_info "subscription=OK"

log_title "Prepare variables"
# ###########################

TF_project_folder="${FOLDER_ROOT}/terraform/projects/${projectName}"

log_info "TF_file_variables..."
TF_file_variables="${TF_project_folder}/env/${environment}/terraform.tfvars"
ensure_file "${TF_file_variables}"
log_info "TF_file_variables=${TF_file_variables}"

log_info "TF_file_variables_backend..."
TF_file_variables_backend="${TF_project_folder}/env/${environment}/backend.tfvars"
ensure_file "${TF_file_variables_backend}"
log_info "TF_file_variables_backend=${TF_file_variables_backend}"

log_info "location_backend..."
location_backend=$(value_from --file ${TF_file_variables} --findKey location_backend)
[[ ! -z "${location_backend}" ]] || { log_error "Location for backend not set"; }
log_info "location_backend=${location_backend}"

log_info "my_ip..."
my_ip=$(curl -s https://ipinfo.io/ip) || { log_error "Can not get ip"; }
[[ ! -z "${my_ip}" ]] || { log_error "IP not set"; }
log_info "my_ip=${my_ip}"

log_info "rg_all..."
rg_all=$(value_from --file ${TF_file_variables} --findKey rg_all)
[[ ! -z "${rg_all}" ]] || { log_error "rg_all not set"; }
log_info "rg_all=${rg_all}"

log_title "EXPORT VARIABLES"
# ##########################

export_vars=(environment action projectName)

for v in "${export_vars[@]}"; do
  log_info "export ${v}"
  export "${v}"
done

log_title "MAIN EXECUTION"
# ########################

# run pre-execution script if provided
if [[ -n "${before_script}" ]]; then
    log_box "Running pre-execution script: ${before_script}"
    [[ -x "${before_script}" ]] || log_error "Pre-exec script not executable/found: ${before_script}"
    "${before_script}"
fi

declare -a TF_ACTIONS=("resourcesCreate" "resourcesDelete")

# iaac related actions
if [[ " ${TF_ACTIONS[@]} " =~ " ${action} " ]]; then

    if [[ "${skip_backend}" == "NO" ]]; then
        iaac_backend_create \
            --location "${location_backend}" \
            --fileVarsBackend "${TF_file_variables_backend}"
    else
        log_info "Skipping backend creation"
    fi

    iaac_run \
        --folder "${TF_project_folder}" \
        --environment "${environment}" \
        --action "${action}" \
        --fileVarsBackend "${TF_file_variables_backend}" \
        --fileVars "${TF_file_variables}" \
        --skipCleanup "${skip_cleanup}" \
        --skipInit "${skip_init}" \
        --skipValidate "${skip_validate}" \
        --skipRefresh "${skip_refresh}" \
        --skipApply "${skip_apply}" \
        --myIp "${my_ip}"

elif [[ "${action}" == "..." ]]; then
    echo "..."
else
    usage
fi

# run post-execution script if provided
if [[ -n "${after_script}" ]]; then
    log_box "Running post-execution script: ${after_script}"
    [[ -x "${after_script}" ]] || log_error "Post-exec script not executable/found: ${after_script}"
    "${after_script}"
fi
