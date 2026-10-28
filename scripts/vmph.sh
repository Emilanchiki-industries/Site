#!/usr/bin/env bash

##################################################################################################################
# UTILS
##################################################################################################################
__quote() {
    declare string="$1"
    jq --null-input --arg argument "$string" '$argument'
}

__validate_project_file() {
    declare project="$1"
    declare schema="path/to/schema"

    check-jsonschema --schemafile "$schema" ."$project"
}

# shellcheck disable=SC2155
declare PROGRAM="$(__quote "$0")"

##################################################################################################################
# CONSTANTS
##################################################################################################################
source ./colors.sh
source ./placeholders.sh
soource ./formatter.sh


##################################################################################################################
# DEPENDENCIES
##################################################################################################################
__check_dependency() {
    command -v "$1" >/dev/null 2>&1 || {
        printf "Required dependency ${COMMAND_COLOR}%s${RESET} is not installed\n" "$1"
        printf "You can install it like this (if you are on Ubuntu-based distribution):\n"
        printf "  sudo apt install ${COMMAND_COLOR}%s${RESET} -y\n" "$1"
        exit 1
    }
}

check_dependencies() {
    for dependency in jq check-jsonschema; do
        __check_dependency "$dependency"
    done
}

##################################################################################################################
# HELP
##################################################################################################################



help() {
    __help_title About
    __help_about "$(__help_program)" "a portable VectorMotion file parser"
    __help_redirected_indent
    echo "To hide examples and this hint redirect $(__help_program)s error output to /dev/null like:" >&2
    __help_redirected_indent
    echo "$(__help_program) 2> /dev/null" >&2
    __help_separator

    __help_title Dependencies
    __help_dependency_list_item jq "used for obtaining jq values"
    __help_dependency_list_item check-jsonschema "used to validate JSON part of VectorMotion project against JSON schema before querying data"
    __help_separator

    __help_title Syntax
    echo "${LIST_MARK}$(__help_program) $(__help_option get) $(__help_placeholder "scene | layer | setting") $(__help_placeholder "name") $(__help_project_file_placeholder): print scene, layer or global setting"
    __help_redirected_indent
    __help_example_list_item "$(__help_program) $(__help_option get) scene 'Scene 1'"
    __help_redirected_indent
    __help_example_list_item "$(__help_program) $(__help_option get) layer 'Rectangle 1'"

    echo "${LIST_MARK}$(__help_program) $(__help_option get) $(__help_placeholder "resources | scenes | layers | settings") $(__help_project_file_placeholder): print resources, all scenes, all layers or global settings"
    __help_redirected_indent
    __help_example_list_item "$(__help_program) $(__help_option get) scenes"
    __help_separator

    __help_subtitle Filtering
    __help_indent
    echo "In combination with $(__help_option get) you can always put the following options to filter out unneded scenes and layers:"
    __help_indent
    __help_option_list_item "name" "check names and filter out scenes or layers not matching a JQ-based regular expression pattern"
    __help_redirected_indent2
    __help_example_list_item "${LIST_MARK}$(__help_program) $(__help_option get) scenes $(__help_option name) eq '^Grass '"

    __help_indent
    __help_option_list_item "width" "check widths and filter out those scenes or layers which smaller or bigger than the specified size"
    __help_redirected_indent2
    __help_example_list_item "${LIST_MARK}$(__help_program) $(__help_option get) scenes $(__help_option width) gt 100"

    __help_indent
    __help_option_list_item "height" "check heights and filter out those scenes or layers which smaller or bigger than the specified size"
    __help_redirected_indent2
    __help_example_list_item "${LIST_MARK}$(__help_program) $(__help_option get) scenes $(__help_option height) width gt 100"

    __help_indent
    __help_option_list_item "field-of-view" "check field of view and filter out those scenes which smaller or bigger than the specified one"
    __help_redirected_indent2
    __help_example_list_item "${LIST_MARK}$(__help_program) $(__help_option get) scenes $(__help_option field-of-view) gt 100"

    __help_indent
    __help_option_list_item "animation-length" "check field of view and filter out those scenes which have shorter of longer animation than the specified one"
    __help_redirected_indent2
    __help_example_list_item "${LIST_MARK}$(__help_program) $(__help_option get) scenes $(__help_option animation-length) gt 100"

    __help_indent
    __help_option_list_item "current-frame" "check current keyframe and filter out those scenes which have current keyframe placed before of after a specific one"
    __help_redirected_indent2
    __help_example_list_item "${LIST_MARK}$(__help_program) $(__help_option get) scenes $(__help_option current-keyframe) gt 100"

    __help_indent
    __help_option_list_item "color" "check color and filter out those scenes or layers which have matching or not matching color to the specified one"
    __help_redirected_indent2
    __help_example_list_item "${LIST_MARK}$(__help_program) $(__help_option get) scenes $(__help_option color) 'red >= 100'"
    __help_redirected_indent2
    __help_example_list_item "${LIST_MARK}$(__help_program) $(__help_option get) layers $(__help_option color) '== #FFFFFF'"
    __help_separator

    __help_indent
    echo "Each condition is an expression in the following form:"
    __help_indent
    __help_list_item "$(__help_placeholder "> | < | >= | <= | == | !=") $(__help_placeholder "number | regex")"
    __help_indent
    __help_list_item "$(__help_placeholder "red | green | blue | alpha") $(__help_placeholder "> | < | >= | <= | == | !=") $(__help_placeholder "number")"

    __help_indent
    echo "All filters are combined as if they were joined via and in other programming languages"
    __help_indent
    echo "You can write colors in HEX or compare their components (red, green, blue, alpha) invividually"
    __help_separator

    __help_subtitle Low-level
    __help_indent
    echo "${LIST_MARK}$(__help_program) $(__help_option get-direct) $(__help_placeholder jq_code) $(__help_placeholder name_pattern): pass jq code to extract needed data"
    __help_separator

    __help_title "How to contribute"
    echo "You can edit project's code or ask me to do that by contacting me either in project's repository or by EmilyGraceSeville7cfg@gmail.com"
}

