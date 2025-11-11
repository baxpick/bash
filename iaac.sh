# include guard
if [[ -n "$_IAAC_SH_INCLUDED" ]]; then
  return
fi
_IAAC_SH_INCLUDED=1

# arguments (from environment - since script should be sourced)
TOOL="${IAAC_TOOL:-terraform}"

# absolute path to root folder
if [[ "${FOLDER_bash}" == "" ]]; then
    echo "FOLDER_bash not set"
    exit 1
fi

# includes
# ########

source "${FOLDER_bash}/system.sh"
source "${FOLDER_bash}/logging.sh"
source "${FOLDER_bash}/files.sh"
source "${FOLDER_bash}/azure.sh"

# sanity / dependencies
# #####################

ensure_debian
debian_apt_update

debian_apt_install git

if [[ "${TOOL}" == "terraform" ]]; then
  log_info "Dependency: terraform..."
  MY_TERRAFORM_VERSION=1.11.4
  if ! command -v terraform >/dev/null 2>&1; then
    git clone https://github.com/tfutils/tfenv.git ~/.tfenv >/dev/null 2>&1
    export PATH="${HOME}/.tfenv/bin:${PATH}" >/dev/null 2>&1
    tfenv install ${MY_TERRAFORM_VERSION} >/dev/null 2>&1
    tfenv use ${MY_TERRAFORM_VERSION} >/dev/null 2>&1
  fi
  ensure_command terraform
  terraform --version

elif [[ "${TOOL}" == "tofu" ]]; then
  log_info "Dependency: tofu..."
  debian_apt_install apt-transport-https
  debian_apt_install ca-certificates
  debian_apt_install curl
  debian_apt_install gnupg
  curl --proto '=https' --tlsv1.2 -fsSL https://get.opentofu.org/install-opentofu.sh -o install-opentofu.sh >/dev/null 2>&1
  chmod +x install-opentofu.sh > /dev/null 2>&1
  ${SUDO} ./install-opentofu.sh --install-method deb >/dev/null 2>&1
  rm -f install-opentofu.sh >/dev/null 2>&1
  ensure_command tofu
  tofu --version # Verify installation
else
  log_error "Invalid IAAC_TOOL '${TOOL}'"
fi

# functions
# #########

