# include guard
if [[ -n "$_LOGGING_SH_INCLUDED" ]]; then
  return
fi
_LOGGING_SH_INCLUDED=1

# includes
# ########

source sanity.sh

# functions
# #########

function log_error() {
    (echo >&2 && echo "[ERROR] [$(date)] ${1}" >&2)
    exit 255
}

function log_warning() {
    (echo >&2 && echo "[WARNING] [$(date)] ${1}" >&2)
}

function log_info() {
    (echo >&2 && echo "[INFO] [$(date)] ${1}" >&2)
}

function log_title() {
    (echo >&2 && \
    echo "${1}" >&2 && \
    echo "$(printf "%0.s=" {1..80})" >&2)
}

_log_box() {
    local text="${1}"
    local frameChar="${2:0:1}"
    local padding=" "

    local content="${padding}${text}${padding}"
    local content_length=${#content}
    
    local border_length=$(( (content_length + 2) ))
    local border=$(printf "${frameChar}%.0s" $(seq 1 ${border_length}))

    echo >&2
    echo "$border"  >&2
    echo "${frameChar}${content}${frameChar}" >&2
    echo "$border" >&2
}

function log_box() {
    local text="$1"

    _log_box "${text}" '#'
}

# execute a command and depending on LOG_VERBOSE variable print or suppress the output
# NOTE: use with caution, might not be sutable for all use-cases!
function run() {
    [[ "${1}" != "" ]] || log_error "empty argument"
    
    ensure_command date

    (echo "[run] [$(date)] $@" >&2)

    local result=""

    if [[ "${LOG_VERBOSE}" == "YES" ]]; then
        result=$("$@")
    else
        result=$("$@" >/dev/null 2>&1)
    fi

    if [[ $? -ne 0 ]]; then
        exit 1
    fi

    printf "${result}"
}
