#!/bin/bash
#
# File ownership utility functions for YT-DLP project
# Provides functions to check and enforce file ownership
#

# =============================================================================
# File Ownership Functions
# =============================================================================

# Check if a file or directory is owned by the current user
# Returns 0 if owned by current user, 1 otherwise
check_file_ownership() {
    local target="$1"
    
    if [ ! -e "$target" ]; then
        echo "ERROR: Target does not exist: $target" >&2
        return 2
    fi
    
    local uid gid
    uid=$(id -u)
    gid=$(id -g)
    
    local file_uid file_gid
    file_uid=$(stat -c "%u" "$target" 2>/dev/null || stat -f "%u" "$target" 2>/dev/null || echo 0)
    file_gid=$(stat -c "%g" "$target" 2>/dev/null || stat -f "%g" "$target" 2>/dev/null || echo 0)
    
    if [ "$file_uid" -eq "$uid" ] && [ "$file_gid" -eq "$gid" ]; then
        return 0  # Owned by current user
    else
        return 1  # Not owned by current user
    fi
}

# Enforce file ownership to current user
# Parameters:
#   $1: target file or directory
#   $2: optional - "recursive" for directories
# Returns 0 on success, 1 on failure
enforce_file_ownership() {
    local target="$1"
    local recursive="$2"
    
    if [ ! -e "$target" ]; then
        echo "ERROR: Target does not exist: $target" >&2
        return 1
    fi
    
    local uid gid
    uid=$(id -u)
    gid=$(id -g)
    
    if [ "$recursive" = "recursive" ]; then
        # Recursive chown
        chown -R "$uid:$gid" "$target"
        local result=$?
        if [ $result -eq 0 ]; then
            echo "INFO: Recursively set ownership of $target to $uid:$gid" >&2
        else
            echo "ERROR: Failed to set recursive ownership of $target" >&2
        fi
        return $result
    else
        # Non-recursive chown
        chown "$uid:$gid" "$target"
        local result=$?
        if [ $result -eq 0 ]; then
            echo "INFO: Set ownership of $target to $uid:$gid" >&2
        else
            echo "ERROR: Failed to set ownership of $target" >&2
        fi
        return $result
    fi
}

# Verify ownership of multiple files/directories
# Parameters:
#   $@: list of files/directories to check
# Returns 0 if all owned by current user, 1 otherwise
verify_all_ownership() {
    local all_good=true
    
    for target in "$@"; do
        if [ ! -e "$target" ]; then
            echo "WARNING: Target does not exist: $target" >&2
            all_good=false
        elif ! check_file_ownership "$target"; then
            echo "ERROR: Target not owned by current user: $target" >&2
            all_good=false
        fi
    done
    
    if [ "$all_good" = true ]; then
        return 0
    else
        return 1
    fi
}

# Export functions for use in sourced scripts
export -f check_file_ownership enforce_file_ownership verify_all_ownership