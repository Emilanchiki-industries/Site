#!/usr/bin/env sh

program=$(echo "$0" | sed -E 's|.*/||')
reset='\e[0m'

cli='--help | -h print this help message
--version | -v print a version of this program
--cli | -c print available options in a parsable {long},{short},{description} format without coloring
--from | -f a directory to input files
--to | -t a directory where to put symlinks for --from|-f files
--pattern | -p create symlinks only for files matching this grep pattern, otherwise for none'

color() {
    __color_in_text="$1"

    # shellcheck disable=SC2059
    printf "$(echo "$__color_in_text" |
        sed 's/\(--\?[a-z]\+ \| --\?[a-z]\+\)/\\e[36m\1\\e[0m/g' |
        sed 's/\({[a-z]\+}\)/\\e[33m\1\\e[0m/g' |
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
A utility to create symlinks into a specific folder to enable access to downloaded files

# Reason
Programs can struggle loading large collections of downloaded files at once that's why it's usefule to selectively load files which are already available for offline usage

# CLI
$cli

# Examples
$program --from {directory} --to {directory} --pattern {pattern}: symlink input files from the target directory"
}

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

    -f | --from)
        [ -d "$argument" ] || {
            highlight "$argument"
            printf ': '
            error "an input directory specified by --from|-f doesn't exist currently"
            exit 1
        }

        from="$argument"
        shift
        ;;

    -t | --to)
        [ -d "$argument" ] || {
            highlight "$argument"
            printf ': '
            error "a target directory specified by --to|-t doesn't exist currently"
            exit 1
        }

        to="$argument"
        shift
        ;;

    -p | --pattern)
        message="$(echo | command grep -q "$argument" 2>&1)" || {
            [ $? -eq 2 ] && {
                highlight "$argument"
                printf ': '
                error "invalid grep regular expression specified by --pattern|-p as there is an error like $(echo "$message" | sed 's|grep: ||' | tr '[:upper:]' '[:lower:]')"
                exit 1
            }
        }

        pattern="$argument"
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

for input_path in "$from"/*; do
    input_file="$(basename "$input_path")"
    echo "$input_file" | grep -q "$pattern" && {
        highlight "$input_file"
        
        # shellcheck disable=SC2015
        if ln -s "$input_path" "$to/$input_file" 2> /dev/null; then
            printf ': matched, created symlink in %s\n' "$to"
        else
            printf ': '
            error "symlink $to/$input_file already exists for this file"
        fi
    }
done