__extract_json_file_part() {
    sed --quiet --regexp-extended --zero-terminated 's/.*(\{"resources":\{.+)/\1/p' "$1"
}

##################################################################################################################
# SCENES
##################################################################################################################
declare TEXT_COLOR='\e[32;1m'
declare NUMBER_COLOR='\e[36m'

__extract_scene_name() {
    declare project="$1"
    jq --raw-output '.title' "$project"
}

__extract_scene_id() {
    declare project="$1"
    jq --raw-output '.id' "$project"
}

__extract_scene_width() {
    declare project="$1"
    jq --raw-output '.world.size.value.width' "$project"
}

__extract_scene_height() {
    declare project="$1"
    jq --raw-output '.world.size.value.height' "$project"
}

__extract_scene_field_of_view() {
    declare project="$1"
    jq --raw-output '.world.fov.keyed' "$project"
}

__extract_scene_layer_count() {
    declare project="$1"
    jq --raw-output '.layers | length' "$project"
}

# shellcheck disable=SC2155
__extract_scene_is_empty() {
    declare project="$1"
    declare layer_count="$(__extract_scene_layer_count "$project")"
    [[ "$layer_count" == 0 ]] && echo true || echo false
}

__extract_scene_animation_length() {
    declare project="$1"
    jq --raw-output '.animation.length' "$project"
}

__extract_scene_animation_current_frame() {
    declare project="$1"
    jq --raw-output '.animation.frame' "$project"
}

# shellcheck disable=SC2155
__extract_scene_is_current_frame_outside_of_animation_range() {
    declare project="$1"
    declare animation_length="$(__extract_scene_animation_length "$project")"
    declare animation_current_frame="$(__extract_scene_animation_current_frame "$project")"

    [[ "$animation_current_frame" > "$animation_length" ]] && echo true || echo false
}

