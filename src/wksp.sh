#!/bin/bash

# Check if the shell is zsh or bash
if [ -n "$ZSH_VERSION" ]; then
    SHELL_TYPE="zsh"
    setopt shwordsplit
else
    SHELL_TYPE="bash"
fi

wksp_folder_name=".wksp"
wksp_cache_name=".cache"

# Define colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Log function
log() {
    local level=$1
    local message=$2
    case $level in
    INFO)
        echo -e "${GREEN}[INFO]${NC} $message"
        ;;
    WARNING)
        echo -e "${YELLOW}[WARNING]${NC} $message"
        ;;
    ERROR)
        echo -e "${RED}[ERROR]${NC} $message"
        ;;
    *)
        echo -e "[UNKNOWN] $message"
        ;;
    esac
}

usage() {
    log WARNING "Not implemented"
}

# Function to read file and save lines to an array
read_file() {
    local file=$1
    if [[ ! -f $file ]]; then
        echo "File not found: $file"
        exit 1
    fi

    local lines=()
    while IFS= read -r line; do
        # Skip empty lines and lines starting with #
        if [[ -n $line && ! $line =~ ^# ]]; then
            lines+=("$line")
        fi
    done <"$file"

    # Return the lines array
    echo "${lines[@]}"
}

# Function to iterate projects and return a map
iterate_projects_and_return_map() {
    local file=$1

    if [ "$SHELL_TYPE" = "zsh" ]; then
        typeset -A project_repo_map # Declare an associative array for zsh
    else
        declare -A project_repo_map # Declare an associative array for bash
    fi

    # Read the projects into an array
    local projects=($(read_file "$file"))

    # Iterate over the projects array and process each pair
    for ((i = 1; i < ${#projects[@]}; i += 2)); do
        local repo="${projects[i]}"
        local project="${projects[i + 1]}"
        project_repo_map["$project"]="$repo"
    done

    if [ "$SHELL_TYPE" = "zsh" ]; then
        echo "$(typeset -p project_repo_map)" # Print the associative array declaration for zsh
    else
        echo "$(declare -p project_repo_map)" # Print the associative array declaration for bash
    fi
}

_add() {
    current_folder="$(pwd)"
    folder_name=$(basename "${current_folder}")

    project_repo_map=$(iterate_projects_and_return_map "${HOME}/${wksp_folder_name}/${wksp_cache_name}")
    eval "$project_repo_map"

    # Access the associative array
    for project in ${(v)project_repo_map}; do
        if [[ "${folder_name}" == "${project}" ]]; then
            log WARNING "${folder_name} already added"
            return 1
        fi
    done

    echo "${folder_name} ${current_folder}" >>"${HOME}/${wksp_folder_name}/${wksp_cache_name}"

    log INFO "${folder_name} added. Use command wksp ${folder_name} to access ${current_folder}"
}

_init() {
    if [ -d "${HOME}/${wksp_folder_name}" ]; then
        log ERROR "wksp already initialized"
    else
        mkdir -p "${HOME}/${wksp_folder_name}" || exit
        touch "${HOME}/${wksp_folder_name}/${wksp_cache_name}"
        log INFO "wksp initialized successfully"
    fi
}

_goto() {
    local folder=$(echo "$1" | tr '[:upper:]' '[:lower:]')

    # Assuming iterate_projects_and_return_map returns a valid associative array definition
    local project_repo_map
    project_repo_map=$(iterate_projects_and_return_map "${HOME}/${wksp_folder_name}/${wksp_cache_name}")

    # Evaluate the associative array
    eval "$project_repo_map"

    # Access the associative array
    for project in ${(k)project_repo_map}; do
        local project_non_intensive=$(echo "${project_repo_map[${project}]}" | tr '[:upper:]' '[:lower:]')
        if [[ "${folder}" == "${project_non_intensive}" ]]; then
            cd "${project}" || return 1
            echo -e '\nHit [Ctrl]+[D] to exit this child shell.'
            # Start a new child shell and store its PID
            $SHELL

            return 0
        fi
    done

    echo "Project '${folder}' not found."
    return 1
}

wksp() {
    if [ $# -eq 0 ]; then
        usage
    fi

    case $1 in
    init)
        _init
        ;;
    add)
        _add
        ;;
    *)
        _goto $1
        ;;
    esac
}
