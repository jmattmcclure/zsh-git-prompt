# To install source this file from your .zshrc file

export GIT_PROMPT_EXECUTABLE=${GIT_PROMPT_EXECUTABLE:-"python"}  

if [ -n "$ZSH_VERSION" ]; then
    # Always has path to this directory
    # A: finds the absolute path, even if this is symlinked
    # h: equivalent to dirname
    export __GIT_PROMPT_DIR=${0:A:h}
elif [ -n "$BASH_VERSION" ]; then
    export __GIT_PROMPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
else
    export __GIT_PROMPT_DIR=$(dirname "$(readlink -f "$0")")
fi

# see documentation at http://linux.die.net/man/1/zshexpn
preexec_update_git_vars() {
    case "$2" in
    git*|hub*|gh*|stg*)
        __EXECUTED_GIT_COMMAND=1
        ;;
    esac
}

precmd_update_git_vars() {
    if [ -n "$__EXECUTED_GIT_COMMAND" ] || [ ! -n "$ZSH_THEME_GIT_PROMPT_CACHE" ]; then
        update_current_git_vars
        unset __EXECUTED_GIT_COMMAND
    fi
}

chpwd_update_git_vars() {
    update_current_git_vars
}

# https://unix.stackexchange.com/a/331490/153926
dynamic_assign() { 
    eval "$1"=\"\$2\"
}