__extract_scene_is_solid_background() {
    declare project="$1"
    jq --raw-output '.bg.paint.keyed.type == "Solid"' "$project"
}

__extract_scene_solid_background_color_component() {
    declare project="$1"
    jq --raw-output 'if (.bg.paint.keyed.type == "Solid") then .bg.paint.keyed.solid else null end' "$project"
}

__extract_scene_solid_background_red_component() {
    declare project="$1"
    __extract_scene_solid_background_color_component "$project" | jq '.[0]'
}

__extract_scene_solid_background_green_component() {
    declare project="$1"
    __extract_scene_solid_background_color_component "$project" | jq '.[1]'
}

__extract_scene_solid_background_blue_component() {
    declare project="$1"
    __extract_scene_solid_background_color_component "$project" | jq '.[2]'
}

__extract_scene_solid_background_alpha_component() {
    declare project="$1"
    __extract_scene_solid_background_color_component "$project" | jq '.[3]'
}

__extract_scene_gradient_background_color_components() {
    declare project="$1"
    jq --raw-output 'if (.bg.paint.keyed.type == "Gradient") then
            .bg.paint.keyed.gradient.stops
        else
            null
        end' "$project"
}

__extract_scene_gradient_background_red_components() {
    declare project="$1"
    __extract_scene_gradient_background_color_components "$project" | jq '.[0].color[0], .[1].color[0]'
}

__extract_scene_gradient_background_green_components() {
    declare project="$1"
    __extract_scene_gradient_background_color_components "$project" | jq '.[0].color[1], .[1].color[1]'
}

__extract_scene_gradient_background_blue_components() {
    declare project="$1"
    __extract_scene_gradient_background_color_components "$project" | jq '.[0].color[2], .[1].color[2]'
}

__extract_scene_gradient_background_alpha_components() {
    declare project="$1"
    __extract_scene_gradient_background_color_components "$project" | jq '.[0].color[3], .[1].color[3]'
}

__extract_color_as_reformatted_json() {
    declare red="$1"
    declare green="$2"
    declare blue="$3"
    declare alpha="$4"

    jq --null-input --argjson red "$red" --argjson green "$green" --argjson blue "$blue" --argjson alpha "$alpha" \
        '{ red: $red, green: $green, blue: $blue, alpha: $alpha }'
}

# shellcheck disable=SC2155
__extract_scene_as_reformatted_json() {
    declare project="$1"

    declare name="$(__extract_scene_name "$project")"
    declare id="$(__extract_scene_id "$project")"
    declare width="$(__extract_scene_width "$project")"
    declare height="$(__extract_scene_height "$project")"

    declare field_of_view="$(__extract_scene_field_of_view "$project")"
    declare layer_count="$(__extract_scene_layer_count "$project")"
    declare animation_length="$(__extract_scene_animation_length "$project")"
    declare animation_current_frame="$(__extract_scene_animation_current_frame "$project")"

    declare background=""
    if [[ "$(__extract_scene_is_solid_background "$project")" == true ]]; then
        declare red="$(__extract_scene_solid_background_red_component "$project")"
        declare green="$(__extract_scene_solid_background_green_component "$project")"
        declare blue="$(__extract_scene_solid_background_blue_component "$project")"
        declare alpha="$(__extract_scene_solid_background_alpha_component "$project")"

        background="$(__extract_color_as_reformatted_json "$red" "$green" "$blue" "$alpha")"
    else
        declare first_red="$(__extract_scene_gradient_background_red_components "$project" | sed -n '1p')"
        declare first_green="$(__extract_scene_gradient_background_green_components "$project" | sed -n '1p')"
        declare first_blue="$(__extract_scene_gradient_background_blue_components "$project" | sed -n '1p')"
        declare first_alpha="$(__extract_scene_gradient_background_alpha_components "$project" | sed -n '1p')"

        declare second_red="$(__extract_scene_gradient_background_red_components "$project" | sed -n '2p')"
        declare second_green="$(__extract_scene_gradient_background_green_components "$project" | sed -n '2p')"
        declare second_blue="$(__extract_scene_gradient_background_blue_components "$project" | sed -n '2p')"
        declare second_alpha="$(__extract_scene_gradient_background_alpha_components "$project" | sed -n '2p')"

        declare first_color="$(__extract_color_as_reformatted_json "$first_red" "$first_green" "$first_blue" "$first_alpha")"
        declare second_color="$(__extract_color_as_reformatted_json "$second_red" "$second_green" "$second_blue" "$second_alpha")"

        background="$(jq --null-input --argjson first "$first_color" --argjson second "$second_color" '{first: $first, second: $second}')"
    fi

    jq --null-input --argjson program "$PROGRAM" \
        --arg name "$name" --argjson id "$id" \
        --argjson width "$width" --argjson height "$height" \
        --argjson field_of_view "$field_of_view" \
        --argjson layer_count "$layer_count" \
        --argjson animation_length "$animation_length" \
        --argjson animation_current_frame "$animation_current_frame" \
        --argjson background "$background" \
        '{
        comment: "Contains information about scene formatted according to \($program)",
        name: $name,
        identifier: $id,
        width: $width,
        height: $height,
        field_of_view: $field_of_view,
        animation: {
            length: $animation_length,
            current_frame: $animation_current_frame
        },
        background_color: $background
    }'
}

