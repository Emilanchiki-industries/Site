#!/usr/bin/env bash

source ./formatter.sh

declare program=vmph

vmph_help() {
    about
    command: "$program" "a portable VectorMotion file parser"
    line

    header: Dependencies
    bullet_list:
        command: jq "used for reading VectorMotion project file"
        command: check-jsonschema "used to validate JSON part of VectorMotion later read by jq"
    list_end
    line

    header: Syntax
    bullet_list:
        command: "$program $(option: get) $(placeholder: "scene | layer | setting") $(placeholder: name) $(project_file)" "print scene, layer or global setting"
        command: "$program $(option: get) $(placeholder: "scenes | layers | settings") $(project_file)" "print resources, all scenes, all layers or global settings"
    list_end
}

vmph_help
