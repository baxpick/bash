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

source "${FOLDER_bash}/system.sh"
source "${FOLDER_bash}/logging.sh"

# sanity / dependencies
# #####################

ensure_debian
debian_apt_update

debian_apt_install curl

log_info "Dependency: Azure CLI..."
if ! command -v az >/dev/null 2>&1; then
    curl -sL https://aka.ms/InstallAzureCLIDeb |${SUDO} bash
fi
ensure_command az

if ! az extension show --name "azure-devops" >/dev/null 2>&1; then
    run az extension add --name azure-devops
fi

debian_apt_install jq

# functions
# #########

function azure_login() {

    log_info "Logging in to Azure..."

    # defaults
    local CLIENT_ID=""
    local CLIENT_CERT_PATH=""
    local CLIENT_CERT_BASE64=""
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
            --clientCertPath)
            CLIENT_CERT_PATH="$2"
            shift
            shift
            ;;
            --clientCertBase64)
            CLIENT_CERT_BASE64="$2"
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

    # Validate required arguments
    { \
        [[ ${CLIENT_ID} != "" ]] && \
        [[ ${TENANT_ID} != "" ]] && \
        [[ ${CLIENT_CERT_PATH} != "" ]] && \
        [[ ${CLIENT_CERT_BASE64} != "" ]] \
    } || { log_error "Function argument missing"; }

    ensure_command "az"

    # Check if already logged in
    if ! az account show >/dev/null 2>&1; then

        mkdir -p "$(dirname "${CLIENT_CERT_PATH}")" >/dev/null 2>&1 || true

        echo "${ARM_CLIENT_CERT_BASE64}" |base64 -d >"${CLIENT_CERT_PATH}"
        chmod 600 "${CLIENT_CERT_PATH}"

        # convert .pem to .pfx
        # REMARK: tofu needs this in ARM_CLIENT_CERTIFICATE_PATH variable
        export ARM_CLIENT_CERTIFICATE_PATH=$(dirname "${ARM_CLIENT_CERT_PATH}")/azure-sp.pfx
        openssl pkcs12 \
            -export \
            -out ${ARM_CLIENT_CERTIFICATE_PATH} \
            -in "${ARM_CLIENT_CERT_PATH}" \
            -passout pass: \
            -macalg sha1 \
            -keypbe PBE-SHA1-3DES \
            -certpbe PBE-SHA1-3DES

        az login --service-principal \
            --username ${CLIENT_ID} \
            --certificate "${CLIENT_CERT_PATH}" \
            --tenant ${TENANT_ID} >/dev/null 2>&1
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
  local ipAddressStart=""
  local ipAddressEnd=""
  local resourceGroup=""
  local resourceName=""
  local resourceType=""

  # Parse named arguments
  while [[ $# -gt 0 ]]; do
      key="$1"
      case $key in
          --ipAddressStart)
          ipAddressStart="$2"
          shift
          shift
          ;;
          --ipAddressEnd)
          ipAddressEnd="$2"
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
    [[ "${ipAddressStart}" != "" ]] && \
    [[ "${ipAddressEnd}" != "" ]] && \
    [[ "${resourceGroup}" != "" ]] && \
    [[ "${resourceName}" != "" ]] && \
    [[ "${resourceType}" != "" ]] \
  } || { log_error "Function argument missing"; }

  # log
  log_info "[LOG] IP Address Start: ${ipAddressStart}"
  log_info "[LOG] IP Address End: ${ipAddressEnd}"
  log_info "[LOG] Resource Group: ${resourceGroup}"
  log_info "[LOG] Resource Name: ${resourceName}"
  log_info "[LOG] Resource Type: ${resourceType}"

  # main
  if [[ "${resourceType}" == "postgres_flexible_server" ]]; then
    run az postgres flexible-server \
        firewall-rule create \
        --resource-group "${resourceGroup}" \
        --name "${resourceName}" \
        --rule-name "allow-ip-range" \
        --start-ip-address "${ipAddressStart}" \
        --end-ip-address "${ipAddressEnd}"
  else
    log_error "Unsupported resource type '${resourceType}'"
  fi

  log_info "Open azure resource access completed successfully"
}

