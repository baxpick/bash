# include guard
if [[ -n "$_LOGGING_SH_INCLUDED" ]]; then
  return
fi
_LOGGING_SH_INCLUDED=1

# absolute path to root folder
if [[ "${FOLDER_bash}" == "" ]]; then
    echo "FOLDER_bash not set"
    exit 1
fi

# includes
# ########

source "${FOLDER_bash}/system.sh"

# functions
# #########

function log_error() {
    (echo "🧨[$(date "+%Y-%m-%dT%H:%M:%S%z")] ${1}" >&2)
    exit 255
}

function log_error_no_exit() {
    (echo "🧨[$(date "+%Y-%m-%dT%H:%M:%S%z")] ${1}" >&2)
    return 255
}

function log_warning() {
    (echo "⚠️ [$(date "+%Y-%m-%dT%H:%M:%S%z")] ${1}" >&2)
}

function log_info() {
    (echo "ℹ️ [$(date "+%Y-%m-%dT%H:%M:%S%z")] ${1}" >&2)
}

function log_done() {
    (echo "✔️ [$(date "+%Y-%m-%dT%H:%M:%S%z")] ${1}" >&2)
}

function log_special() {
    (echo "❤️ [$(date "+%Y-%m-%dT%H:%M:%S%z")] ${1}" >&2)
}

function log_title() {
    (\
        echo >&2 && \
        echo "${1}" >&2 && \
        echo "$(printf "%0.s=" {1..80})" >&2 && \
        echo >&2 \
    )
}

function log_subtitle() {
    (\
        echo >&2 && \
        echo "${1}" >&2 && \
        echo "$(printf "%0.s-" {1..40})" >&2 && \
        echo >&2 \
    )
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
    echo >&2
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

    # build a copy of "$@" for logging, but mask sensitive values
    local log_args=()
    local mask_next=false
    for arg in "$@"; do
        if $mask_next; then
            log_args+=( '...' )
            mask_next=false
            continue
        fi
        if [[ "$arg" == "--account-key" ]]; then
            log_args+=( "$arg" )
            mask_next=true
        else
            log_args+=( "$arg" )
        fi
    done

    # log the (possibly masked) command
    ( echo "🚀[$(date "+%Y-%m-%dT%H:%M:%S%z")] ${log_args[*]}" >&2 )

    # actually run the real command with full args
    local result
    if [[ "${LOG_VERBOSE}" == "YES" ]]; then
        result=$( "$@" )
    else
        result=$( "$@" >/dev/null 2>&1 )
    fi

    if [[ $? -ne 0 ]]; then
        exit 255
    fi

    if [[ -n "${result}" ]]; then
        # ensure single trailing newline
        [[ "${result}" != *$'\n' ]] && result+=$'\n'
        printf '%s' "${result}"
    fi
}
