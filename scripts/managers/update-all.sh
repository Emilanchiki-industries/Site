#!/usr/bin/env sh

program=$(echo "$0" | sed -E 's|.*/||')
reset='\e[0m'

failed_commands=""
update_applications=false
update_repositories=true

configuration="$(mktemp)"

cli='--help | -h print this help message
--version | -v print a version of this program
--just | -j {applications|repositories} update just what is requested (applications or repositories)
--repositories | -r a path to a directory with repositories to update'

initialize_configuration() {
    echo "update_applications=$update_applications
update_repositories=$update_repositories" >"$configuration"
}

get_configuration_key() {
    __get_configuration_key_in_key="$1"
    command grep -F "$__get_configuration_key_in_key" "$configuration" | sed 's/^.\+\=//'
}

set_configuration_key() {
    __set_configuration_key_in_key="$1"
    __set_configuration_key_in_value="$2"
    sed "/$__set_configuration_key_in_key/ s/=.\+/=$__set_configuration_key_in_value/" "$configuration" |
        tee "$configuration" >/dev/null
}

color() {
    __color_in_text="$1"

    # shellcheck disable=SC2059
    printf "$(echo "$__color_in_text" |
        sed 's/*\([a-z-]\+\)*/\\e[36m\1\\e[0m/g' |
        sed 's|\(\(/[0-9A-Za-z._-]\+\)\+/\?\)|\\e[32m\1\\e[0m|g' |
        sed 's/\(^--\?[a-z]\+ \| --\?[a-z]\+ \| --\?[a-z]\+$\)/\\e[36m\1\\e[0m/g' |
        sed 's/\({[a-z|]\+}\)/\\e[33m\1\\e[0m/g' |
        sed 's/#\+ \(.\+\)/\\e[32m\1\\e[0m/g')\n" 
}

highlight() {
    __highlight_in_text="$1"

    __highlight_color='\e[36m'
    printf "$__highlight_color%s$reset" "$__highlight_in_text"
}

error() {
    __error_in_error="$1"

    __error_color='\e[31m'
    printf "$__error_color%s$reset\n" "$__error_in_error" >&2
}

help() {
    color "# Description
A utility to update your applications and git repositories

# Reason
It can be tedious to manage apps through different package managers and build your own up-to-date learning base from Git repositories

# CLI
$cli

# Examples
$program --repositories {path}: update not only all apps but also repositories inside specified directory"
}

run_if_exists() {
    __exists_append_sudo=false

    if [ "$1" = sudo ]; then
        __exists_in_binary="$2"
        __exists_append_sudo=true
        shift
    else
        __exists_in_binary="$1"
    fi
    shift

    command -v "$__exists_in_binary" > /dev/null && {
        if [ "$__exists_append_sudo" = true ]; then
            # shellcheck disable=SC2024
            sudo "$__exists_in_binary" "$@" > "$log" 2> "$log" || failed_commands="$failed_commands, @$__exists_in_binary"
        else
            "$__exists_in_binary" "$@" > "$log" 2> "$log" || failed_commands="$failed_commands, @$__exists_in_binary"
        fi
    }
}

deb_package_update_count() {
    apt-get -q -y --ignore-hold --allow-change-held-packages --allow-unauthenticated -s dist-upgrade |
        grep -c ^Inst
}

flatpak_package_update_count() {
    flatpak remote-ls --updates |
        sed '1d' | wc -l
}

if [ "$(id -u)" -ne 0 ]; then
    error "this program expects to be run as root, for instance via sudo"
    exit 1
fi

initialize_configuration

while [ $# -gt 0 ]; do
    option="$1"
    argument="$2"

    case "$option" in
    -h | --help)
        help
        exit
        ;;

    -v | --version)
        printf 1.0.0
        exit
        ;;

    -c | --cli)
        echo "$cli" | sed 's/\(--[^ -]\+\) | \(-[^ -]\) \(.\+\)/\1,\2,\3/g'
        exit
        ;;

    -r | --repositories)
        [ -d "$argument" ] || {
            highlight "$argument"
            printf ': '
            error "an input directory specified by --repositories|-r doesn't exist currently"
            exit 1
        }

        repositories="$argument"
        shift
        ;;

    -j | --just)
        filter="$argument"
        filter="$(echo "$filter" | sed 's/,/\n/g; s/^ \+\| \+$//g')"

        echo "$filter" | while read -r line; do
            if [ "$line" != applications ] && [ "$line" != repositories ]; then
                highlight "$line"
                printf ': '
                error 'invalid target, expected one of: applications, repositories'
                exit 1
            fi

            [ "$line" = applications ] && set_configuration_key update_applications true
            [ "$line" = repositories ] && set_configuration_key update_repositories true
        done
        shift
        ;;

    *)
        highlight "$option"
        printf ': '
        error "invalid option, expected one of: $(echo "$cli" |
            sed 's/\(--[^ -]\+\) | \(-[^ -]\) .\+/\1|\2/g' | tr '\n' ' ' | sed 's/\([a-z]\) \(-\)/\1, \2/g')"
        exit 1
        ;;
    esac

    shift
done

update_applications="$(get_configuration_key update_applications)"
update_repositories="$(get_configuration_key update_repositories)"

log="$(mktemp)"
color "Created a temporary log file $log for commands run further like *apt*"
echo

[ "$update_applications" = true ] && {
    color 'Trying to update debian packages via *apt*...'
    run_if_exists sudo apt update -y
    updatable="$(deb_package_update_count)"
    if [ "$updatable" = 0 ]; then
        color 'There is nothing to update with *apt*'
    else
        color "$updatable will be updated via *apt*"
        run_if_exists sudo apt upgrade -y
    fi
    echo

    color 'Trying to update flatpak packages via *flatpak...'
    updatable="$(flatpak_package_update_count)"
    if [ "$updatable" = 0 ]; then
        color 'There is nothing to update with *flatpak'
    else
        color "$updatable can will be updated via *flatpak"
        run_if_exists flatpak update -y
    fi
    echo

    color 'Trying to update snap packages via via *snap*...'
    run_if_exists sudo snap refresh
    echo

    color 'Trying to update rust version manager alongwith Rust toolchains via *rustup*...'
    run_if_exists rustup update
    echo
}

[ "$update_repositories" = true ] && {
    [ -z "$repositories" ] && {
        error 'cannot update repositories when --repositories|-r is not specified'
        exit 1
    }

    color "Trying to update repositories in $repositories via *git-pull*..."
    for repository in "$repositories"/*; do
        (
            cd "$repository" || {
                highlight "$repository"
                printf ': '
                error "can't update"
            }
        ) || continue

        color "Trying to update *$(basename "$repository")* via *git-pull*..."
        branches="$(git branch --no-color)"
        if echo "$branches" | grep -q main; then 
            git switch -q main | tee "$log" > /dev/null 2> /dev/null
        elif echo "$branches" | grep -q master; then
            git switch -q master | tee "$log" > /dev/null 2> /dev/null
        else
            error "there is no main or master branch found"
        fi

        git pull | tee "$log" > /dev/null 2> /dev/null
    done
}