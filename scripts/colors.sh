#!/usr/bin/env bash

# shellcheck disable=SC2155,SC2034

source ./codes.sh

shopt -s extglob

# [internal constant, do not change]
declare __colors_RESET='\e[0m'
# [internal constant, do not change]
declare __colors_IDENTIFIER='\e[33m'
# [internal constant, do not change]
declare __colors_VALUE='\e[32m'

declare -a __colors_NAMES=(black red green yellow blue purple cyan white)
# shellcheck disable=SC2207
declare -a __colors_BASE_CODES=($(seq 30 37))

# [internal function, do not change]
__colors_get_color_base_code() {
    declare in_name="$1"

    declare index=0
    declare name=

    for name in "${__colors_NAMES[@]}"; do
        [[ "$name" == "$in_name" ]] && {
            echo -n "${__colors_BASE_CODES[index]}"
            return $codes_SUCCESS
        }
        (( index++ ))
    done

    return $codes_INVALID_ARGUMENT_ERROR
}

# [internal function, do not change]
__colors_get_color_name() {
    declare in_code="$1"

    declare index=0
    declare code=

    for code in "${__colors_BASE_CODES[@]}"; do
        [[ "$code" == "$in_code" ]] && {
            echo -n "${__colors_NAMES[index]}"
            return $codes_SUCCESS
        }
        (( index++ ))
    done

    return $codes_INVALID_ARGUMENT_ERROR
}

# [internal function, do not change]
__colors_throw_as_already_used_flag() {
    declare flag="$1"

    printf "$__colors_IDENTIFIER%s$__colors_RESET was already used before\n" "$flag" >&2
    return $codes_INVALID_OPTION_ERROR
}

# [internal function, do not change]
__declare_throw_as_unknown_option() {
    declare option="$1"

    printf "$__colors_IDENTIFIER%s$__colors_RESET is not known\n" "$option" >&2
    return $codes_INVALID_OPTION_ERROR
}

# [internal function, do not change]
__declare_throw_if_invalid_color() {
    declare option="$1"
    declare argument="$2"

    __colors_get_color_base_code "$argument" >/dev/null || {
        printf "$__colors_IDENTIFIER%s$__colors_RESET has an invalid color $__colors_VALUE%s$__colors_RESET\n" "$option" "$argument" >&2
        return $codes_INVALID_ARGUMENT_ERROR
    }
    return $codes_SUCCESS
}

# Obtain ANSI color sequence
# Signature: colors_to_ansi {options}
#
# Where {options} is a sequence of unique options:
#   --foreground | -f {color} set a foreground color
#   --background | -b {color} set a background color
#   --intensive-foreground | -if use brighter foreground color
#   --intensive-background | -ib use brighter background color
#   --intensive | -i use both intensive and foreground and background colors
#   --bold make font bold
#   --italic make font italic
#   --underline make font underlined
#   --overline make font overlined
#   --reset | -r back to default
#
# Where {color} is one of:
#   black | red | green | yellow | blue | purple | cyan | white
colors_to_ansi() {
    declare code='\e['

    declare is_foreground_met=false
    declare is_background_met=false
    declare is_bold_met=false
    declare is_italic_met=false
    declare is_intensive_foreground_met=false
    declare is_intensive_background_met=false
    declare is_intensive_met=false
    declare is_underline_met=false
    declare is_overline_met=false
    declare is_strikethrough_met=false
    declare is_reset_met=false

    declare foreground=""
    declare background=""

    while [[ $# -gt 0 ]]
    do
        declare option="$1"
        declare argument="$2"

        case "$option" in
            --foreground | -f)
                [[ $is_foreground_met == true ]] && {
                    __colors_throw_as_already_used_flag '--foreground | -f' || return
                }
                __declare_throw_if_invalid_color '--foreground | -f' "$argument" || return

                is_foreground_met=true
                foreground="$argument"
                shift
                ;;
            --background | -b)
                [[ $is_background_met == true ]] && {
                    __colors_throw_as_already_used_flag '--background | -b' || return
                }
                __declare_throw_if_invalid_color '--background | -b' "$argument" || return

                is_background_met=true
                background="$argument"
                shift
                ;;
            --intensive-foreground | -if)
                [[ $is_intensive_foreground_met == true ]] && __colors_throw_as_already_used_flag '--intensive-foreground | -if'
                is_intensive_foreground_met=true
                ;;
            --intensive-background | -ib)
                [[ $is_intensive_background_met == true ]] && __colors_throw_as_already_used_flag '--intensive-background | -ib'
                is_intensive_background_met=true
                ;;
            --intensive | -i)
                [[ $is_intensive_met == true ]] && __colors_throw_as_already_used_flag '--intensive | -i'
                
                is_intensive_met=true
                is_intensive_foreground_met=true
                is_intensive_background_met=true
                ;;

            --bold)
                [[ $is_bold_met == true ]] && __colors_throw_as_already_used_flag '--bold'
                is_bold_met=true
                ;;
            --italic)
                [[ $is_italic_met == true ]] && __colors_throw_as_already_used_flag '--italic'
                is_italic_met=true
                ;;
            --underline)
                [[ $is_underline_met == true ]] && __colors_throw_as_already_used_flag '--underline'
                is_underline_met=true
                ;;
            --overline)
                [[ $is_overline_met == true ]] && __colors_throw_as_already_used_flag '--overline'
                is_overline_met=true
                ;;
            --strikethrough)
                [[ $is_strikethrough_met == true ]] && __colors_throw_as_already_used_flag '--strikethrough'
                is_strikethrough_met=true
                ;;
            --reset | -r)
                [[ $is_reset_met == true ]] && __colors_throw_as_already_used_flag '--reset | -r'
                
                is_reset_met=true
                ;;
            *)
                __declare_throw_as_unknown_option "$option" || return
                ;;
        esac

        shift
    done

    [[ "$is_reset_met" == true ]] && {
        # shellcheck disable=SC2028
        echo '\e[0m'
        return $codes_SUCCESS
    }

    [[ "$is_foreground_met" == true ]] && foreground="$(__colors_get_color_base_code "$foreground")"
    [[ "$is_background_met" == true ]] && background="$(( $(__colors_get_color_base_code "$background") + 10))"

    [[ "$is_intensive_foreground_met" == true ]] && foreground="$(( foreground + 60 ))"
    [[ "$is_intensive_background_met" == true ]] && background="$(( background + 60 ))"

    declare -a codes=()
    [[ -n "$foreground" ]] && codes+=("$foreground")
    [[ -n "$background" ]] && codes+=("$background")

    [[ "$is_bold_met" == true ]] && codes+=(1)
    [[ "$is_italic_met" == true ]] && codes+=(3)
    [[ "$is_underline_met" == true ]] && codes+=(4)
    [[ "$is_overline_met" == true ]] && codes+=(53)
    [[ "$is_strikethrough_met" == true ]] && codes+=(9)

    IFS=";" ; code="${code}${codes[*]}m"
    printf '%s' "$code"
}

