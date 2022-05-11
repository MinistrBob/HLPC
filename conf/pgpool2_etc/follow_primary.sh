#!/bin/bash
# This script is run after failover_command to synchronize the Standby with the new Primary 
#(После крушения старого Primary и повышения одного из Standbay до нового Primary, делает из старого Primary новый ещё один Standby.).
# First try pg_rewind. If pg_rewind failed, use pg_basebackup.

set -o xtrace

# Special values:
# 1)  %d = node id
# 2)  %h = hostname
# 3)  %p = port number
# 4)  %D = node database cluster path
# 5)  %m = new primary node id
# 6)  %H = new primary node hostname
# 7)  %M = old main node id
# 8)  %P = old primary node id
# 9)  %r = new primary port number
# 10) %R = new primary database cluster path
# 11) %N = old primary node hostname
# 12) %S = old primary node port number
# 13) %% = '%' character

NODE_ID="$1"
NODE_HOST="$2"
NODE_PORT="$3"
NODE_PGDATA="$4"
NEW_PRIMARY_NODE_ID="$5"
NEW_PRIMARY_NODE_HOST="$6"
OLD_MAIN_NODE_ID="$7"
OLD_PRIMARY_NODE_ID="$8"
NEW_PRIMARY_NODE_PORT="$9"
NEW_PRIMARY_NODE_PGDATA="${10}"

