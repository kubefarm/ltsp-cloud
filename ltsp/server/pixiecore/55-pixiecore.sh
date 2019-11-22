# This file is part of LTSP, https://ltsp.github.io
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Runs pixiecore compatible api-server

pixiecore_cmdline() {
    local args

    args=$(getopt -n "ltsp $_APPLET" -o "p:" -l \
        "port:" -- "$@") ||
        usage 1
    eval "set -- $args"
    while true; do
        case "$1" in
            -p|--port) shift; HTTP_PORT=$1 ;;
            --) shift; break ;;
            *) die "ltsp $_APPLET: error in cmdline: $*" ;;
        esac
        shift
    done
    test "$#" = "0" || usage 1
    run_main_functions "$_SCRIPTS" "$@"
}

pixiecore_main() {
    HTTP_PORT=${HTTP_PORT:-8080}
    echo "Starting server on :${HTTP_PORT}"
    socat -v -T0.05 tcp-l:${HTTP_PORT},reuseaddr,fork system:"$_APPLET_DIR/handle.sh"
}
