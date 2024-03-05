#!/usr/bin/env bash

source ./scripts/util.sh
set -u +e

cleanup() {
    # Check if any background jobs are running before attempting to kill them
    if [[ $(jobs -p) ]]; then
        kill $(jobs -p) 2>/dev/null
    fi
}

trap cleanup EXIT

BASE_CLA_PORT=31000

index=$1

# Function to find an available port
find_available_port() {
    local port=$1
    while nc -z localhost $port; do
        port=$((port + 1))
    done
    echo $port
}

cl_data_dir $index
datadir=$cl_data_dir
port=$(find_available_port $BASE_CLA_PORT)
echo "Selected port for libp2p communication: $port"

http_port=$((BASE_CLA_PORT + index))  # Fix: Use BASE_CLA_PORT for HTTP port calculation
log_file=$datadir/beacon_node.log

echo "Started the lighthouse beacon node #$index which is now listening at port $port and http at port $http_port. You can see the log at $log_file"

# --disable-packet-filter is necessary because it's involved in rate limiting and nodes per IP limit
# See https://github.com/sigp/discv5/blob/v0.1.0/src/socket/filter/mod.rs#L149-L186
sleep 5
$LIGHTHOUSE_CMD beacon_node \
    --datadir $datadir \
    --testnet-dir $CONSENSUS_DIR \
    --execution-endpoint http://localhost:$(expr $BASE_EL_RPC_PORT + $index) \
    --execution-jwt $datadir/jwtsecret \
    --enable-private-discovery \
    --staking \
    --enr-address 127.0.0.1 \
    --enr-udp-port $port \
    --enr-tcp-port $port \
    --port $port \
    --http \
    --http-port $http_port \
    --disable-packet-filter \
    < /dev/null > $log_file 2>&1

if test $? -ne 0; then
    node_error "The lighthouse beacon node #$index returns an error. The last 10 lines of the log file are shown below.\n\n$(tail -n 10 $log_file)"
    exit 1
fi
