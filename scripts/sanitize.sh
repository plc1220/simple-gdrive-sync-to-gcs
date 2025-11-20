#!/bin/bash
sanitize() {
    echo "$1" | tr '[:upper:]' '[:lower:]' \
        | sed 's/ /-/g' \
        | sed 's/[^a-z0-9-]//g' \
        | sed 's/--*/-/g'
}

sanitize "$1"