# HOME=/var/lib/postgresql - эту переменную не нужно определять она уже определена в ОС для каждого пользователя 
PGHOME=/usr/lib/postgresql/13
PGCONFIG=/etc/postgresql/13/main
# Пока что без архивных журналов (также удалил rm -rf ${ARCHIVEDIR}/* и restore_command = 'scp ${PRIMARY_NODE_HOST}:${ARCHIVEDIR}/%f %p')
# ARCHIVEDIR=/var/lib/pgsql/archivedir
REPLUSER=replicator
PCP_USER=pgpool
PGPOOL_PATH=/usr/sbin
PCP_PORT=9898
REPL_SLOT_NAME=${NODE_HOST//[-.]/_}

# Для отладки вывести все переменные
# ( set -o posix ; set )

echo follow_primary.sh: start: Standby node ${NODE_ID}

## Test passwordless SSH
echo follow_primary.sh: Test passwordless SSH
ssh -T -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null postgres@${NEW_PRIMARY_NODE_HOST} -i ~/.ssh/id_rsa_pgpool ls /tmp > /dev/null
if [ $? -ne 0 ]; then
    echo follow_primary.sh: end: passwordless SSH to postgres@${NEW_PRIMARY_NODE_HOST} failed. Please setup passwordless SSH.
    exit 1
fi

## Get PostgreSQL major version
echo follow_primary.sh: Get PostgreSQL major version
PGVERSION=`${PGHOME}/bin/initdb -V | awk '{print $3}' | sed 's/\..*//' | sed 's/\([0-9]*\)[a-zA-Z].*/\1/'`

echo follow_primary.sh: Check if PostgreSQL version more or equal 12
if [ $PGVERSION -ge 12 ]; then
    RECOVERYCONF=${NODE_PGDATA}/myrecovery.conf
else
    RECOVERYCONF=${NODE_PGDATA}/recovery.conf
fi

## Check the status of Standby
echo follow_primary.sh: Check the status of Standby
ssh -T -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    postgres@${NODE_HOST} -i ~/.ssh/id_rsa_pgpool ${PGHOME}/bin/pg_ctl -w -D ${NODE_PGDATA} status


## If Standby is running, synchronize it with the new Primary.
echo follow_primary.sh: Check If Standby is running, synchronize it with the new Primary.
if [ $? -eq 0 ]; then

    echo follow_primary.sh: pg_rewind for node ${NODE_ID}

    # Create replication slot "${REPL_SLOT_NAME}"
    echo follow_primary.sh: Create replication slot "${REPL_SLOT_NAME}"
    ${PGHOME}/bin/psql -h ${NEW_PRIMARY_NODE_HOST} -p ${NEW_PRIMARY_NODE_PORT} \
        -c "SELECT pg_create_physical_replication_slot('${REPL_SLOT_NAME}');"  >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo follow_primary.sh: create replication slot \"${REPL_SLOT_NAME}\" failed. You may need to create replication slot manually.
    fi

    echo follow_primary.sh: Do pg_rewind
    ssh -T -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null postgres@${NODE_HOST} -i ~/.ssh/id_rsa_pgpool "

        set -o errexit

        ${PGHOME}/bin/pg_ctl -w -m f -D ${NODE_PGDATA} stop

        ${PGHOME}/bin/pg_rewind -D ${NODE_PGDATA} --source-server=\"user=postgres host=${NEW_PRIMARY_NODE_HOST} port=${NEW_PRIMARY_NODE_PORT}\"

        rm -rf ${NODE_PGDATA}/pg_replslot/*

        cat > ${RECOVERYCONF} << EOT
primary_conninfo = 'host=${NEW_PRIMARY_NODE_HOST} port=${NEW_PRIMARY_NODE_PORT} user=${REPLUSER} application_name=${NODE_HOST} passfile=''${HOME}/.pgpass'''
recovery_target_timeline = 'latest'
primary_slot_name = '${REPL_SLOT_NAME}'
EOT

        if [ ${PGVERSION} -ge 12 ]; then
            sed -i -e \"\\\$ainclude_if_exists = '$(echo ${RECOVERYCONF} | sed -e 's/\//\\\//g')'\" \
                   -e \"/^include_if_exists = '$(echo ${RECOVERYCONF} | sed -e 's/\//\\\//g')'/d\" ${PGCONFIG}/postgresql.conf
            touch ${NODE_PGDATA}/standby.signal
        else
            echo \"standby_mode = 'on'\" >> ${RECOVERYCONF}
        fi

        ${PGHOME}/bin/pg_ctl -l /dev/null -w -D ${NODE_PGDATA} start

    "
    
    echo follow_primary.sh: Check result pg_rewind
    if [ $? -ne 0 ]; then
        echo follow_primary.sh: pg_rewind failed. Try pg_basebackup.

        ssh -T -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null postgres@${NODE_HOST} -i ~/.ssh/id_rsa_pgpool "

            set -o errexit

            # Execute pg_basebackup
            rm -rf ${NODE_PGDATA}
            ${PGHOME}/bin/pg_basebackup -h ${NEW_PRIMARY_NODE_HOST} -U $REPLUSER -p ${NEW_PRIMARY_NODE_PORT} -D ${NODE_PGDATA} -X stream

            cat > ${RECOVERYCONF} << EOT
primary_conninfo = 'host=${NEW_PRIMARY_NODE_HOST} port=${NEW_PRIMARY_NODE_PORT} user=${REPLUSER} application_name=${NODE_HOST} passfile=''${HOME}/.pgpass'''
recovery_target_timeline = 'latest'
primary_slot_name = '${REPL_SLOT_NAME}'
EOT

            if [ ${PGVERSION} -ge 12 ]; then
                sed -i -e \"\\\$ainclude_if_exists = '$(echo ${RECOVERYCONF} | sed -e 's/\//\\\//g')'\" \
                       -e \"/^include_if_exists = '$(echo ${RECOVERYCONF} | sed -e 's/\//\\\//g')'/d\" ${PGCONFIG}/postgresql.conf
                touch ${NODE_PGDATA}/standby.signal
            else
                echo \"standby_mode = 'on'\" >> ${RECOVERYCONF}
            fi
        "

        if [ $? -ne 0 ]; then

            echo follow_primary.sh: drop replication slot
            ${PGHOME}/bin/psql -h ${NEW_PRIMARY_NODE_HOST} -p ${NEW_PRIMARY_NODE_PORT} \
                -c "SELECT pg_drop_replication_slot('${REPL_SLOT_NAME}');"  >/dev/null 2>&1

            if [ $? -ne 0 ]; then
                echo ERROR: follow_primary.sh: drop replication slot \"${REPL_SLOT_NAME}\" failed. You may need to drop replication slot manually.
            fi

            echo follow_primary.sh: end: pg_basebackup failed
            exit 1
        fi

        echo follow_primary.sh: start Standby node on ${NODE_HOST}
        ssh -T -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
            postgres@${NODE_HOST} -i ~/.ssh/id_rsa_pgpool $PGHOME/bin/pg_ctl -l /dev/null -w -D ${NODE_PGDATA} start

    fi

    echo follow_primary.sh: If start Standby successfully, attach this node
    if [ $? -eq 0 ]; then

        echo follow_primary.sh: Run pcp_attact_node to attach Standby node to Pgpool-II.
        ${PGPOOL_PATH}/pcp_attach_node -w -h localhost -U $PCP_USER -p ${PCP_PORT} -n ${NODE_ID}

        if [ $? -ne 0 ]; then
            echo ERROR: follow_primary.sh: end: pcp_attach_node failed
            exit 1
        fi

    echo follow_primary.sh: If start Standby failed, drop replication slot "${REPL_SLOT_NAME}"
    else

        ${PGHOME}/bin/psql -h ${NEW_PRIMARY_NODE_HOST} -p ${NEW_PRIMARY_NODE_PORT} \
            -c "SELECT pg_drop_replication_slot('${REPL_SLOT_NAME}');"  >/dev/null 2>&1

        if [ $? -ne 0 ]; then
            echo ERROR: follow_primary.sh: drop replication slot \"${REPL_SLOT_NAME}\" failed. You may need to drop replication slot manually.
        fi

        echo ERROR: follow_primary.sh: end: follow primary command failed
        exit 1
    fi

else
    echo follow_primary.sh: end: failed_nod_id=${NODE_ID} is not running. skipping follow primary command
    exit 0
fi

echo follow_primary.sh: end: follow primary command is completed successfully
exit 0
