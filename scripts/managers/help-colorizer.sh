#!/usr/bin/env sh

# shellcheck disable=SC2120

program=$(echo "$0" | command sed -E 's|.*/||')
configuration="$(mktemp)"
user_overrides_configuration="$(mktemp)"

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
--options -o print parsable list of options in "{long}|{short}" format per line
--codes -c print parsable list of codes in "{code}" format per line
--just -j print just specific sections of help in the preferred order
--keys -k print parsable list of configuration option in "{option}" format per line
--disable -d {target} disable highlighting for specified items (check # Argument format #)
--completion -C generate bash completion
--theme -t specify theme file to use
--format | -f format a theme file and print formatting result without touching the original theme
--remove-comments | -r remove comments from a theme file file without touching the original theme
--preview -p preview theme file with syntax highlighting
--header-style -H {color} specify header color (override theme preference, check # Argument format #)
--bold-style -b {color} specify bold color (override theme preference, check # Argument format #)
--italic-style -i {color} specify italic color (override theme preference, check # Argument format #)
--options-style -O {color} specify options color (override theme preference, check # Argument format #)
--placeholders-style -P {color} specify placeholders color (override theme preference, check # Argument format #)'

codes='0 a successfull execution
1 an invalid option
2 an invalid option argument
3 an invalid theme key
4 an invalid theme key value'

notation='{placeholder} a placeholder with arbitrary text content resulting in "./theme.ini" e.g.
{first|or} a placeholder with two alternatives "first" and "or" (adding more alternatives is possible via "|") resulting in "first" e.g.
{bold?} text item containing "bold" or nothing
{(first|or) ...} a placeholder {first|or} which can be repeated via one space resulting in "first second" e.g.'

color_format='{bold?} {italic?} {black|red|green|yellow|blue|magenta|cyan|white}'

# Signature: {input} | color_apply -> {colored output}
# [pipeline filter]
color_apply() {
    __color_apply__in_text="$(cat /dev/stdin)"
    __color_apply__option_regex='--\+[A-Za-z-]\{1,\}'
    __color_apply__placeholder_regex='{[A-Za-z0-9_?| .,()]\{1,\}}'
    __color_apply__header_regex='#\{1,\} \(.\{1,\}\) \{1,\}#'
    __color_apply__option_color=36
    __color_apply_placeholder_color=33
    __color_apply_header_color=32

    # shellcheck disable=SC2059
    printf "$(echo "$__color_apply__in_text" |
        command sed "s/ \($__color_apply__option_regex\) / \\\e[${__color_apply__option_color}m\1\\\e[0m /g" |
        command sed "s/^\($__color_apply__option_regex\) /\\\e[${__color_apply__option_color}m\1\\\e[0m /g" |
        command sed "s/ \($__color_apply__option_regex\)$/ \\\e[${__color_apply__option_color}m\1\\\e[0m/g" |
        command sed "s/\($__color_apply__placeholder_regex\)/\\\e[${__color_apply_placeholder_color}m\1\\\e[0m/g" |
        command sed "s/$__color_apply__header_regex/\\\e[${__color_apply_header_color}m\1\\\e[0m/g")\n" 
}

# Signature: {input} | color_apply -> {colored output}
# [pipeline filter]
color_apply_for_ini() {
    __color_apply_for_ini__in_text="$(cat /dev/stdin)"

    # shellcheck disable=SC2059
    printf "$(echo "$__color_apply_for_ini__in_text" |
        command sed 's/\([= ]\)\(bold \)/\1\\e[33m\2\\e[0m/g' |
        command sed 's/\([= ]\)\(italic \)/\1\\e[33m\2\\e[0m/g' |
        command sed 's/\([= ]\)\(true\)$/\1\\e[36m\2\\e[0m/g' |
        command sed 's/\([= ]\)\(false\)$/\1\\e[36m\2\\e[0m/g' |
        command sed 's/\(#.\{1,\}\)/\\e[32m\1\\e[0m/g')\n" 
}

# Signature: {input} | color_as_information -> {colored output}
# [pipeline filter]
color_as_information() {
    __color_as_information__in_text="$(cat /dev/stdin)"

    __color_as_information__color='\e[36m'
    printf "$__color_as_information__color%s$reset" "$__color_as_information__in_text"
}

# Signature: {input} | color_as_error -> {colored output}
# [pipeline filter]
color_as_error() {
    __color_as_error__in_error="$(cat /dev/stdin)"

    __color_as_error__color='\e[31m'
    printf "${__color_as_error__color}%s$reset\n" "$__color_as_error__in_error" >&2
}

# Signature: {style} | color_as_error_for_color_option {option}
# [pipeline closer]
color_as_error_for_color_option() {
    __color_as_error_for_color_option__in_style="$(cat /dev/stdin)"
    __color_as_error_for_color_option__in_option="$1"

    echo "a $__color_as_error_for_color_option__in_style style specified by $__color_as_error_for_color_option__in_option is invalid, expected it to be in the following format: $color_format" |
        color_as_error
}

# Signature: {input} | string_append {text} -> {input}{text}
# [pipeline filter]
string_append() {
    __string_append__in_input="$(cat /dev/stdin)"
    __string_append__in_text="$1"

    printf "%s%s" "$__string_append__in_input" "$__string_append__in_text"
}

# Signature: {input} | string_prepend {text} -> {text}{input}
# [pipeline filter]
string_prepend() {
    __string_prepend__in_input="$(cat /dev/stdin)"
    __string_prepend__in_text="$1"

    printf "%s%s" "$__string_prepend__in_text" "$__string_prepend__in_input"
}

# Signature: {input} | string_append_long_section_break -> {input}{section break}
# [pipeline filter]
string_append_long_section_break() {
    cat /dev/stdin | string_append "$(printf '\n\n\037')"
}

# Signature: {input} | string_append_section_break -> {input}{section break}
# [pipeline filter]
string_append_small_section_break() {
    cat /dev/stdin | string_append "$(printf '\n\037')"
}

# Signature: user_overrides -> {user override configuration}
# [pipeline starter]
user_overrides() {
    cat "$user_overrides_configuration"
}

# Signature: {user override configuration} | user_overrides_add {key} {value} -> {extended user override configuration}
# [pipeline filter]
user_overrides_add() {
    __user_overrides_add__in_key="$1"
    __user_overrides_add__in_value="$2"

    echo "$user_overrides_configuration
$__user_overrides_add__in_key=$__user_overrides_add__in_value"
}

# Signature: {user override configuration} | user_overrides_save
# [pipeline closer]
user_overrides_save() {
    cat /dev/stdin >"$user_overrides_configuration"
}

# Signature: throw_if_color_option_is_invalid {option} {value} {style}
# [not a pipeline participant]
throw_if_color_option_is_invalid() {
    __throw_if_color_option_is_invalid__in_option="$1"
    __throw_if_color_option_is_invalid__in_value="$2"
    __throw_if_color_option_is_invalid__in_style="$3"

    echo "$__throw_if_color_option_is_invalid__in_value" |
        configuration_key_value_clean |
        configuration_is_valid_color_value || {
        echo "$__throw_if_color_option_is_invalid__in_value" | color_as_information | string_append ': '
        echo "$__throw_if_color_option_is_invalid__in_style" | color_as_error_for_color_option "$__throw_if_color_option_is_invalid__in_option"
        exit "$invalid_option_argument"
    }
}

# Signature: throw_if_theme_doesnt_exist {theme path}
# [not a pipeline participant]
throw_if_theme_doesnt_exist() {
    __throw_if_theme_doesnt_exist__in_theme="$1"
    
    [ -f "$__throw_if_theme_doesnt_exist__in_theme" ] || {
        echo "$__throw_if_theme_doesnt_exist__in_theme" | color_as_information | string_append ': '
        echo "a theme specified by --theme|-t doesn't exist currently" | color_as_error
        exit "$invalid_option_argument"
    }
}

# Signature: configuration_initialize
# [not a pipeline participant]
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
    cat /dev/stdin | command sed 's/ *#.\{1,\}//g'
}

# Signature: {configuration content} | configuration_format -> {formatted configuration}
# [pipline filter]
configuration_format() {
    cat /dev/stdin | command sed 's/^ \{1,\}//; s/ \{1,\}$//; s/ *= */=/'
}

# Signature: {configuration content} | configuration_preprocess_for_parsing -> {cleaned configuration}
# [pipline filter]
configuration_preprocess_for_parsing() {
    cat /dev/stdin | configuration_remove_comments | configuration_format
}

# Signature: {configuration content} | configuration_save
# Signature: {configuration content} | configuration_save {custom configuration path}
# [pipeline closer]
configuration_save() {
    __configuration_save__in_path="$1"

    if [ -z "$__configuration_save__in_path" ]; then
        cat /dev/stdin | tee "$configuration" >/dev/null
    else
        cat /dev/stdin | tee "$__configuration_save__in_path" >/dev/null
    fi
}

# Signature: {configuration content} | configuration_get_key {key} -> {configuration key value}
# [pipeline filter]
configuration_get_key_value() {
    __configuration_get_key_value__in_key="$1"

    cat /dev/stdin |
        configuration_preprocess_for_parsing |
        command grep -F "$__configuration_get_key_value__in_key=" |
        command sed 's/[^=]\{1,\}=//'
}

# Signagure: {configuration content} | configuration_has_key {key}
# [pipeline filter]
configuration_has_key() {
    __configuration_has_key__in_key="$1"

    __configuration_had_key__search_result="$(cat /dev/stdin |
        configuration_preprocess_for_parsing |
        command grep -F "$__configuration_has_key__in_key=")"
    
    [ -n "$__configuration_had_key__search_result" ]
}

# Signature: {configuration content} | get_configuration_keys -> {configuration keys one per line}
# [pipeline filter]
configuration_get_keys() {
    __get_configuration_keys__in_configuration="$1"

    cat /dev/stdin |
        configuration_preprocess_for_parsing |
        command sed '/=/ s/=[^=]\{1,\}//; /^$/d'
}

# Signature: {key} | configuration_is_valid_color_key
# [condition checker]
configuration_is_valid_color_key() {
    __configuration_is_valid_color_key__in_key="$(cat /dev/stdin)"

    [ "$__configuration_is_valid_color_key__in_key" = header ] ||
    [ "$__configuration_is_valid_color_key__in_key" = bold ] ||
    [ "$__configuration_is_valid_color_key__in_key" = italic ] ||
    [ "$__configuration_is_valid_color_key__in_key" = options ] ||
    [ "$__configuration_is_valid_color_key__in_key" = placeholders ]
}

# Signature: {key} | configuration_is_valid_switch_key
# [condition checker]
configuration_is_valid_switch_key() {
    __configuration_is_valid_switch_key__in_key="$(cat /dev/stdin)"

    [ "$__configuration_is_valid_switch_key__in_key" = header_enable ] ||
    [ "$__configuration_is_valid_switch_key__in_key" = bold_enable ] ||
    [ "$__configuration_is_valid_switch_key__in_key" = italic_enable ] ||
    [ "$__configuration_is_valid_switch_key__in_key" = options_enable ] ||
    [ "$__configuration_is_valid_switch_key__in_key" = placeholders_enable ]
}

# Signature: {key} | configuration_is_valid_section_key
# [condition checker]
configuration_is_valid_section_key() {
    __configuration_is_valid_section_key__in_key="$(cat /dev/stdin)"
    
    [ "$__configuration_is_valid_section_key__in_key" = description ] ||
    [ "$__configuration_is_valid_section_key__in_key" = reasoning ] ||
    [ "$__configuration_is_valid_section_key__in_key" = cli ] ||
    [ "$__configuration_is_valid_section_key__in_key" = argument_format ] ||
    [ "$__configuration_is_valid_section_key__in_key" = notation ] ||
    [ "$__configuration_is_valid_section_key__in_key" = codes ] ||
    [ "$__configuration_is_valid_section_key__in_key" = examples ] ||
    [ "$__configuration_is_valid_section_key__in_key" = contacts ]
}

# Signature: {key} | configuration_is_valid_key
# [condition checker]
configuration_is_valid_key() {
    __configuration_is_valid_key__in_key="$(cat /dev/stdin)"

    echo "$__configuration_is_valid_key__in_key" | configuration_is_valid_color_key ||
    echo "$__configuration_is_valid_key__in_key" | configuration_is_valid_switch_key
}

# Signature: {key value} | configuration_key_value_clean -> {clean key value}
# [pipline filter]
configuration_key_value_clean() {
    cat /dev/stdin | command sed 's/^ \{1,\}//; s/ \{1,\}$//; s/ \{1,\}/ /;'
}

# Signagure: {clean key value} | __configuration_is_valid_color_value {prefix}
# [condition checker]
__configuration_is_valid_color_value() {
    ____configuration_is_valid_color_value_with_prefix__in_value="$(cat /dev/stdin)"
    ____configuration_is_valid_color_value__in_prefix="$1"

    [ "$____configuration_is_valid_color_value_with_prefix__in_value" = "${____configuration_is_valid_color_value__in_prefix}black" ] ||
    [ "$____configuration_is_valid_color_value_with_prefix__in_value" = "${____configuration_is_valid_color_value__in_prefix}red" ] ||
    [ "$____configuration_is_valid_color_value_with_prefix__in_value" = "${____configuration_is_valid_color_value__in_prefix}green" ] ||
    [ "$____configuration_is_valid_color_value_with_prefix__in_value" = "${____configuration_is_valid_color_value__in_prefix}yellow" ] ||
    [ "$____configuration_is_valid_color_value_with_prefix__in_value" = "${____configuration_is_valid_color_value__in_prefix}blue" ] ||
    [ "$____configuration_is_valid_color_value_with_prefix__in_value" = "${____configuration_is_valid_color_value__in_prefix}magenta" ] ||
    [ "$____configuration_is_valid_color_value_with_prefix__in_value" = "${____configuration_is_valid_color_value__in_prefix}cyan" ] ||
    [ "$____configuration_is_valid_color_value_with_prefix__in_value" = "${____configuration_is_valid_color_value__in_prefix}white" ]
}

# Signagure: {clean key value} | configuration_is_valid_color_value
# [condition checker]
configuration_is_valid_color_value() {
    __configuration_is_valid_color_value__in_value="$(cat /dev/stdin)"

    echo "$__configuration_is_valid_color_value__in_value" | __configuration_is_valid_color_value ||
    echo "$__configuration_is_valid_color_value__in_value" | __configuration_is_valid_color_value 'bold ' ||
    echo "$__configuration_is_valid_color_value__in_value" | __configuration_is_valid_color_value 'italic ' ||
    echo "$__configuration_is_valid_color_value__in_value" | __configuration_is_valid_color_value 'bold italic ' ||
    echo "$__configuration_is_valid_color_value__in_value" | __configuration_is_valid_color_value 'italic bold '
}

# Signagure: {key value} | configuration_is_valid_switch_value
# [condition checker]
configuration_is_valid_switch_value() {
    __configuration_is_valid_switch_value__in_value="$(cat /dev/stdin)"

    [ "$__configuration_is_valid_switch_value__in_value" = true ] ||
    [ "$__configuration_is_valid_switch_value__in_value" = false ]
}

# Signature: {configuration content} | configuration_is_valid -> {invalid keys one per line}
# [pipeline closer, condition checker]
configuration_is_valid() {
    __configuration_is_valid__result="$(mktemp)"
    echo true > "$__configuration_is_valid__result"

    __configuration_is_valid__clean_configuration="$(cat /dev/stdin | configuration_preprocess_for_parsing)"
    echo "$__configuration_is_valid__clean_configuration" | configuration_get_keys | while read -r key; do
        echo "$key" | configuration_is_valid_key || {
            echo "unsupported $key"
            echo false > "$__configuration_is_valid__result"
        }
    done

    __configuration_is_valid__invalid_prefix=invalid
    echo "$__configuration_is_valid__clean_configuration" |
        configuration_get_keys |
        command grep -v enable |
        while read -r key; do

        echo "$key" | configuration_is_valid_key || continue

        echo "$__configuration_is_valid__clean_configuration" |
            configuration_get_key_value "$key" |
            configuration_key_value_clean |
            configuration_is_valid_color_value || {

            echo "$__configuration_is_valid__invalid_prefix $key"
            echo false > "$__configuration_is_valid__result"
        }
    done

    echo "$__configuration_is_valid__clean_configuration" |
        configuration_get_keys |
        command grep enable |
        while read -r key; do

        echo "$key" | configuration_is_valid_key || continue

        echo "$__configuration_is_valid__clean_configuration" |
            configuration_get_key_value "$key" |
            configuration_key_value_clean |
            configuration_is_valid_switch_value || {

            echo "$__configuration_is_valid__invalid_prefix $key"
            echo false > "$__configuration_is_valid__result"
        }
    done

    if [ "$(cat "$__configuration_is_valid__result")" = true ]; then
        return "$success"
    else
        return "$invalid_theme_key"
    fi
}

# Signature: {configuration content} | configuration_set_key {key} {value} -> {updated configuration}
# [pipeline filter]
configuration_set_key() {
    __configuration_set_key__in_key="$1"
    __configuration_set_key__in_value="$2"

    if ! echo "$__configuration_set_key__in_key" | configuration_is_valid_key; then
        color_as_information "$__configuration_set_key__in_key"
        printf ': '
        color_as_error "invalid key, expected one of: $(configuration_get_keys | into_one_line)"
        return "$invalid_theme_key"
    fi

    cat /dev/stdin |
        configuration_preprocess_for_parsing |
        command sed "/$__configuration_set_key__in_key/ s/=.*/=$__configuration_set_key__in_value/"
}

# Signature: {configuration content} | configuration_merge {override configuration content} -> {configuration merge}
configuration_merge() {
    __configuration_merge__first_configuration="$(cat /dev/stdin | configuration_preprocess_for_parsing)"
    __configuration_merge__overriding_configuration="$(echo "$1" | configuration_preprocess_for_parsing)"

    echo "$__configuration_merge__first_configuration" | configuration_get_keys | while read -r key; do
        if echo "$__configuration_merge__overriding_configuration" | configuration_has_key "$key"; then
            __configuration_merge__value="$(echo "$__configuration_merge__overriding_configuration" |
                configuration_get_key_value "$key")"
        else
            __configuration_merge__value="$(echo "$__configuration_merge__first_configuration" |
                configuration_get_key_value "$key")"
        fi
        echo "$key=$__configuration_merge__value"
    done

    echo "$__configuration_merge__overriding_configuration" | configuration_get_keys | while read -r key; do
        if ! echo "$__configuration_merge__first_configuration" | configuration_has_key "$key"; then
            __configuration_merge__value="$(echo "$__configuration_merge__overriding_configuration" |
                configuration_get_key_value "$key")"
                echo "$key=$__configuration_merge__value"
        fi
    done
}

