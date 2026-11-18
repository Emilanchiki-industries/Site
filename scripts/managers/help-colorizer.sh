#!/usr/bin/env sh

# shellcheck disable=SC2120

program=$(echo "$0" | sed -E 's|.*/||')
configuration="$(mktemp)"

success=0
invalid_option=1
invalid_option_argument=2
invalid_theme_key=3
invalid_theme_key_value=4

configuration_header_color=green
configuration_bold_color=cyan
configuration_italic_color="$configuration_bold_color"
configuration_options_color="$configuration_bold_color"
configuration_placeholders_color=yellow

configuration_header_enable=true
configuration_bold_enable=true
configuration_italic_enable=true
configuration_options_enable=true
configuration_placeholders_enable=true

reset='\e[0m'

cli='--help -h print this help message
--version -v print a version of this program
--options -O print parsable list of options in {long}|{short} format per line
--codes -C print parsable list of codes in {code} format per line
--keys -K print parsable list of configuration option in {option} format per line
--disable -d {headers,bold,italic,options,placeholders} disable highlighting for specified items
--completion -c generate bash completion
--theme -t specify theme file to use
--header -h specify header color (override theme preference)
--bold -b specify bold color (override theme preference)
--italic -i specify italic color (override theme preference)
--options -o specify options color (override theme preference)
--placeholders -p specify placeholders color (override theme preference)'

codes='0 successfull execution
1 invalid option
2 invalid option argument
3 invalid theme key
4 invalid theme key value'

# Signature: {input} | color -> {colored output}
# [pipeline filter]
color() {
    __color__in_text="$(cat </dev/stdin)"

    # shellcheck disable=SC2059
    printf "$(echo "$__color__in_text" |
        sed 's/\(--\?[a-z]\+ \| --\?[a-z]\+\)/\\e[36m\1\\e[0m/g' |
        sed 's/\({[a-z]\+}\)/\\e[33m\1\\e[0m/g' |
        sed 's/#\+ \(.\+\)/\\e[32m\1\\e[0m/g')\n" 
}

# Signature: {input} | highlight -> {colored output}
# [pipeline filter]
highlight() {
    __highlight__in_text="$(cat </dev/stdin)"

    __highlight__color='\e[36m'
    printf "$__highlight__color%s$reset" "$__highlight__in_text"
}

# Signature: {input} | error -> {colored output}
# [pipeline filter]
error() {
    __error__in_error="$(cat </dev/stdin)"

    __error__color='\e[31m'
    printf "${__error__color}%s$reset\n" "$__error__in_error" >&2
}

# Signature: {input} | append {text} -> {input}{text}
# [pipeline filter]
append() {
    __append__in_input="$(cat </dev/stdin)"
    __append__in_text="$1"

    printf "%s%s" "$__append__in_input" "$__append__in_text"
}

# Signature: configuration_initialize
configuration_initialize() {
    echo "# Default theme
header=$configuration_header_color
bold=$configuration_bold_color
italic=$configuration_italic_color
options=$configuration_options_color
placeholders=$configuration_placeholders_color

header_enable=$configuration_header_enable
bold_enable=$configuration_bold_enable
italic_enable=$configuration_italic_enable
options_enable=$configuration_options_enable
placeholders_enable=$configuration_placeholders_enable" >"$configuration"
}

# Signature: configuration -> {default configuration}
# Signature: configuration {configuration path} -> {custom configuration}
# [pipeline starter]
configuration() {
    __configuration__in_path="$1"

    if [ -z "$__configuration__in_path" ]; then
        cat "$configuration"
    else
        cat "$__configuration__in_path"
    fi
}

# Signature: {configuration content} | configuration_remove_comments -> {configuration with removed comments}
# [pipline filter]
configuration_remove_comments() {
    cat </dev/stdin | sed 's/ *#.\{1,\}//g'
}