# Convert ANSI color sequence to colors_to_ansi call
# Signature: colors_from_ansi {ansi_sequence}
#
# Where {ansi_sequence} is a sequence in the following format:
# \e[{code1;code2,...}m
# 
# Where {code*} is one of:
#   30..37: foreground colors
#   40..47: background colors
#   90..97: bright foreground colors
#   100..107: bright foreground colors
#   1: make font bold
#   3: make font italic
#   4: make font underlined
#   53: make font overlined
#   9: make font strikethrough
colors_from_ansi() {
    declare input="$1"
    # shellcheck disable=SC2155
    declare stripped="$(echo -n "$input" | sed --regexp-extended 's/^\\e\[|m$//g')"

    [[ -z "$input" ]] && {
        # shellcheck disable=SC2059
        printf "Input sequence doesn't contain anything\n" >&2
        return $codes_INVALID_ARGUMENT_ERROR
    }
    [[ "$input" == "$stripped" ]] && {
        # shellcheck disable=SC2059
        printf "Input sequence doesn't start with $__colors_IDENTIFIER\\\e$__colors_RESET or doesn't end with ${__colors_IDENTIFIER}m$__colors_RESET\n" >&2
        return $codes_INVALID_ARGUMENT_ERROR
    }

    IFS=";" read -r -a codes <<< "$stripped"
    # shellcheck disable=SC2207
    declare -a codes=($(echo "${codes[@]}" | sort --unique | sed 's/ /\n/g'))
    declare command_line=""

    declare is_intensive_foreground_met=false
    declare is_intensive_background_met=false

    for code in "${codes[@]}"; do
        [[ "$code" != +([[:digit:]]) ]] && {
            printf "$__colors_VALUE%s$__colors_RESET is not a number\n" "$code" >&2
            return $codes_INVALID_ARGUMENT_ERROR
        }

        case "$code" in
            1)
                command_line="${command_line} --bold"
                ;;
            3)
                command_line="${command_line} --italic"
                ;;
            4)
                command_line="${command_line} --underline"
                ;;
            53)
                command_line="${command_line} --overline"
                ;;
            9)
                command_line="${command_line} --strikethrough"
                ;;
            3*)
                command_line="${command_line} --foreground $(__colors_get_color_name "$code")"
                ;;
            4*)
                command_line="${command_line} --background $(__colors_get_color_name "$(( code - 10 ))")"
                ;;
            9*)
                command_line="${command_line} --foreground $(__colors_get_color_name "$(( code - 60 ))")"
                is_intensive_foreground_met=true
                ;;
            10*)
                command_line="${command_line} --background $(__colors_get_color_name "$(( code - 70 ))")"
                is_intensive_background_met=true
                ;;
            *)
                command ...
                ;;
        esac
    done

    if [[ $is_intensive_foreground_met == true ]] && [[ $is_intensive_background_met == true ]]; then
        command_line="--intensive ${command_line}"
    elif [[ $is_intensive_foreground_met == true ]]; then
        command_line="--intensive-foreground ${command_line}"
    elif [[ $is_intensive_background_met == true ]]; then
        command_line="--intensive-background ${command_line}"
    fi

    echo -n "$command_line" | sed --regexp-extended 's/\s\s+/ /g; s/^\s*//'
}

# shellcheck disable=SC2034
declare colors_EXAMPLE="$(colors_to_ansi --intensive-foreground --background green --foreground white --bold)"
declare colors_SPECIAL_CHARACTER="$(colors_to_ansi --foreground red --bold)"
declare colors_PLACEHOLDER="$(colors_to_ansi --foreground cyan)"
declare colors_COMMAND="$(colors_to_ansi --foreground cyan)"
declare colors_OPTION="$(colors_to_ansi --foreground yellow)"
declare colors_HEADER="$(colors_to_ansi --foreground green)"
declare colors_FIX_LABEL="$(colors_to_ansi --intensive-foreground --background green --foreground white --bold)"
declare colors_FIX_PREFIX="$(colors_to_ansi --intensive-foreground --background green --foreground white --bold)"

declare colors_RESET="$(colors_to_ansi --reset)"
