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

function aws_update_nameservers_from_azure_dns_zone() {

    log_info "Updating aws name servers from azure dns zone..."

    local DOMAIN_NAME=${1}
    local AWS_REGION=${2}
    local AZURE_DNS_ZONE_RG=${3}
    local WAIT_FOR_UPDATE=${4}

    { \
        [[ ${DOMAIN_NAME} != "" ]] && \
        [[ ${AWS_REGION} != "" ]] && \
        [[ ${AZURE_DNS_ZONE_RG} != "" ]] && \
        [[ ${WAIT_FOR_UPDATE} != "" ]] \
    } || { log_error "Function argument missing"; }

    ensure_command "aws"
    ensure_command "az"
    ensure_command "jq"
    
    local AZURE_NS_UNPARSED=$(az network dns zone show -g ${AZURE_DNS_ZONE_RG} -n ${DOMAIN_NAME} --query nameServers)

    AZURE_NS=()
    while read -r line; do
        AZURE_NS+=("${line%.}")
    done < <(echo "${AZURE_NS_UNPARSED}" | jq -r '.[]')

    run aws route53domains update-domain-nameservers \
        --region ${AWS_REGION} \
        --domain-name ${DOMAIN_NAME} \
        --nameservers \
            "Name=${AZURE_NS[3]}" \
            "Name=${AZURE_NS[2]}" \
            "Name=${AZURE_NS[1]}" \
            "Name=${AZURE_NS[0]}"

    if [[ "${WAIT_FOR_UPDATE}" == "YES" ]]; then
        local WAIT_ELAPSED=0
        local WAIT_TIMEOUT=300

        log_info "Wait until change is propagated..."
        while true; do
            local AWS_NS_UNPARSED=$(aws route53domains get-domain-detail --domain-name "${DOMAIN_NAME}" --region ${AWS_REGION} --output text --query 'Nameservers[*].Name')
            if [[ "$(echo ${AWS_NS_UNPARSED} |grep ${AZURE_NS[3]} |grep ${AZURE_NS[2]} |grep ${AZURE_NS[1]} |grep ${AZURE_NS[0]})" != "" ]]; then                
                log_info "Updating aws name servers from azure dns zone finished successfully"
                return 0
            fi

            if [ "${WAIT_ELAPSED}" -ge "${WAIT_TIMEOUT}" ]; then
                log_error "Change not propagated within timeout"
            fi

            sleep 1
            WAIT_ELAPSED=$((WAIT_ELAPSED + 1))
        done
    fi

    log_info "Updating aws name servers from azure dns zone initiated successfully"
}
