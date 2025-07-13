# include guard
if [[ -n "$_AZURE_SH_INCLUDED" ]]; then
  return
fi
_AZURE_SH_INCLUDED=1

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
ensure_command jq

# functions
# #########

function azure_login() {

    log_info "Logging in to Azure..."

    # defaults
    local CLIENT_ID=""
    local CLIENT_SECRET=""
    local TENANT_ID=""

    # Parse named arguments
    while [[ $# -gt 0 ]]; do
        key="$1"
        case $key in
            --clientId)
            CLIENT_ID="$2"
            shift
            shift
            ;;
            --clientSecret)
            CLIENT_SECRET="$2"
            shift
            shift
            ;;
            --tenantId)
            TENANT_ID="$2"
            shift
            shift
            ;;
        esac
    done

    { \
        [[ ${CLIENT_ID} != "" ]] && \
        [[ ${CLIENT_SECRET} != "" ]] && \
        [[ ${TENANT_ID} != "" ]] \
    } || { log_error "Function argument missing"; }

    ensure_command "az"

    if ! az account show >/dev/null 2>&1; then
        az login --service-principal -u ${ARM_CLIENT_ID} -p ${ARM_CLIENT_SECRET} --tenant ${ARM_TENANT_ID} >/dev/null 2>&1
    fi

    run az account show || { log_error "You are not signed in to Azure"; }

    log_info "Logged in to Azure successfully"
}

function azure_create_rg() {

    log_info "Create resource group..."

    # defaults
    local rg=""
    local location=""

    # Parse named arguments
    while [[ $# -gt 0 ]]; do
        key="$1"
        case $key in
            --resourceGroup)
            rg="$2"
            shift
            shift
            ;;
            --location)
            location="$2"
            shift
            shift
            ;;
        esac
    done

    { \
        [[ "${rg}" != "" ]] && \
        [[ "${location}" != "" ]] \
    } || { log_error "Function argument missing"; }

    local rg_found=$(az group list |jq -r ".[] | select(.name == \"${rg}\") | .id")

    # early exit if resource already exists...
    [[ "${rg_found}" != "" ]] && \
        { log_info "Group '${rg}' already created"; return; }

    # ...create resource otherwise
    run az group create \
        --name "${rg}" \
        --location "${location}"

    log_info "Group '${rg}' created successfully"
}

function azure_create_sa() {

    log_info "Create storage account..."

    # defaults
    local rg=""
    local location=""
    local sa_name=""
    local sa_sku=""
    local sa_tier=""
    local sa_public=""

    # Parse named arguments
    while [[ $# -gt 0 ]]; do
        key="$1"
        case $key in
            --resourceGroup)
            rg="$2"
            shift
            shift
            ;;
            --location)
            location="$2"
            shift
            shift
            ;;
            --saName)
            sa_name="$2"
            shift
            shift
            ;;
            --saSku)
            sa_sku="$2"
            shift
            shift
            ;;
            --saTier)
            sa_tier="$2"
            shift
            shift
            ;;
            --saPublic)
            sa_public="$2"
            shift
            shift
            ;;
        esac
    done

    { \
        [[ "${rg}" != "" ]] && \
        [[ "${location}" != "" ]] && \
        [[ "${sa_name}" != "" ]] && \
        [[ "${sa_sku}" != "" ]] && \
        [[ "${sa_tier}" != "" ]] && \
        [[ "${sa_public}" != "" ]] \
    } || { log_error "Function argument missing"; }

    # check Microsoft.Storage registration
    state=$(az provider show --namespace Microsoft.Storage --query registrationState -o tsv)
    if [ "$state" != "Registered" ]; then
        log_info "Registering Microsoft.Storage (current state: $state)"
        az provider register \
            --namespace Microsoft.Storage \
            --wait \
            --consent-to-permissions
        log_info "Microsoft.Storage registered successfully"
    else
        log_info "Microsoft.Storage already registered"
    fi

    local sa_name_found=$(az storage account list |jq -r ".[] | select(.name == \"${sa_name}\") | .id")
    
    # early exit if resource already exists...
    [[ "${sa_name_found}" != "" ]] && \
        { log_info "Storage account '${sa_name}' already created"; return; }

    # ...create resource otherwise
    run az storage account create \
        --resource-group "${rg}" \
        --location "${location}" \
        --name "${sa_name}" \
        --sku "${sa_sku}" \
        --access-tier "${sa_tier}" \
        --allow-blob-public-access "${sa_public}"

    log_info "Storage account '${sa_name}' created successfully"
}

function azure_create_sa_container() {
    log_info "Create storage account container..."

    # defaults
    local sa_name=""
    local sa_container_name=""

    # Parse named arguments
    while [[ $# -gt 0 ]]; do
        key="$1"
        case $key in
            --saName)
            sa_name="$2"
            shift
            shift
            ;;
            --saContainerName)
            sa_container_name="$2"
            shift
            shift
            ;;
        esac
    done

    { \
        [[ ${sa_name} != "" ]] && \
        [[ ${sa_container_name} != "" ]] \
    } || { log_error "Function argument missing"; }

    local sa_container_name_found=$(az storage container list --account-name ${sa_name} --auth-mode login |jq ".[] | select(.name == \"${sa_container_name}\")")
    
    # early exit if resource already exists...
    [[ "${sa_container_name_found}" != "" ]] && \
        { log_info "Storage account container '${sa_container_name}' already created"; return; }

    # ...create resource otherwise
    local key=$(az storage account keys list --account-name "${sa_name}" --query '[0].value' -o tsv)
    [[ ${key} != "" ]] || { log_error "Storage account key not found"; }

    run az storage container create \
        --name "${sa_container_name}" \
        --account-name "${sa_name}" \
        --account-key "${key}"

    log_info "Storage account container '${sa_container_name}' created successfully"
}

# open access to resource so that change can be applied
function azure_resource_open() {

  log_info "Open azure resource access"

  # defaults
  local ipAddress=""
  local resourceGroup=""
  local resourceName=""
  local resourceType=""

  # Parse named arguments
  while [[ $# -gt 0 ]]; do
      key="$1"
      case $key in
          --ipAddress)
          ipAddress="$2"
          shift
          shift
          ;;      
          --resourceGroup)
          resourceGroup="$2"
          shift
          shift
          ;;
          --resourceName)
          resourceName="$2"
          shift
          shift
          ;;
          --resourceType)
          resourceType="$2"
          shift
          shift
          ;;    
      esac
  done

  # sanity
  log_info "Sanity check..."
  ensure_command az
  { \
    [[ "${ipAddress}" != "" ]] && \
    [[ "${resourceGroup}" != "" ]] && \
    [[ "${resourceName}" != "" ]] && \
    [[ "${resourceType}" != "" ]] \
  } || { log_error "Function argument missing"; }

  # log
  log_info "[LOG] IP Address: ${ipAddress}"
  log_info "[LOG] Resource Group: ${resourceGroup}"
  log_info "[LOG] Resource Name: ${resourceName}"
  log_info "[LOG] Resource Type: ${resourceType}"

  # main
  if [[ "${resourceType}" == "postgres_flexible_server" ]]; then
    run az postgres flexible-server \
        firewall-rule create \
        --resource-group ${resourceGroup} \
        --name psqlf-main-mysurvey-wes-prod \
        --rule-name "allow-current-ip" \
        --start-ip-address ${ipAddress} \
        --end-ip-address ${ipAddress}
  else
    log_error "Unsupported resource type '${resourceType}'"
  fi

  log_info "Open azure resource access completed successfully"
}
