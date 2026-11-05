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
__colors_throw_as_already_used_option() {
    declare in_option="$1"

    printf "$__colors_IDENTIFIER%s$__colors_RESET was already used before\n" "$in_option" >&2
    return $codes_INVALID_OPTION_ERROR
}

# [internal function, do not change]
__declare_throw_as_unknown_option() {
    declare in_option="$1"

    printf "$__colors_IDENTIFIER%s$__colors_RESET is not known\n" "$in_option" >&2
    return $codes_INVALID_OPTION_ERROR
}

# [internal function, do not change]
__colors_throw_as_incompatible_options() {
    declare in_option="$1"

    printf "$__colors_IDENTIFIER%s$__colors_RESET is not compatible with other options used\n" "$in_option" >&2
    return $codes_INVALID_OPTION_ERROR
}

# [internal function, do not change]
__colors_throw_as_missing_option() {
    declare in_option="$1"
    declare in_missing_option="$2"

    printf "$__colors_IDENTIFIER%s$__colors_RESET is missing for $__colors_IDENTIFIER%s$__colors_RESET\n" "$in_missing_option" "$in_option" >&2
    return $codes_INVALID_OPTION_ERROR
}

# [internal function, do not change]
__declare_throw_if_invalid_color() {
    declare in_option="$1"
    declare in_argument="$2"

    __colors_get_color_base_code "$in_argument" >/dev/null || {
        printf "$__colors_IDENTIFIER%s$__colors_RESET has an invalid color $__colors_VALUE%s$__colors_RESET\n" "$in_option" "$in_argument" >&2
        return $codes_INVALID_ARGUMENT_ERROR
    }
    return $codes_SUCCESS
}

__colors_check_is_true() {
    declare in_command_line="$1"
    declare in_trim_command="$2"
    declare in_description="$3"

    # shellcheck disable=SC2155
    declare trimmed_command_line="$(echo -n "$in_command_line" | sed --regexp-extended "$in_trim_command")"
    [[ "$in_command_line" == "$trimmed_command_line" ]] || {
        printf "${__colors_IDENTIFIER}hint${__colors_RESET}: %s\n" "$in_description"
        return $codes_INVALID_ARGUMENT_ERROR
    }
    return $codes_SUCCESS
}

__colors_check_is_background_after_foreground() {
    declare in_command_line="$1"
    __colors_check_is_true "$in_command_line" 's/(--background|-b) (--foreground|-f)//' '--background | -b should be placed after --foreground | -f'
}

__colors_check_are_long_options_used() {
    declare in_command_line="$1"
    __colors_check_is_true "$in_command_line" 's/\<-[^-]+\>//' 'long options should be preferred for readability'
}

__colors_check_intensive_is_used_for_brightening_both_foreground_and_background() {
    declare in_command_line="$1"
    __colors_check_is_true "$in_command_line" 's/(--intensive-(fore|back)ground|-i[fb]) (--intensive-(fore|back)ground|-i[fb])//' '--intensive | -i should be used to brighten both foreground and background at once'
}