# Signagure: get_codes -> {codes one per line}
# [pipeline starter]
get_codes() {
    echo "$codes" | command sed 's/^\(.\).*/\1/g'
}

# Signagure: get_cli_options -> {cli options one per line}
# [pipeline starter]
get_cli_options() {
    echo "$cli" | command sed 's/\(--[^ -]\{1,\}\) \(-[^ -]\) .\{1,\}/\1|\2/g'
}

# Signagure: {input} | into_one_line -> {input items joined via comma}
# [pipeline filter]
into_one_line() {
    cat /dev/stdin | tr '\n' ' ' | command sed 's/ $//; s/ /, /g'
}

# Signagure: {input} | into_several_lines -> {input items spreaded into several lines}
# [pipeline filter]
into_several_lines() {
    cat /dev/stdin | command sed 's/,/\n/g; s/^[[:space:]]\{1,\}//g; s/[[:space:]]\{1,\}$//g;'
}

# Signagure: help_description -> {help text}
# [pipeline starter]
help_description() {
    echo "# Description #
A utility to perform simple Regex-based colorization of your input"
}

# Signagure: help_reasoning -> {help text}
# [pipeline starter]
help_reasoning() {
    echo "# Reasoning #
Programs often output their --help | -h message without any colors which can be hard to read"
}