update_current_git_vars() {
    unset __CURRENT_GIT_STATUS

    if [ "$GIT_PROMPT_EXECUTABLE" = "python" ]; then
        local py_bin=${ZSH_GIT_PROMPT_PYBIN:-"python"}
        __GIT_CMD() {
            git status --porcelain --branch 2>/dev/null | ZSH_THEME_GIT_PROMPT_HASH_PREFIX=$ZSH_THEME_GIT_PROMPT_HASH_PREFIX $py_bin "$__GIT_PROMPT_DIR/python/gitstatus.py"
        }
    else
        __GIT_CMD() {
            git status --porcelain --branch &> /dev/null | $__GIT_PROMPT_DIR/haskell/.bin/gitstatus
        }
    fi

    local has_stderr=false

    while IFS= read -r line; do 
        if [ "$line" = "" ]; then
            continue
        elif [[ "$line" =~ GIT_*=* ]]; then
            local VAR=${line%% *}
            local ARG=${line#* }
            dynamic_assign "$VAR" "$ARG"
        elif [ "$__GIT_PROMPT_DEBUG" = "yes" ]; then
            has_stderr=true
            echo "__git_cmd: $line"
        fi
    done < <(__GIT_CMD 2>&1)
 
    if $has_stderr; then
        echo "Unexpected output. Check the lines starting with __git_cmd:"
    fi

    unset __GIT_CMD
}

git_super_status() {
    precmd_update_git_vars


    if [ -n "$GIT_IS_REPOSITORY" ]; then
        local STATUS="$ZSH_THEME_GIT_PROMPT_PREFIX$ZSH_THEME_GIT_PROMPT_BRANCH$GIT_BRANCH%{${reset_color}%}"
        local clean=1

        if [ -n "$GIT_REBASE" ] && [ "$GIT_REBASE" != "0" ]; then
            STATUS="$STATUS$ZSH_THEME_GIT_PROMPT_REBASE$GIT_REBASE%{${reset_color}%}"
        elif [ "$GIT_MERGING" != "0" ]; then
            STATUS="$STATUS$ZSH_THEME_GIT_PROMPT_MERGING%{${reset_color}%}"
        fi

        if [ "$GIT_LOCAL_ONLY" != "0" ]; then
            STATUS="$STATUS$ZSH_THEME_GIT_PROMPT_LOCAL%{${reset_color}%}"
        elif [[ "$ZSH_GIT_PROMPT_SHOW_UPSTREAM" -gt "0" ]] && [ -n "$GIT_UPSTREAM" ] && [ "$GIT_UPSTREAM" != ".." ]; then
            local parts=( "${(s:/:)GIT_UPSTREAM}" )
            if [ "$ZSH_GIT_PROMPT_SHOW_UPSTREAM" -eq "2" ] && [ "$parts[2]" = "$GIT_BRANCH" ]; then
                GIT_UPSTREAM="$parts[1]"
            fi
            STATUS="$STATUS$ZSH_THEME_GIT_PROMPT_UPSTREAM_FRONT$GIT_UPSTREAM$ZSH_THEME_GIT_PROMPT_UPSTREAM_END%{${reset_color}%}"
        fi

        if [ "$GIT_BEHIND" != "0" ] || [ "$GIT_AHEAD" != "0" ]; then
            STATUS="$STATUS "
        fi
        if [ "$GIT_BEHIND" != "0" ]; then
            STATUS="$STATUS$ZSH_THEME_GIT_PROMPT_BEHIND$GIT_BEHIND%{${reset_color}%}"
        fi
        if [ "$GIT_AHEAD" != "0" ]; then
            STATUS="$STATUS$ZSH_THEME_GIT_PROMPT_AHEAD$GIT_AHEAD%{${reset_color}%}"
        fi

        STATUS="$STATUS$ZSH_THEME_GIT_PROMPT_SEPARATOR"

        if [ "$GIT_STAGED" != "0" ]; then
            STATUS="$STATUS$ZSH_THEME_GIT_PROMPT_STAGED$GIT_STAGED%{${reset_color}%}"
            clean=0
        fi
        if [ "$GIT_CONFLICTS" != "0" ]; then
            STATUS="$STATUS$ZSH_THEME_GIT_PROMPT_CONFLICTS$GIT_CONFLICTS%{${reset_color}%}"
            clean=0
        fi
        if [ "$GIT_CHANGED" != "0" ]; then
            STATUS="$STATUS$ZSH_THEME_GIT_PROMPT_CHANGED$GIT_CHANGED%{${reset_color}%}"
            clean=0
        fi
        if [ "$GIT_UNTRACKED" != "0" ]; then
            STATUS="$STATUS$ZSH_THEME_GIT_PROMPT_UNTRACKED$GIT_UNTRACKED%{${reset_color}%}"
            clean=0
        fi
        if [ "$GIT_STASHED" != "0" ]; then
            STATUS="$STATUS$ZSH_THEME_GIT_PROMPT_STASHED$GIT_STASHED%{${reset_color}%}"
            clean=0
        fi
        if [ "$clean" = "1" ]; then
            STATUS="$STATUS$ZSH_THEME_GIT_PROMPT_CLEAN%{${reset_color}%}"
        fi

        echo "%{${reset_color}%}$STATUS$ZSH_THEME_GIT_PROMPT_SUFFIX%{${reset_color}%}"
    fi
}


if [ "$1" = "--debug" ]; then
    __GIT_PROMPT_DEBUG="yes"
    git_super_status
    exit
fi

# Load required modules
autoload -U add-zsh-hook
autoload -U colors
colors

# Allow for functions in the prompt
setopt PROMPT_SUBST

# Hooks to make the prompt
add-zsh-hook chpwd chpwd_update_git_vars
add-zsh-hook preexec preexec_update_git_vars
add-zsh-hook precmd precmd_update_git_vars

# Default values for the appearance of the prompt.
# The theme is identical to magicmonty/bash-git-prompt
ZSH_THEME_GIT_PROMPT_PREFIX="["
ZSH_THEME_GIT_PROMPT_SUFFIX="]"
ZSH_THEME_GIT_PROMPT_HASH_PREFIX=":"
ZSH_THEME_GIT_PROMPT_SEPARATOR="|"
ZSH_THEME_GIT_PROMPT_BRANCH="%{$fg_bold[magenta]%}"
ZSH_THEME_GIT_PROMPT_STAGED="%{$fg[red]%}%{●%G%}"
ZSH_THEME_GIT_PROMPT_CONFLICTS="%{$fg[red]%}%{✖%G%}"
ZSH_THEME_GIT_PROMPT_CHANGED="%{$fg[blue]%}%{✚%G%}"
ZSH_THEME_GIT_PROMPT_BEHIND="%{↓·%2G%}"
ZSH_THEME_GIT_PROMPT_AHEAD="%{↑·%2G%}"
ZSH_THEME_GIT_PROMPT_STASHED="%{$fg_bold[blue]%}%{⚑%G%}"
ZSH_THEME_GIT_PROMPT_UNTRACKED="%{$fg[cyan]%}%{…%G%}"
ZSH_THEME_GIT_PROMPT_CLEAN="%{$fg_bold[green]%}%{✔%G%}"
ZSH_THEME_GIT_PROMPT_LOCAL=" L"
# The remote branch will be shown between these two
ZSH_THEME_GIT_PROMPT_UPSTREAM_FRONT=" {%{$fg[blue]%}"
ZSH_THEME_GIT_PROMPT_UPSTREAM_END="%{${reset_color}%}}"
ZSH_THEME_GIT_PROMPT_MERGING="%{$fg_bold[magenta]%}|MERGING%{${reset_color}%}"
ZSH_THEME_GIT_PROMPT_REBASE="%{$fg_bold[magenta]%}|REBASE%{${reset_color}%} "

# vim: filetype=zsh: tabstop=4 shiftwidth=4 expandtab
