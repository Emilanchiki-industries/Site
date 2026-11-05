#!/usr/bin/env bash

source ./colors.sh

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
