# include guard
if [[ -n "$_TERRAFORM_SH_INCLUDED" ]]; then
  return
fi
_TERRAFORM_SH_INCLUDED=1

# absolute path to root folder
if [[ "${FOLDER_bash}" == "" ]]; then
    echo "FOLDER_bash not set"
    exit 1
fi

# includes
# ########

source "${FOLDER_bash}/sanity.sh"
source "${FOLDER_bash}/logging.sh"
source "${FOLDER_bash}/files.sh"
source "${FOLDER_bash}/azure.sh"

# functions
# #########

function terraform_backend_create() {

  local FILE_variables_backend=$1

  log_title "Terraform backend create"

  ensure_file ${FILE_variables_backend}

  # backend resource group
  local rg=$(value_from ${FILE_variables_backend} resource_group_name)
  local location=$(value_from ${FILE_variables_backend} location)
  azure_create_rg "${rg}" "${location}"
  (echo >&2)

  # backend storage account
  local sa_name=$(value_from ${FILE_variables_backend} storage_account_name)
  azure_create_sa "${rg}" "${location}" "${sa_name}" "Standard_LRS" "Cool" "true"
  (echo >&2)

  # backend storage account container
  local sa_container_name=$(value_from ${FILE_variables_backend} container_name)
  azure_create_sa_container "${sa_name}" "${sa_container_name}"
  (echo >&2)

  log_info "Terraform backend created successfully"
}

# wraps terraform commands
function terraform_run() {

  log_title "Terraform run"

  # defaults
  local folder=""
  local environment=""
  local action=""
  local FILE_variables=""
  local FILE_variables_backend=""

  # Parse named arguments
  while [[ $# -gt 0 ]]; do
      key="$1"
      case $key in
          --folder)
          folder="$2"
          shift
          shift
          ;;      
          --environment)
          environment="$2"
          shift
          shift
          ;;
          --action)
          action="$2"
          shift
          shift
          ;;
          --fileVars)
          FILE_variables="$2"
          shift
          shift
          ;;
          --fileVarsBackend)
          FILE_variables_backend="$2"
          shift
          shift
          ;;
      esac
  done

  # sanity
  log_info "Sanity check..."
  ensure_command terraform
  
  { \
    [[ "${folder}" != "" ]] && \
    [[ "${environment}" != "" ]] && \
    [[ "${action}" != "" ]] && \
    [[ "${FILE_variables}" != "" ]] && \
    [[ "${FILE_variables_backend}" != "" ]] \
  } || { log_error "Function argument missing"; }
  
  ensure_folder "${folder}"
  cd "${folder}" > /dev/null 2>&1
  ensure_file "main.tf"
  
  declare -a VALID_ENVIRONMENTS=("dev" "prod")
  if [[ ! " ${VALID_ENVIRONMENTS[@]} " =~ " ${environment} " ]]; then
    log_error "Invalid environment '${environment}'"
  fi

  declare -a VALID_ACTIONS=("resourcesCreate" "resourcesDelete")
  if [[ ! " ${VALID_ACTIONS[@]} " =~ " ${action} " ]]; then
    log_error "Invalid action '${action}'"
  fi

  ensure_file "${FILE_variables}"
  ensure_file "${FILE_variables_backend}"
  log_info "Sanity check completed successfully\n"

  # log
  log_info "[LOG] Current working directory: '$(pwd)'"

  log_info "[LOG] Folder: ${folder}"
  log_info "[LOG] Environment: ${environment}"
  log_info "[LOG] Action: ${action}"
  log_info "[LOG] File variables: ${FILE_variables}"
  log_info "[LOG] File variables backend: ${FILE_variables_backend}\n"
  
  # cleanup
  log_info "Cleanup..."
  rm -rf .terraform* 2>/dev/null
  rm "${environment}.plan" 2>/dev/null
  log_info "Cleanup completed successfully\n"

  # init
  log_info "Initialize..."
  run terraform init \
    -upgrade -input=false \
    -var "environment=${environment}" \
    -var "action=${action}" \
    -var-file="${FILE_variables}" \
    -backend-config="${FILE_variables_backend}"
  log_info "Initialize completed successfully\n"

  # validate
  log_info "Validate..."
  run terraform validate
  log_info "Validate completed successfully\n"

  # refresh
  log_info "Refresh..."
  run terraform refresh \
    -var "environment=${environment}" \
    -var "action=${action}" \  
    -input=false \
    -var-file="${FILE_variables}"
  log_info "Refresh completed successfully\n"

  # early exit on delete
  if [[ ${action} == "resourcesDelete" ]]; then
    log_info "Destroy..."
    run terraform destroy -auto-approve -input=false \
        -var "environment=${environment}" \
        -var "action=${action}" \
        -var-file="${FILE_variables}"
    log_info "Destroy completed successfully\n"
    return 0
  fi

  # otherwise plan and apply
  if [[ ${action} == "resourcesCreate" ]]; then
    log_info "Plan..."
    run terraform plan \
      -var "environment=${environment}" \
      -var "action=${action}" \
      -input=false \
      -var-file="${FILE_variables}" \
      -out "${environment}.plan"
    log_info "Plan completed successfully\n"

    log_info "Apply..."
    run terraform apply \
      -auto-approve \
      -input=false \
      "${environment}.plan"
    log_info "Apply completed successfully\n"
  fi

  cd - > /dev/null 2>&1
  log_info "Terraform run completed successfully\n"
}