# Signature: {configuration content} | configuration_format -> {formatted configuration}
# [pipline filter]
configuration_format() {
    cat </dev/stdin | sed 's/^ \{1,\}//; s/ \{1,\}$//; s/ *= */=/'
}

# Signature: {configuration content} | configuration_clean -> {cleaned configuration}
# [pipline starter | pipline filter]
configuration_clean() {
    cat </dev/stdin | configuration_remove_comments | configuration_format
}

# Signature: {configuration content} | configuration_save
# Signature: {configuration content} | configuration_save {custom configuration path}
# [pipeline closer]
configuration_save() {
    __configuration_save__in_path="$1"

    if [ -z "$__configuration_save__in_path" ]; then
        cat </dev/stdin | tee "$configuration" >/dev/null
    else
        cat </dev/stdin | tee "$__configuration_save__in_path" >/dev/null
    fi
}

# Signature: {configuration content} | configuration_get {key} -> {configuration key value}
# [pipeline filter]
configuration_get() {
    __configuration_get__in_key="$1"

    cat </dev/stdin |
        configuration_clean |
        command grep -F "$__configuration_get__in_key" |
        sed 's/[^=]\{1,\}=//'
}

# Signature: {configuration content} | get_configuration_keys -> {configuration keys one per line}
# [pipeline filter]
get_configuration_keys() {
    __get_configuration_keys__in_configuration="$1"

    cat </dev/stdin |
        configuration_clean |
        sed '/=/ s/=[^=]\{1,\}//; /^$/d'
}

# Signature: configuration_is_valid_color_key {key}
# [condition checker]
configuration_is_valid_color_key() {
    __configuration_is_valid_color_key__in_key="$1"

    [ "$__configuration_is_valid_color_key__in_key" = header ] ||
    [ "$__configuration_is_valid_color_key__in_key" = bold ] ||
    [ "$__configuration_is_valid_color_key__in_key" = italic ] ||
    [ "$__configuration_is_valid_color_key__in_key" = options ] ||
    [ "$__configuration_is_valid_color_key__in_key" = placeholders ]
}

# Signature: configuration_is_valid_switch_key {key}
# [condition checker]
configuration_is_valid_switch_key() {
    __configuration_is_valid_switch_key__in_key="$1"

    [ "$__configuration_is_valid_color_key__in_key" = header_enable ] ||
    [ "$__configuration_is_valid_color_key__in_key" = bold_enable ] ||
    [ "$__configuration_is_valid_color_key__in_key" = italic_enable ] ||
    [ "$__configuration_is_valid_color_key__in_key" = options_enable ] ||
    [ "$__configuration_is_valid_color_key__in_key" = placeholders_enable ]
}

# Signature: configuration_is_valid_key {key}
# [condition checker]
configuration_is_valid_key() {
    __configuration_is_valid_key__in_key="$(cat </dev/stdin)"

    echo "$__configuration_is_valid_key__in_key" | configuration_is_valid_color_key ||
        echo "$__configuration_is_valid_key__in_key" | configuration_is_valid_switch_key
}

# Signature: {configuration content} | configuration_is_valid -> {invalid keys one per line}
# [pipeline closer, condition checker]
configuration_is_valid() {
    __configuration_is_valid__result="$(mktemp)"
    echo true > "$__configuration_is_valid__result"

    cat </dev/stdin | while read -r key; do
        echo "$key" | configuration_is_valid_key || {
            echo "$key"
            echo false > "$__configuration_is_valid__result"
        }
    done

    if [ "$(cat "$__configuration_is_valid__result")" = true ]; then
        return "$success"
    else
        return "$invalid_theme_key"
    fi
}

# Signature: {configuration content} | configuration_set {key} {value} -> {updated configuration}
# [pipeline filter]
configuration_set() {
    __configuration_set__in_key="$1"
    __configuration_set__in_value="$2"

    if ! echo "$__configuration_set__in_key" | configuration_is_valid_key; then
        highlight "$__configuration_set__in_key"
        printf ': '
        error "invalid key, expected one of: $(get_configuration_keys | into_one_line)"
        return "$invalid_theme_key"
    fi

    configuration_clean | sed "/$__configuration_set__in_key/ s/=.*/=$__configuration_set__in_value/"
}