function iaac_backend_create() {

  log_subtitle "IaaC backend create"

  # defaults
  local location=""
  local FILE_variables_backend=""

  # Parse named arguments
  while [[ $# -gt 0 ]]; do
      key="$1"
      case $key in
          --location)
          location="$2"
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
  
  { \
    [[ "${location}" != "" ]] && \
    [[ "${FILE_variables_backend}" != "" ]] \
  } || { log_error "Function argument missing"; }
  
  ensure_file "${FILE_variables_backend}"
  log_info "Sanity check completed successfully"
  (echo >&2)

  # read variables
  local rg=$(value_from --file ${FILE_variables_backend} --findKey resource_group_name)
  local sa_name=$(value_from --file ${FILE_variables_backend} --findKey storage_account_name)
  local sa_container_name=$(value_from --file ${FILE_variables_backend} --findKey container_name)

  # log
  log_info "[LOG] File variables backend: ${FILE_variables_backend}"
  log_info "[LOG] location: ${location}"
  log_info "[LOG] resource group: ${rg}"
  log_info "[LOG] storage account name: ${sa_name}"
  log_info "[LOG] container name: ${sa_container_name}"
  (echo >&2)

  # create resources (or confirm they already exist)
  azure_create_rg --resourceGroup "${rg}" --location "${location}"
  (echo >&2)

  azure_create_sa --resourceGroup "${rg}" --location "${location}" --saName "${sa_name}" --saSku "Standard_LRS" --saTier "Cool" --saPublic "true"
  (echo >&2)

  azure_create_sa_container --saName "${sa_name}" --saContainerName "${sa_container_name}"
  (echo >&2)

  log_info "IaaC backend created successfully"
}

# wraps IaaC commands
function iaac_run() {

  log_subtitle "IaaC run"

  # defaults
  local folder=""
  local environment=""
  local action=""
  local FILE_variables=""
  local FILE_variables_backend=""
  local skip_refresh="NO"
  local skip_apply="YES"
  local skip_cleanup="NO"
  local skip_init="NO"
  local skip_validate="NO"
  local my_ip=""

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
          --skipRefresh)
          skip_refresh="$2"
          shift
          shift
          ;;
          --skipApply)
          skip_apply="$2"
          shift
          shift
          ;;
          --skipCleanup)
          skip_cleanup="$2"
          shift
          shift
          ;;
          --skipInit)
          skip_init="$2"
          shift
          shift
          ;;
          --skipValidate)
          skip_validate="$2"
          shift
          shift
          ;;
          --myIp)
          my_ip="$2"
          shift
          shift
          ;;          
      esac
  done

  # sanity
  log_info "Sanity check..."
  ensure_command ${TOOL}
  
  { \
    [[ "${folder}" != "" ]] && \
    [[ "${environment}" != "" ]] && \
    [[ "${action}" != "" ]] && \
    [[ "${FILE_variables}" != "" ]] && \
    [[ "${FILE_variables_backend}" != "" ]] && \
    [[ "${skip_refresh}" != "" ]] && \
    [[ "${skip_apply}" != "" ]] && \
    [[ "${skip_cleanup}" != "" ]] && \
    [[ "${skip_init}" != "" ]] && \
    [[ "${skip_validate}" != "" ]] && \
    [[ "${my_ip}" != "" ]] \
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
  log_info "Sanity check completed successfully"
  (echo >&2)

  [[ "${skip_refresh}" == "YES" ]] || [[ "${skip_refresh}" == "NO" ]] || \
    { log_error "Invalid skip_refresh - must be 'YES' or 'NO'"; }
  [[ "${skip_apply}" == "YES" ]] || [[ "${skip_apply}" == "NO" ]] || \
    { log_error "Invalid skip_apply - must be 'YES' or 'NO'"; }
  [[ "${skip_cleanup}" == "YES" ]] || [[ "${skip_cleanup}" == "NO" ]] || \
    { log_error "Invalid skip_cleanup - must be 'YES' or 'NO'"; }
  [[ "${skip_init}" == "YES" ]] || [[ "${skip_init}" == "NO" ]] || \
    { log_error "Invalid skip_init - must be 'YES' or 'NO'"; }
  [[ "${skip_validate}" == "YES" ]] || [[ "${skip_validate}" == "NO" ]] || \
    { log_error "Invalid skip_validate - must be 'YES' or 'NO'"; }
  
  # log
  log_info "[LOG] Current working directory: '$(pwd)'"

  log_info "[LOG] Folder: ${folder}"
  log_info "[LOG] Environment: ${environment}"
  log_info "[LOG] Action: ${action}"
  log_info "[LOG] File variables: ${FILE_variables}"
  log_info "[LOG] File variables backend: ${FILE_variables_backend}"
  log_info "[LOG] Skip refresh: ${skip_refresh}"
  log_info "[LOG] Skip apply: ${skip_apply}"
  log_info "[LOG] Skip cleanup: ${skip_cleanup}"
  log_info "[LOG] Skip init: ${skip_init}"
  log_info "[LOG] Skip validate: ${skip_validate}"
  log_info "[LOG] My IP: ${my_ip}"
  (echo >&2)
  
  # cleanup
  log_info "Cleanup..."
  if [[ "${skip_cleanup}" == "NO" ]]; then
    rm -rf .terraform* 2>/dev/null
    rm "${environment}.plan" 2>/dev/null
    rm "${environment}.plan.json" 2>/dev/null
    log_info "Cleanup completed successfully"
  else
    log_info "Cleanup skipped"
  fi
  (echo >&2)

  # init
  log_info "Initialize..."
  if [[ "${skip_init}" == "NO" ]]; then
    run ${TOOL} init \
      -upgrade -input=false \
      -var "environment=${environment}" \
      -var "action=${action}" \
      -var "my_ip=${my_ip}" \
      -var-file="${FILE_variables}" \
      -backend-config="${FILE_variables_backend}"
    log_info "Initialize completed successfully"
  else
    log_info "Initialize skipped"
  fi
  (echo >&2)

  # validate
  log_info "Validate..."
  if [[ "${skip_validate}" == "NO" ]]; then
    run ${TOOL} validate
    log_info "Validate completed successfully"
  else
    log_info "Validate skipped"
  fi
  (echo >&2)

  # early exit on delete
  if [[ ${action} == "resourcesDelete" ]]; then
    log_info "Destroy..."
    if [[ "${skip_apply}" == "NO" ]]; then
      run ${TOOL} destroy -auto-approve -input=false \
          -var "environment=${environment}" \
          -var "action=${action}" \
          -var "my_ip=${my_ip}" \
          -var-file="${FILE_variables}"
      log_info "Destroy completed successfully"
    else
      log_info "Destroy skipped"
    fi
    (echo >&2)
    return 0
  fi

  # otherwise plan and apply
   if [[ ${action} == "resourcesCreate" ]]; then

    # sync local state if drift was made
    log_info "Plan... (refresh only)"
    if [[ "${skip_refresh}" == "NO" ]]; then
      run ${TOOL} plan \
        -var "environment=${environment}" \
        -var "action=${action}" \
        -var "my_ip=${my_ip}" \
        -input=false \
        -refresh-only \
        -var-file="${FILE_variables}" \
        -out "temp.plan"
      log_info "Plan completed successfully"
    else
      log_info "Plan skipped"
    fi
    (echo >&2)  

    log_info "Plan+Apply... (real)"
    if [[ "${skip_apply}" == "NO" ]]; then
      log_info "Plan... (real)"
      run ${TOOL} plan \
        -var "environment=${environment}" \
        -var "action=${action}" \
        -var "my_ip=${my_ip}" \
        -input=false \
        -var-file="${FILE_variables}" \
        -out "${environment}.plan"
      ${TOOL} show -json "${environment}.plan" >"${environment}.plan.json"
      log_info "Plan (real) completed successfully"
      (echo >&2)

      log_info "Apply... (real)"
      run ${TOOL} apply \
        -auto-approve \
        -input=false \
        "${environment}.plan"      
      log_info "Apply (real) completed successfully"
    else
      log_info "Plan+Apply skipped"
    fi
    log_info "Plan+Apply (real) completed successfully"
    (echo >&2)    
  fi

  cd - > /dev/null 2>&1
  log_info "IaaC run completed successfully"
  (echo >&2)
}