# shellcheck disable=SC2155
__print_compact_scene() {
    # shellcheck disable=SC2155
    declare project="$(__quote "$1")"

    __help_title "# Scene information in a human readable way" >&2
    __help_title "#" >&2
    __help_title "# 1) To get more information about it acquire it in JSON format like:" >&2
    __help_title "# > $PROGRAM get scene {{scene name}} $project" >&2
    __help_title "# 2) To hide this banner redirect $PROGRAM output to /dev/null like this:" >&2
    __help_title "# $PROGRAM $project 2>/dev/null" >&2

    declare name="$(__extract_scene_name "$project")"
    declare width="$(__extract_scene_width "$project")"
    declare height="$(__extract_scene_height "$project")"

    printf "${TEXT_COLOR}%s${RESET}: ${NUMBER_COLOR}%s${RESET}x${NUMBER_COLOR}%s${RESET}\n" "$name" "$width" "$height"
}

# shellcheck disable=SC2155
__print_detailed_scene() {
    __print_compact_scene "$1"

    declare id="$(__extract_scene_id "$1")"
    declare layer_count="$(__extract_scene_layer_count "$1")"
    declare animation_length="$(__extract_scene_animation_length "$1")"
    declare animation_current_frame="$(__extract_scene_animation_current_frame "$1")"

    printf "${INDENT} identifier: ${TEXT_COLOR}%s${RESET}\n" "$id"
    printf "${INDENT} amount of layers: ${TEXT_COLOR}%s${RESET}\n" "$layer_count"
    printf "${INDENT} animation length: ${TEXT_COLOR}%s${RESET}\n" "$animation_length"
    printf "${INDENT} animation current frame: ${TEXT_COLOR}%s${RESET}\n" "$animation_current_frame"
}

##################################################################################################################
# OBJECTS
##################################################################################################################
declare OBJECT_FUNCTION_MAP='{
    "name": "__extract_object_name",
    "id": "__extract_object_id",
    "width": "__extract_object_width",
    "height": "__extract_object_height",
    "stroke-opacity": "__extract_object_stroke_opacity",
    "stroke-width": "__extract_object_stroke_width",
    "stroke-cap": "__extract_object_stroke_cap",
    "stroke-join": "__extract_object_stroke_join",
    "stroke-dash": "__extract_object_stroke_dash",
    "stroke-gap": "__extract_object_stroke_gap",
    "stroke-red": "__extract_object_stroke_red_components",
    "stroke-green": "__extract_object_stroke_green_components",
    "stroke-blue": "__extract_object_stroke_blue_components",
    "stroke-alpha": "__extract_object_stroke_alpha_components",
    "fill-red": "__extract_object_fill_red_components",
    "fill-green": "__extract_object_fill_green_components",
    "fill-blue": "__extract_object_fill_blue_components",
    "fill-alpha": "__extract_object_fill_alpha_components",
    "position-x": "__extract_object_position_x_component",
    "position-y": "__extract_object_position_y_component",
    "position-z": "__extract_object_position_z_component",
    "rotation-x": "__extract_object_rotation_x_component",
    "rotation-y": "__extract_object_rotation_y_component",
    "rotation-z": "__extract_object_rotation_z_component",
    "scale-x": "__extract_object_scale_x_component",
    "scale-y": "__extract_object_scale_y_component"
}'