# Signagure: get_codes -> {codes one per line}
# [pipeline starter]
get_codes() {
    echo "$codes" | sed 's/^\(.\).*/\1/g'
}

# Signagure: get_cli_options -> {cli options one per line}
# [pipeline starter]
get_cli_options() {
    echo "$cli" | sed 's/\(--[^ -]\+\) \(-[^ -]\) .\{1,\}/\1|\2/g'
}

# Signagure: {input} | into_one_line -> {input items joined via comma}
# [pipeline filter]
into_one_line() {
    cat </dev/stdin | tr '\n' ' ' | sed 's/ $//; s/ /, /g'
}

# Signagure: {input} | into_several_lines -> {input items spreaded into several lines}
# [pipeline filter]
into_several_lines() {
    cat </dev/stdin | sed 's/,/\n/g; s/^[[:space:]]\{1,\}//g; s/[[:space:]]\{1,\}$//g;'
}

# Signagure: help -> {help text}
# [pipeline starter]
help() {
    echo "# Description
A utility to perform simple Regex-based colorization of your input

# Reason
Programs often output their --help | -h message without any colors which can be hard to read

# CLI
$cli

# Codes
$codes

# Examples
grep --help | $program --theme {path}: color grep help
grep --help | $program --options {color_code}: color grep help

# Contacts
EmilyGraceSeville7cfg@gmail.com - program author email" | color
}

configuration_initialize

while [ $# -gt 0 ]; do
    option="$1"
    argument="$2"

    case "$option" in
    --help | -h | help\?)
        help
        exit "$success"
    ;;

    --version | -v | version\?)
        echo 1.0.0
        exit "$success"
    ;;

    --options | -O | options\?)
        get_cli_options
        exit "$success"
    ;;

    --codes | -C | codes\?)
        get_codes
        exit "$success"
    ;;

    --keys | -K | keys\?)
        configuration | get_configuration_keys
        exit "$success"
    ;;

    --disable | -d | disable:)
        filter="$argument"
        filter="$(echo "$filter" | into_several_lines)"

        echo "$filter" | while read -r key; do
            if ! configuration_is_valid_color_key "$key";  then
                echo "$key" | highlight | append ': '
                echo "an invalid target, expected one of: $(configuration | get_configuration_keys | grep -v enable | into_one_line)" | error
                exit "$invalid_option_argument"
            fi

            [ "$key" = header ] && configuration_set header_enable false | configuration_save
            [ "$key" = bold ] && configuration_set bold_enable false | configuration_save
            [ "$key" = italic ] && configuration_set italic_enable false | configuration_save
            [ "$key" = options ] && configuration_set options_enable false | configuration_save
            [ "$key" = placeholders ] && configuration_set placeholders_enable false | configuration_save
        done || exit
        shift
    ;;

    --theme | -t | theme:)
        theme="$argument"

        [ -f "$theme" ] || {
            echo "$theme" | highlight | append ': '
            echo "a theme specified by --theme|-t doesn't exist currently" | error
            exit "$invalid_option_argument"
        }

        invalid_keys="$(configuration "$theme" | configuration_is_valid)"
        # shellcheck disable=SC2181
        [ $? -ne 0 ] && {
            echo "$theme" | highlight | append ': '
            echo "a theme specified by --theme|-t contains these unsupported options: $(echo "$invalid_keys" | into_one_line)" | error
            exit "$invalid_option_argument"
        }
        shift
    ;;

    *)
        highlight "$option"
        printf ': '
        error "an invalid option, expected one of: $(get_cli_options | into_one_line)"
        exit "$invalid_option"
    ;;
    esac

    shift
done