# Signagure: help_cli -> {help text}
# [pipeline starter]
help_cli() {
    echo "# CLI #
$cli"
}

# Signagure: help_codes -> {help text}
# [pipeline starter]
help_codes() {
    echo "# Codes #
$codes"
}

# Signagure: help_argument_format -> {help text}
# [pipeline starter]
help_argument_format() {
    echo "# Argument format #
{color} placeholder actually is $color_format where \"bold\" and \"italic\" are optional
{target} placeholder actually is {(headers|bold|italic|options|placeholders),...} where listed values can be written via comma like \"headers,bold\""
}

# Signagure: help_notation -> {help text}
# [pipeline starter]
help_notation() {
    echo "# Placeholder notation #
$notation"
}

# Signagure: help_examples -> {help text}
# [pipeline starter]
help_examples() {
    echo "# Examples #
grep --help | $program --theme {path}: color grep help
grep --help | $program --options {color_code}: color grep help"
}

# Signagure: help_notation -> {help text}
# [pipeline starter]
help_contacts() {
    echo "# Contacts #
EmilyGraceSeville7cfg@gmail.com - program author email"
}

# Signagure: help -> {help text}
# [pipeline starter]
help() {
    help_description | string_append_long_section_break |
        string_append "$(help_reasoning)" | string_append_long_section_break | 
        string_append "$(help_cli)" | string_append_long_section_break |
        string_append "$(help_argument_format)" | string_append_long_section_break |
        string_append "$(help_notation)" | string_append_long_section_break |
        string_append "$(help_codes)" | string_append_long_section_break |
        string_append "$(help_examples)" | string_append_long_section_break |
        string_append "$(help_contacts)" | color_apply | more
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

    --options | -o | options\?)
        get_cli_options
        exit "$success"
    ;;

    --codes | -c | codes\?)
        get_codes
        exit "$success"
    ;;

    --just | -j | just:)
        filter="$argument"
        filter="$(echo "$filter" | into_several_lines)"

        key_count="$(mktemp)"
        echo 0 >"$key_count"
        echo "$filter" | while read -r key; do
            if ! echo "$key" | configuration_is_valid_section_key;  then
                echo "$key" | color_as_information | string_append ': '
                echo "an invalid target, expected one of: description, reasoning, cli, argument_format, notation, codes, examples, contacts" | color_as_error
                exit "$invalid_option_argument"
            fi
            echo "$(($(cat "$key_count") + 1))" > "$key_count"
        done || exit

        current_key_index="$(mktemp)"
        echo 1 >"$current_key_index"
        echo "$filter" | while read -r key; do
            help_function=
            case "$key" in
                description)
                    help_function=help_description
                    ;;
                reasoning)
                    help_function=help_reasoning
                    ;;
                cli)
                    help_function=help_cli
                    ;;
                argument_format)
                    help_function=help_argument_format
                    ;;
                notation)
                    help_function=help_notation
                    ;;
                codes)
                    help_function=help_codes
                    ;;
                examples)
                    help_function=help_examples
                    ;;
                contacts)
                    help_function=help_contacts
                    ;;
            esac

            if [ "$(cat "$current_key_index")" -lt "$(cat "$key_count")" ]; then
                "$help_function" | string_append_small_section_break | color_apply
            else
                "$help_function" | color_apply
            fi

            echo "$(($(cat "$current_key_index") + 1))" > "$current_key_index"
        done
        
        exit "$success"
    ;;

    --keys | -k | keys\?)
        configuration | configuration_get_keys
        exit "$success"
    ;;

    --disable | -d | disable:)
        filter="$argument"
        filter="$(echo "$filter" | into_several_lines)"

        echo "$filter" | while read -r key; do
            if ! echo "$key" | configuration_is_valid_color_key;  then
                echo "$key" | color_as_information | string_append ': '
                echo "an invalid target, expected one of: $(configuration | configuration_get_keys | command grep -v enable | into_one_line)" | color_as_error
                exit "$invalid_option_argument"
            fi

            [ "$key" = header ] && configuration_set_key header_enable false | configuration_save
            [ "$key" = bold ] && configuration_set_key bold_enable false | configuration_save
            [ "$key" = italic ] && configuration_set_key italic_enable false | configuration_save
            [ "$key" = options ] && configuration_set_key options_enable false | configuration_save
            [ "$key" = placeholders ] && configuration_set_key placeholders_enable false | configuration_save
        done || exit
        shift
    ;;

    --theme | -t | theme:)
        theme="$argument"
        throw_if_theme_doesnt_exist "$theme" || exit
        invalid_keys="$(configuration "$theme" | configuration_is_valid)"

        # shellcheck disable=SC2181
        [ $? -ne 0 ] && {
            unsupported_prefix=unsupported
            echo "$invalid_keys" | command grep -q "^$unsupported_prefix " && {
                echo "$theme" | color_as_information | string_append ': '

                keys="$(echo "$invalid_keys" |
                    sed "/^$unsupported_prefix /!d; s/^$unsupported_prefix //" |
                    into_one_line)"
                    
                
                echo "a theme specified by --theme|-t contains these unsupported keys: $keys" | color_as_error
            }

            invalid_prefix=invalid
            echo "$invalid_keys" | command grep -q "^$invalid_prefix " && {
                echo "$theme" | color_as_information | string_append ': '

                keys="$(echo "$invalid_keys" |
                    sed "/^$invalid_prefix /!d; s/^$invalid_prefix //" |
                    into_one_line)"
                    
                
                echo "a theme specified by --theme|-t contains these invalid keys: $keys" | color_as_error
            }
            exit "$invalid_option_argument"
        }
        shift
    ;;

    --preview | -p | preview:)
        theme="$argument"
        throw_if_theme_doesnt_exist "$theme" || exit
        configuration "$theme" | configuration_format | color_apply_for_ini
        shift
        ;;

    --format | -f | format:)
        theme="$argument"
        throw_if_theme_doesnt_exist "$theme" || exit
        configuration "$theme" | configuration_format
        shift
        ;;

    --remove-comments | -r | remove-comments:)
        theme="$argument"
        throw_if_theme_doesnt_exist "$theme" || exit

        configuration "$theme" | configuration_format
        shift
        ;;

    --header-style | -H | header-style:)
        header_style="$argument"
        throw_if_color_option_is_invalid '--header-style|-h' "$header_style" header || exit

        user_overrides | user_overrides_add header "$header_style" | user_overrides_save
        shift
    ;;

    --bold-style | -b | bold-style:)
        bold_style="$argument"
        throw_if_color_option_is_invalid '--bold-style|-b' "$bold_style" bold || exit
        
        user_overrides | user_overrides_add bold "$bold_style" | user_overrides_save
        shift
    ;;

    --italic-style | -i | italic-style:)
        italic_style="$argument"
        throw_if_color_option_is_invalid '--italic-style|-i' "$italic_style" italic || exit
        
        user_overrides | user_overrides_add italic "$bold_style" | user_overrides_save
        shift
    ;;

    --options-style | -O | options-style:)
        options_style="$argument"
        throw_if_color_option_is_invalid '--options-style|-o' "$options_style" options || exit
        
        user_overrides | user_overrides_add options "$options_style" | user_overrides_save
        shift
    ;;

    --placeholders-style | -P | placeholders-style:)
        placeholders_style="$argument"
        throw_if_color_option_is_invalid '--placeholders-style|-o' "$placeholders_style" placeholders || exit
        
        user_overrides | user_overrides_add placeholders "$placeholders_style" | user_overrides_save
        shift
    ;;

    *)
        color_as_information "$option"
        printf ': '
        color_as_error "an invalid option, expected one of: $(get_cli_options | into_one_line)"
        exit "$invalid_option"
    ;;
    esac

    shift
done

user_overrides