__extract_object_name() {
    declare project="$1"
    jq --raw-output '.name' "$project"
}

__extract_object_id() {
    declare project="$1"
    jq --raw-output '.id' "$project"
}

__extract_object_size_property() {
    declare property="$1"
    declare project="$2"

    jq --arg property "$property" --raw-output 'if .obj.image != null then
            .obj.image.bounds.size.value.keyed[$property]
        elif .obj.shape.geometry.rect != null then
            .obj.shape.geometry.rect.bounds.size.value.keyed[$property]
        elif .obj.shape.geometry.polygon != null then
            .obj.shape.geometry.polygon.bounds.size.value.keyed[$property]
        elif .obj.text != null then
            .obj.text.layout.text_box.size.value.keyed[$property]
        elif .obj.scene != null then
            .obj.scene.bounds.size.value.keyed[$property]
        else
            null
        end' "$project" 
}

__extract_object_width() {
    declare project="$1"
    __extract_object_size_property width "$project"
}

__extract_object_height() {
    declare project="$1"
    __extract_object_size_property height "$project"
}

__extract_object_stroke_opacity() {
    declare project="$1"
    jq --raw-output 'obj.scene.stroke.opacity.keyed' "$project"
}

__extract_object_stroke_width() {
    declare project="$1"
    jq --raw-output 'obj.scene.stroke.width.keyed' "$project"
}

__extract_object_stroke_cap() {
    declare project="$1"
    jq --raw-output 'obj.scene.stroke.cap.keyed' "$project"
}

__extract_object_stroke_join() {
    declare project="$1"
    jq --raw-output 'obj.scene.stroke.join.keyed' "$project"
}

__extract_object_stroke_dash() {
    declare project="$1"
    jq --raw-output 'obj.scene.stroke.dash.keyed' "$project"
}

__extract_object_stroke_gap() {
    declare project="$1"
    jq --raw-output 'obj.scene.stroke.gap.keyed' "$project"
}

__extract_object_stroke_red_components() { :; }
__extract_object_stroke_green_components() { :; }
__extract_object_stroke_blue_components() { :; }
__extract_object_stroke_alpha_components() { :; }

__extract_object_stroke_is_visible() { :; }
__extract_object_stroke_is_without_gaps() { :; }
__extract_object_stroke_is_gradient() { :; }

__extract_object_fill_red_components() { :; }
__extract_object_fill_green_components() { :; }
__extract_object_fill_blue_components() { :; }
__extract_object_fill_alpha_components() { :; }

__extract_object_fill_is_visible() { :; }
__extract_object_fill_is_gradient() { :; }

__extract_object_position_x_component() { :; }
__extract_object_position_y_component() { :; }
__extract_object_position_z_component() { :; }

__extract_object_rotation_x_component() { :; }
__extract_object_rotation_y_component() { :; }
__extract_object_rotation_z_component() { :; }

__extract_object_scale_x_component() { :; }
__extract_object_scale_y_component() { :; }

__extract_object_pivot_x_component() { :; }
__extract_object_pivot_y_component() { :; }

check_dependencies

help
#__extract_object_width "./Sample inputs/object.json"

#vmpf get layers --position-x gt 100 --position-y in 100..455