# Obtain ANSI color sequence
# Signature: colors_to_ansi {options}
#
# Where {options} is a sequence of unique options:
#   --analyze | -a analyze passed options and give advices on a better usage where each recommendation is put on a separate line
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

    declare is_analyze_met=false
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

    declare command_line=""
    declare argument_count="$#"

    while [[ $# -gt 0 ]]
    do
        declare option="$1"
        declare argument="$2"
        command_line="$command_line $option"

        case "$option" in
            --analyze | -a)
                 [[ "$is_analyze_met" == true ]] && {
                    __colors_throw_as_already_used_option '--analyze | -a' || return
                }

                is_analyze_met=true
                ;;
            --foreground | -f)
                 [[ "$is_foreground_met" == true ]] && {
                    __colors_throw_as_already_used_option '--foreground | -f' || return
                }
                __declare_throw_if_invalid_color '--foreground | -f' "$argument" || return

                is_foreground_met=true
                foreground="$argument"
                shift
                ;;
            --background | -b)
                 [[ "$is_background_met" == true ]] && {
                    __colors_throw_as_already_used_option '--background | -b' || return
                }
                __declare_throw_if_invalid_color '--background | -b' "$argument" || return

                is_background_met=true
                background="$argument"
                shift
                ;;
            --intensive-foreground | -if)
                 [[ "$is_intensive_foreground_met" == true ]] && __colors_throw_as_already_used_option '--intensive-foreground | -if'
                is_intensive_foreground_met=true
                ;;
            --intensive-background | -ib)
                 [[ "$is_intensive_background_met" == true ]] && __colors_throw_as_already_used_option '--intensive-background | -ib'
                is_intensive_background_met=true
                ;;
            --intensive | -i)
                 [[ "$is_intensive_met" == true ]] && __colors_throw_as_already_used_option '--intensive | -i'
                
                is_intensive_met=true
                is_intensive_foreground_met=true
                is_intensive_background_met=true
                ;;

            --bold | -B)
                 [[ "$is_bold_met" == true ]] && __colors_throw_as_already_used_option '--bold | -B'
                is_bold_met=true
                ;;
            --italic | -I)
                 [[ "$is_italic_met" == true ]] && __colors_throw_as_already_used_option '--italic | -I'
                is_italic_met=true
                ;;
            --underline | -U)
                 [[ "$is_underline_met" == true ]] && __colors_throw_as_already_used_option '--underline | -U'
                is_underline_met=true
                ;;
            --overline | -O)
                 [[ "$is_overline_met" == true ]] && __colors_throw_as_already_used_option '--overline | -O'
                is_overline_met=true
                ;;
            --strikethrough | -S)
                 [[ "$is_strikethrough_met" == true ]] && __colors_throw_as_already_used_option '--strikethrough | -S'
                is_strikethrough_met=true
                ;;
            --reset | -r)
                 [[ "$is_reset_met" == true ]] && __colors_throw_as_already_used_option '--reset | -r'
                
                is_reset_met=true
                ;;
            *)
                __declare_throw_as_unknown_option "$option" || return
                ;;
        esac

        shift
    done

    if [[ "$is_analyze_met" == false ]] && [[ "$is_reset_met" == true ]] && (( $argument_count > 1 )); then
        __colors_throw_as_incompatible_options '--reset | -r'
        return
    fi

    if [[ "$is_intensive_foreground_met" == true ]] && [[ "$is_foreground_met" == false ]]; then
        __colors_throw_as_missing_option '--intensive-foreground | -if' '--foreground | -f'
        return
    fi

    if [[ "$is_intensive_background_met" == true ]] && [[ "$is_background_met" == false ]]; then
        __colors_throw_as_missing_option '--intensive-background | -ib' '--backgroung | -b'
        return
    fi

    [[ "$is_analyze_met" == true ]] && {
        echo 'Style-related issues are listed below:'
        __colors_check_is_background_after_foreground "$command_line"
        __colors_check_are_long_options_used "$command_line"
        __colors_check_intensive_is_used_for_brightening_both_foreground_and_background "$command_line"
        return $codes_SUCCESS
    }

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
    declare in_ansi_sequence="$1"
    # shellcheck disable=SC2155
    declare stripped="$(echo -n "$in_ansi_sequence" | sed --regexp-extended 's/^\\e\[|m$//g')"

    [[ -z "$in_ansi_sequence" ]] && {
        # shellcheck disable=SC2059
        printf "Input sequence doesn't contain anything\n" >&2
        return $codes_INVALID_ARGUMENT_ERROR
    }
    [[ "$in_ansi_sequence" == "$stripped" ]] && {
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

    if  [[ "$is_intensive_foreground_met" == true ]] && [[ "$is_intensive_background_met" == true ]]; then
        command_line="--intensive ${command_line}"
    elif  [[ "$is_intensive_foreground_met" == true ]]; then
        command_line="--intensive-foreground ${command_line}"
    elif  [[ "$is_intensive_background_met" == true ]]; then
        command_line="--intensive-background ${command_line}"
    fi

    echo -n "$command_line" | sed --regexp-extended 's/\s\s+/ /g; s/^\s*//'
}
