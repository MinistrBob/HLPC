#!/bin/bash
# This script is run by failover_command. Some standby node promote to a primary. 

set -o xtrace

# Special values:
# 1)  %d = failed node id = FAILED_NODE_ID=0
# 2)  %h = failed node hostname = FAILED_NODE_HOST=astra1
# 3)  %p = failed node port number = FAILED_NODE_PORT=5432
# 4)  %D = failed node database cluster path = FAILED_NODE_PGDATA=/var/lib/postgresql/13/main
# 5)  %m = new main node id = NEW_MAIN_NODE_ID=1
# 6)  %H = new main node hostname = NEW_MAIN_NODE_HOST=astra2
# 7)  %M = old main node id = OLD_MAIN_NODE_ID=0
# 8)  %P = old primary node id = OLD_PRIMARY_NODE_ID=0
# 9)  %r = new main port number = NEW_MAIN_NODE_PORT=5432
# 10) %R = new main database cluster path = NEW_MAIN_NODE_PGDATA=/var/lib/postgresql/13/main
# 11) %N = old primary node hostname = OLD_PRIMARY_NODE_HOST=astra1
# 12) %S = old primary node port number = OLD_PRIMARY_NODE_PORT=5432
# 13) %% = '%' character

FAILED_NODE_ID="$1"
FAILED_NODE_HOST="$2"
FAILED_NODE_PORT="$3"
FAILED_NODE_PGDATA="$4"
NEW_MAIN_NODE_ID="$5"
NEW_MAIN_NODE_HOST="$6"
OLD_MAIN_NODE_ID="$7"
OLD_PRIMARY_NODE_ID="$8"
NEW_MAIN_NODE_PORT="$9"
NEW_MAIN_NODE_PGDATA="${10}"
OLD_PRIMARY_NODE_HOST="${11}"
OLD_PRIMARY_NODE_PORT="${12}"

PGHOME=/usr/lib/postgresql/13
REPL_SLOT_NAME=${FAILED_NODE_HOST//[-.]/_}

# Для отладки вывести все переменные
# ( set -o posix ; set )

echo failover.sh: start: failed_node_id=$FAILED_NODE_ID failed_host=$FAILED_NODE_HOST \
    old_primary_node_id=$OLD_PRIMARY_NODE_ID new_main_node_id=$NEW_MAIN_NODE_ID new_main_host=$NEW_MAIN_NODE_HOST

## If there's no main node anymore, skip failover.
echo failover.sh: Check If there is no main node anymore, skip failover.
if [ $NEW_MAIN_NODE_ID -lt 0 ]; then
    echo failover.sh: All nodes are down. Skipping failover.
    exit 0
fi

echo failover.sh: Test passwordless SSH
## Test passwordless SSH
ssh -T postgres@${NEW_MAIN_NODE_HOST} -i ~/.ssh/id_rsa_pgpool ls /tmp > /dev/null
if [ $? -ne 0 ]; then
    echo failover.sh: passwordless SSH to postgres@${NEW_MAIN_NODE_HOST} failed. Please setup passwordless SSH.
    exit 1
fi

## If Standby node is down, skip failover.
## При этом делается попытка удалить слот репликации с мастера
echo failover.sh: If Standby node is down, skip failover, but try remove replication slot
if [ $OLD_PRIMARY_NODE_ID != "-1" -a $FAILED_NODE_ID != $OLD_PRIMARY_NODE_ID ]; then

    # If Standby node is down, drop replication slot.
    ${PGHOME}/bin/psql -h ${OLD_PRIMARY_NODE_HOST} -p ${OLD_PRIMARY_NODE_PORT} \
        -c "SELECT pg_drop_replication_slot('${REPL_SLOT_NAME}');"

    if [ $? -ne 0 ]; then
        echo ERROR: failover.sh: drop replication slot \"${REPL_SLOT_NAME}\" failed. You may need to drop replication slot manually.
    fi

    echo failover.sh: end: standby node is down. Skipping failover.
    exit 0
fi

## Promote Standby node.
echo failover.sh: primary node is down, promote new_main_node_id=$NEW_MAIN_NODE_ID on ${NEW_MAIN_NODE_HOST}.
ssh -T postgres@${NEW_MAIN_NODE_HOST} -i ~/.ssh/id_rsa_pgpool ${PGHOME}/bin/pg_ctl -D ${NEW_MAIN_NODE_PGDATA} -w promote
if [ $? -ne 0 ]; then
    echo ERROR: failover.sh: end: failover failed
    exit 1
fi

echo failover.sh: end: new_main_node_id=$NEW_MAIN_NODE_ID on ${NEW_MAIN_NODE_HOST} is promoted to a primary
exit 0
