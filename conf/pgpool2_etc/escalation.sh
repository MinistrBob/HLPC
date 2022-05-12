#!/bin/bash
# This script is run by wd_escalation_command to bring down the virtual IP on other pgpool nodes
# before bringing up the virtual IP on the new active pgpool node.

set -o xtrace

PGPOOLS=(astra4 astra5 astra6)

VIP=172.26.12.190
DEVICE=eth0

for pgpool in "${PGPOOLS[@]}"; do
    [ "$HOSTNAME" = "$pgpool" ] && continue
    ssh -T postgres@$pgpool -i ~/.ssh/id_rsa_pgpool "/usr/bin/sudo /usr/bin/ip addr del $VIP/24 dev $DEVICE"
done
exit 0
