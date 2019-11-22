#!/bin/sh
echo 'HTTP/1.0 200 OK'
echo 'Content-Type: text/plain'
echo "Date: $(date)"
echo "Server: $SOCAT_SOCKADDR:$SOCAT_SOCKPORT"
echo "Client: $SOCAT_PEERADDR:$SOCAT_PEER_PORT"
echo "Content-Type: application/vnd.api+json"
echo 'Connection: close'
echo

cat <<EOT
{
  "kernel": "/srv/tftp/ltsp/x86_64/vmlinuz",
  "initrd": ["/srv/tftp/ltsp/x86_64/initrd.img", "/srv/tftp/ltsp/ltsp.img"],
  "cmdline": "ltsp.image=\"{{ ID \"/srv/ltsp/images/x86_64.img\" }}\" loop.max_part=9"
}
EOT
