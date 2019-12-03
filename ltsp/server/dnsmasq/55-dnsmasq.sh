# This file is part of LTSP, https://ltsp.org
# Copyright 2019 the LTSP team, see AUTHORS
# SPDX-License-Identifier: GPL-3.0-or-later

# Configure dnsmasq for LTSP

DNS=${DNS:-0}
HTTP=${HTTP:-0}
PROXY_DHCP=${PROXY_DHCP:-1}
REAL_DHCP=${REAL_DHCP:-1}
TFTP=${TFTP:-1}

dnsmasq_cmdline() {
    local args

    args=$(re getopt -n "ltsp $_APPLET" -o "d:h:p:r:s:t:" -l \
        "dns:,http:,proxy-dhcp:,real-dhcp:,dns-server:,tftp:" -- "$@") ||
        usage 1
    eval "set -- $args"
    while true; do
        case "$1" in
            -d|--dns) shift; DNS=$1 ;;
            -h|--http) shift; HTTP=$1 ;;
            -p|--proxy-dhcp) shift; PROXY_DHCP=$1 ;;
            -r|--real-dhcp) shift; REAL_DHCP=$1 ;;
            -s|--dns-server) shift; DNS_SERVER=$1 ;;
            # Note that this is fine: ltsp -t... dnsmasq -t...
            -t|--tftp) shift; TFTP=$1 ;;
            --) shift; break ;;
            *) die "ltsp $_APPLET: error in cmdline: $*" ;;
        esac
        shift
    done
    run_main_functions "$_SCRIPTS" "$@"
}

dnsmasq_main() {
    test -f /etc/dnsmasq.d/ltsp-server-dnsmasq.conf &&
        die "Found LTSP5 configuration: /etc/dnsmasq.d/ltsp-server-dnsmasq.conf
Aborting, please remove the LTSP5 configuration first"
    mkdir -p "$TFTP_DIR"
    install_template "ltsp-dnsmasq.conf" "/etc/dnsmasq.d/ltsp-dnsmasq.conf" "\
s|^port=0|$(textifb "$DNS" "#&" "&")|
s|^dhcp-range=set:proxy.*|$(textifb "$PROXY_DHCP" "$(proxy_dhcp)" "#&")|
s|^dhcp-range=192.168.67.20.*|$(textifb "$REAL_DHCP" "&" "#&")|
s|^\(dhcp-option=option:dns-server,\).*|\1$(dns_server)|
s|^\(tftp-root=\).*|\1$TFTP_DIR|
s|^enable-tftp|$(textifb "$TFTP" "&" "#&")|
s|\"http://\${[^}]\+}/\(ltsp/ltsp.ipxe\)\"|$(textifb "$HTTP" "&" "\1")|
"
    restart_dnsmasq
}

dns_server() {
    local dns_server

    if [ -n "$DNS_SERVER" ]; then
        echo "$DNS_SERVER" | tr " " ","
        return 0
    fi
    dns_server=
    # Jessie doesn't have systemd-resolve
    if is_command systemd-resolve; then
        dns_server=$(LANG=C.UTF-8 rw systemd-resolve --status |
            sed -n '/DNS Servers:/,/:/s/.* \([0-9.]\{7,15\}\).*/\1/p' |
            grep -v '^127.0.' |
            tr '\n' ',')
    fi
    if [ -z "$dns_server" ]; then
        dns_server=$(rw awk '/^ *nameserver [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/ {
if ($2 !~ "127\\.0\\..*" ) printf "%s,",$2 }' /etc/resolv.conf)
    fi
    dns_server=${dns_server%,}
    dns_server=${dns_server:-8.8.8.8,208.67.222.222}
    test "$DNS" = "1" && dns_server="0.0.0.0,$dns_server"
    echo "$dns_server"
}

length_to_netmask() {
    local nm

    nm=$((0xffffffff ^ ((1 << (32 - $1)) - 1)))
    printf "%d.%d.%d.%d\n" "$(((nm >> 24) & 0xff))" \
        "$(((nm >> 16) & 0xff))" "$(((nm >> 8) & 0xff))" "$((nm & 0xff))"
}

proxy_dhcp() {
    local cidr _dummy subnet netmask separator

    ip route show | while read -r cidr _dummy; do
        subnet=${cidr%%/*}
        case "$subnet" in
            127.0.0.1|169.254.0.0|192.168.67.0|*[!0-9.]*)
                continue
                ;;
            *)  # Ignore single IP routes, like vbox NAT gateway
                test "$cidr" != "${cidr#*/}" || continue
                netmask=$(length_to_netmask "${cidr#*/}")
                # echo in dash translates "\n", use printf to keep it
                printf "%sdhcp-range=set:proxy,%s,proxy,%s" \
                    "${separator}" "$subnet" "$netmask"
                # Insert a separator only after the first line
                separator="\n"
                ;;
        esac
    done
}

restart_dnsmasq() {
    if [ "$DNS" = "1" ]; then
        # If systemd-resolved is running, disable it
        if grep -qws '3500007F:0035' /proc/net/tcp; then
            re mkdir -p /etc/systemd/resolved.conf.d
            re cat >/etc/systemd/resolved.conf.d/ltsp.conf <<EOF
# Generated by \`ltsp dnsmasq\`, see man:ltsp-dnsmasq(8)
[Resolve]
DNSStubListener=no
EOF
            echo "Disabled DNSStubListener in systemd-resolved"
            # The symlink may be relative or absolute, so better use grep
            if ls -l /etc/resolv.conf | grep -q /run/systemd/resolve/stub-resolv.conf; then
                re ln -sf ../run/systemd/resolve/resolv.conf /etc/resolv.conf
                echo "Symlinked /etc/resolv.conf to ../run/systemd/resolve/resolv.conf"
            fi
            # Restart the one that won't be listening in :53 first
            re systemctl restart systemd-resolved
        fi
        re systemctl restart dnsmasq
    else
        re systemctl restart dnsmasq
        if [ -f /etc/systemd/resolved.conf.d/ltsp.conf ]; then
            # We want to undo a previous --dns=1
            re rm -f /etc/systemd/resolved.conf.d/ltsp.conf
            echo "Reenabled DNSStubListener in systemd-resolved"
            if ls -l /etc/resolv.conf | grep -q /run/systemd/resolve/resolv.conf; then
                re ln -sf ../run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
                echo "Symlinked /etc/resolv.conf to ../run/systemd/resolve/stub-resolv.conf"
            fi
            re systemctl restart systemd-resolved
        fi
    fi
    echo "Restarted dnsmasq"
}
