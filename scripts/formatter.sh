#!/usr/bin/env bash

shopt -s extglob

source ./colors.sh

# shellcheck disable=SC2034
# A header mark [public constant, do not change]
declare formatter_HEADER_MARK="# "
# A code mark [public constant, do not change]
declare formatter_CODE_MARK="> "
# A bullet list mark [public constant, do not change]
declare formatter_BULLET_LIST_MARK="* "
# A numbered list mark [public constant, do not change]
declare formatter_NUMBERED_LIST_MARK=") "
# A singular indent [public constant, do not change]
declare formatter_INDENT_MARK="  "
# A description separator [public constant, do not change]
declare formatter_DESCRIPTION_SEPARATOR_MARK=" - "

# [internal constant, do not change]
declare -i __formatter_current_header_level=1
# [internal constant, do not change]
declare -i __formatter_current_indent_level=0

# [internal constant, do not change]
declare -i __formatter_current_list_level=1
# [internal constant, do not change]
declare -a __formatter_level_last_items=(1)
# [internal constant, do not change]
declare __formatter_list_started=false
# [internal constant, do not change]
declare __formatter_list_style=bullet

# [internal function, do not change]
__formatter_check_is_empty_or_with_invalid_characters() {
    declare input="$1"

    [[ ${#input} -gt 0 ]] && {
        # shellcheck disable=SC2155
        declare trimmed_input="$(echo -n "$input" | sed --regexp-extended 's/^\s+|\s+$//g')"
        [[ "$input" == "$trimmed_input" ]]
    }
}

# [internal function, do not change]
__formatter_throw_if_is_empty() {
    declare input="$1"
    declare name="$2"

    __formatter_check_is_empty_or_with_invalid_characters "$input" || {
        printf "%s expected to be at least one character long not containing leading or trailing spaces\n" "$name"
        return 1
    }
}

# [internal function, do not change]
__formatter_indents_amount() {
    printf "%s" "${#__formatter_level_last_items[@]}"
}

# Increase the current heading level
formatter_header_level_up() {
    (( __formatter_current_header_level++ ))
}

# Increase the current heading level
header_up() {
    formatter_header_level_up
}

# Decrease the current heading level
formatter_header_level_down() {
    if [[ $__formatter_current_header_level -gt 1 ]]; then
        (( __formatter_current_header_level++ ))
    fi
}

# Decrease the current heading level
header_down() {
    formatter_header_level_down
}

# Increase the current list level
# It's completely independent from indentation level which just adds series of spaces in front of content on the same line
formatter_list_level_up() {
    (( __formatter_current_list_level++ ))

    declare index=$(($__formatter_current_list_level - 1))
    if [[ $__formatter_current_list_level -gt $(__formatter_indents_amount) ]]; then
        __formatter_level_last_items+=(1)
    else
        __formatter_level_last_items[$index]=1
        declare last_index=$(($(__formatter_indents_amount) - 1))

        for index in $(seq $__formatter_current_list_level $last_index); do
            unset "__formatter_level_last_items[$index]"
        done
    fi
}

# Increase the current list level
# It's completely independent from indentation level which just adds series of spaces in front of content on the same line
list_up() {
    formatter_list_level_up
}

# Increase the current list level
# It's completely independent from indentation level which just adds series of spaces in front of content on the same line
sublist:() {
    formatter_list_level_up
}

# Decrease the current list level
# It's completely independent from indentation level which just adds series of spaces in front of content on the same line
formatter_list_level_down() {
    if [[ $__formatter_current_list_level -gt 1 ]]; then
        (( __formatter_current_list_level-- ))
        unset "__formatter_level_last_items[$__formatter_current_list_level]"
    fi
}

# Decrease the current list level
# It's completely independent from indentation level which just adds series of spaces in front of content on the same line
list_down() {
    formatter_list_level_down
}

# Increase the current indent
# Doesn't affect any list numbering, just adds spaces in front of content on the same line
formatter_indent_level_up() {
    (( __formatter_current_indent_level++ ))
}

# Increase the current indent
# Doesn't affect any list numbering, just adds spaces in front of content on the same line
indent_up() {
    formatter_indent_level_up
}

# Decrease the current indent
# Doesn't affect any list numbering, just adds spaces in front of content on the same line
formatter_indent_level_down() {
    if [[ $__formatter_current_indent_level -gt 1 ]]; then
        (( $__formatter_current_indent_level++ ))
    fi
}

# Decrease the current indent
# Doesn't affect any list numbering, just adds spaces in front of content on the same line
indent_down() {
    formatter_indent_level_down
}

# [internal function, do not change]
__render_indent() {
    for _ in $(seq 1 $__formatter_current_indent_level); do
        printf '%s' "$formatter_INDENT_MARK"
    done
}

# [internal function, do not change]
__render_list_indent() {
    for _ in $(seq 1 $(($__formatter_current_list_level - 1))); do
        printf '%s' "$formatter_INDENT_MARK"
    done
}

# Initiate a new numbered list
formatter_numbered_list_start() {
    __formatter_list_started=true
    __formatter_list_style=numbered
}

# Initiate a new numbered list
# Mixing numbered and bullet lists currently is not possible
numbered_list:() {
    formatter_numbered_list_start
}

# Initiate a new bullet list
# Mixing numbered and bullet lists currently is not possible
formatter_bullet_list_start() {
    __formatter_list_started=true
    __formatter_list_style=bullet
}

# Initiate a new bullet list
# Mixing numbered and bullet lists currently is not possible
bullet_list:() {
    formatter_bullet_list_start
}

# End the current list completely
# Mixing numbered and bullet lists currently is not possible
# Can be used as a list terminator without explicit sublists endings
formatter_list_end() {
    __formatter_list_started=false
    __formatter_level_last_items=(1)
}

# End the current list completely
# Mixing numbered and bullet lists currently is not possible
# Can be used as a list terminator without explicit sublists endings
list_end() {
    formatter_list_end
}

# End the current sublist or the entire list if the current one is the most outermost
# Prefer ending the whole list via list_end rather than with this function
formatter_sublist_end() {
    if [[ $__formatter_current_indent_level == 1 ]]; then
        formatter_list_end
        return
    fi

    declare from=$(($__formatter_current_list_level - 1))
    declare to=$(($(__formatter_indents_amount) - 1))
    for index in $(seq $from $to); do
        unset "__formatter_level_last_items[$index]"
    done
    (( __formatter_current_list_level-- ))
}

# End the current sublist or the entire list if the current one is the most outermost
# Prefer ending the whole list via list_end rather than with this function
sublist_end() {
    formatter_sublist_end
}

# [internal function, do not change]
__render_list_point() {
    if [[ "$__formatter_list_started" == true ]]; then
        __render_list_indent
        declare -i index=$(($__formatter_current_indent_level - 1))
        declare -i last_item_number=${__formatter_level_last_items[$index]}
        
        [[ $__formatter_list_style == bullet ]] && {
            printf "%s" "$formatter_BULLET_LIST_MARK"
        } || {
            printf "%s%s" "$last_item_number" "$formatter_NUMBERED_LIST_MARK"
        }

        (( last_item_number++ ))
        __formatter_level_last_items[$index]=$last_item_number
    fi
}

# [internal function, do not change]
__formatter_render_indents_and_list_marks() {
    __render_indent
    __render_list_point
}

# Render an empty line
formatter_render_empty_line() {
    __render_indent
    printf '\n'
}

# Render an empty line
line() {
    formatter_render_empty_line
}

# Render a text
# Signature: formatter_render_text {text to render}
formatter_render_text() {
    __formatter_render_indents_and_list_marks
    declare text="$1"

    __formatter_throw_if_is_empty "$text" text
    printf "%s\n" "$text"
}

# Render a text
# Signature: text: {text to render}
text:() {
    formatter_render_text "$1"
}

# Render a header level 1
# Signature: formatter_render_header {header to render}
formatter_render_header() {
    __render_indent
    declare header="$1"

    __formatter_throw_if_is_empty "$header" header
    printf "$colors_HEADER$formatter_HEADER_MARK%s$colors_RESET\n" "$header"
}

# Render a header level 1
# Signature: header: {header to render}
header:() {
    formatter_render_header "$1"
}

# Render a header level 1 with "About" text
about() {
    header: "About"
}

# Render a header level 1 with "Syntax" text
syntax() {
    header: "Syntax"
}

# Render a header level 1 with "Contacts" text
contacts() {
    header: "Contacts"
}

# Render a header level 2
# Signature: header2: {header to render}
header2:() {
    header_up
    header: "$1"
    header_down
}

# Render a header level 3
# Signature: header3: {header to render}
header3:() {
    header_up
    header2: "$1"
    header_down
}

# Render a header level 4
# Signature: header4: {header to render}
header4:() {
    header_up
    header3: "$1"
    header_down
}

# Render a header level 5
# Signature: header5: {header to render}
header5:() {
    header_up
    header4: "$1"
    header_down
}

# Render a command with description
# Signature: formatter_render_command_description {command to render} {description to render}
formatter_render_command_description() {
    __formatter_render_indents_and_list_marks

    declare command="$1"
    declare description="$2"

    __formatter_throw_if_is_empty "$command" command
    __formatter_throw_if_is_empty "$description" description
    printf "$colors_COMMAND%s$colors_RESET$formatter_DESCRIPTION_SEPARATOR_MARK%s\n" "$command" "$description"
}

# Render a command with description
# Signature: command: {command to render} {description to render}
command:() {
    formatter_render_command_description "$1" "$2"
}

# Render a placeholder
# Signature: formatter_render_placeholder {placeholder to render}
formatter_render_placeholder() {
    declare placeholder="$1"

    __formatter_throw_if_is_empty "$placeholder" placeholder
    printf "$colors_SPECIAL_CHARACTER{{$colors_RESET$colors_PLACEHOLDER%s$colors_RESET$colors_SPECIAL_CHARACTER}}$colors_RESET" "$placeholder"
}

# Render a placeholder
# Signature: placeholder: {placeholder to render}
placeholder:() {
    formatter_render_placeholder "$1"
}

# Render a file placeholder
any_file() {
    placeholder: "/path/to/file"
}

# Render a file with extension placeholder
# Signature: file_with_extension {extension to render}
file_with_extension() {
    declare extension="$1"
    placeholder: "/path/to/file.$extension"
}

# Render a csv file placeholder
csv_file() {
    file_with_extension csv
}

# Render a json file placeholder
json_file() {
    file_with_extension json
}

# Render a yaml file placeholder
yaml_file() {
    file_with_extension yaml
}

# Render a VectorMotion project file placeholder
project_file() {
    file_with_extension vmpf
}

# Render a placeholder with description
# Signature: formatter_render_placeholder_description {placeholder to render} {description to render}
formatter_render_placeholder_description() {
    __formatter_render_indents_and_list_marks

    declare placeholder="$1"
    declare description="$2"

    __formatter_throw_if_is_empty "$description" description
    placeholder: "$placeholder"
    printf "$formatter_DESCRIPTION_SEPARATOR_MARK%s\n" "$description"
}

# Render a placeholder with description
# Signature: placeholder_description: {placeholder to render} {description to render}
placeholder_description:() {
    formatter_render_placeholder_description "$1" "$2"
}

# Render an option
# Signature: formatter_render_option {option to render}
formatter_render_option() {
    declare option="$1"

    __formatter_throw_if_is_empty "$option" option
    printf "${colors_OPTION}--%s${colors_RESET}" "$option"
}

# Render an option
# Signature: option: {option to render}
option:() {
    formatter_render_option "$1"
}

# Render an option with description
# Signature: formatter_render_option_description {option to render} {description to render}
formatter_render_option_description() {
    __formatter_render_indents_and_list_marks

    declare option="$1"
    declare description="$2"

    __formatter_throw_if_is_empty "$description" description
    option: "$option"
    printf "$formatter_DESCRIPTION_SEPARATOR_MARK%s\n" "$description"
}

# Render an option with description
# Signature: option_description: {option to render} {description to render}
option_description:() {
    formatter_render_option_description "$1" "$2"
}