# close access to resource so that change can be applied
function azure_resource_close() {

  log_info "Close azure resource access..."

  # defaults
  local resourceGroup=""
  local resourceName=""
  local resourceType=""

  # Parse named arguments
  while [[ $# -gt 0 ]]; do
      key="$1"
      case $key in
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
    [[ "${resourceGroup}" != "" ]] && \
    [[ "${resourceName}" != "" ]] && \
    [[ "${resourceType}" != "" ]] \
  } || { log_error "Function argument missing"; }

  # log
  log_info "[LOG] Resource Group: ${resourceGroup}"
  log_info "[LOG] Resource Name: ${resourceName}"
  log_info "[LOG] Resource Type: ${resourceType}"

  # main
  if [[ "${resourceType}" == "postgres_flexible_server" ]]; then
    run az postgres flexible-server \
        firewall-rule delete \
        --resource-group "${resourceGroup}" \
        --name "${resourceName}" \
        --rule-name "allow-ip-range" \
        --yes
  else
    log_error "Unsupported resource type '${resourceType}'"
  fi

  log_info "Close azure resource access completed successfully"
}


function azure_fetch_tls_cert_and_key() {
    log_info "Fetch TLS Certificates from Azure Key Vault..."

    # defaults
    local vault_name=""
    local cert_name=""
    local key_name=""
    local certs_dir_output=""
    local cert_name_output="combined_cert.pem"
    local cert_key_output="privkey.pem"

    # Parse named arguments
    while [[ $# -gt 0 ]]; do
        key="$1"
        case $key in
            --vaultName)
            vault_name="$2"
            shift
            shift
            ;;
            --certName)
            cert_name="$2"
            shift
            shift
            ;;
            --keyName)
            key_name="$2"
            shift
            shift
            ;;
            --certsDirOutput)
            certs_dir_output="$2"
            shift
            shift
            ;;
            --certNameOutput)
            cert_name_output="$2"
            shift
            shift
            ;;
            --keyNameOutput)
            cert_key_output="$2"
            shift
            shift
            ;;
        esac
    done

    # Validate required arguments
    { \
        [[ ${vault_name} != "" ]] && \
        [[ ${cert_name} != "" ]] && \
        [[ ${key_name} != "" ]] && \
        [[ ${certs_dir_output} != "" ]] && \
        [[ ${cert_name_output} != "" ]] && \
        [[ ${cert_key_output} != "" ]] \
    } || { log_error "Function argument missing"; }

    local cert_name_output_full="${certs_dir_output}/${cert_name_output}"
    local cert_key_output_full="${certs_dir_output}/${cert_key_output}"

    ensure_command "az"

    # log_info "Fetching certificates with the following parameters:"
    # log_info "Vault: ${vault_name}"
    # log_info "Certificate: ${cert_name}"
    # log_info "Private Key: ${key_name}"
    # log_info "Certificates Directory: ${certs_dir_output}"
    # log_info "Certificate Output Name: ${cert_name_output}"
    # log_info "Private Key Output Name: ${cert_key_output}"

    # Create certs directory
    mkdir -p "${certs_dir_output}" || log_error "Failed to create certificates directory"

    ensure_command az

    rm "${cert_name_output_full}" >/dev/null 2>&1 || true
    rm "${cert_key_output_full}" >/dev/null 2>&1 || true

    # Fetch certificate
    #log_info "Downloading certificate..."
    az keyvault certificate download \
        --vault-name "${vault_name}" \
        --name "${cert_name}" \
        --file "${cert_name_output_full}" \
        --encoding PEM || log_error "Failed to download certificate from Key Vault"

    # Fetch private key
    #log_info "Downloading private key..."
    az keyvault secret show \
        --vault-name "${vault_name}" \
        --name "${key_name}" \
        --query value \
        -o tsv > "${cert_key_output_full}" || log_error "Failed to download private key from Key Vault"

    ensure_file "${cert_name_output_full}"
    ensure_file "${cert_key_output_full}"

    # chmod 600 "${cert_name_output_full}"
    # chmod 600 "${cert_key_output_full}"

    # Decode and convert private key to proper format
    #log_info "Converting private key to proper PEM format..."
    ensure_command "mktemp"
    local privkey_temp=$(mktemp "${certs_dir_output}/privkey_temp.XXXXXX")
    local privkey_decoded=$(mktemp "${certs_dir_output}/privkey_decoded.XXXXXX")
    
    # Azure Key Vault stores keys as base64, decode first
    ensure_command "base64"
    base64 -d < "${cert_key_output_full}" >"${privkey_decoded}"

    # Convert to EC format
    ensure_command "openssl"
    openssl ec -in "${privkey_decoded}" -out "${privkey_temp}" 2>/dev/null || log_error "Failed to convert private key format"
    mv "${privkey_temp}" "${cert_key_output_full}"
    rm -f "${privkey_decoded}" >/dev/null 2>&1

    chmod 600 "${cert_name_output_full}"
    chmod 600 "${cert_key_output_full}"

    # log_info "✅ Certificates fetched successfully"
    # log_info "Certificate: ${cert_name_output_full}"
    # log_info "Private Key: ${cert_key_output_full}"

    log_info "Fetch TLS Certificates from Azure Key Vault done successfully"
}

# MAIN
# ####

# AZURE LOGIN
if ! command -v az >/dev/null || \
    [ -z "${ARM_CLIENT_ID}" ] || \
    [ -z "${ARM_CLIENT_CERT_PATH}" ] || \
    [ -z "${ARM_CLIENT_CERT_BASE64}" ] || \
    [ -z "${ARM_TENANT_ID}" ] || \
    [ -z "${ARM_SUBSCRIPTION_ID}" ]; then

    log_warning "[AZURE LOGIN] AZURE CLI login can not be performed."
else 
    azure_login --clientId ${ARM_CLIENT_ID} --clientCertPath ${ARM_CLIENT_CERT_PATH} --clientCertBase64 ${ARM_CLIENT_CERT_BASE64} --tenantId ${ARM_TENANT_ID}
fi
