#!/bin/bash
set -euo pipefail
pushd $(dirname "$0")/..

export RPC_URL="http://localhost:5050";

export WORLD_ADDRESS=$(cat ./manifest_dev.json | jq -r '.world.address')

export ACTIONS_ADDRESS=$(cat ./manifest_dev.json | jq -r '.contracts[0].address')

echo "---------------------------------------------------------------------------"
echo world : $WORLD_ADDRESS 
echo " "
echo actions : $ACTIONS_ADDRESS
echo "---------------------------------------------------------------------------"

# enable system -> models authorizations
sozo auth grant --world $WORLD_ADDRESS --wait writer \
 Card,$ACTIONS_ADDRESS \
 Game,$ACTIONS_ADDRESS \
 Player,$ACTIONS_ADDRESS \
 > /dev/null

echo "Default authorizations have been successfully set."