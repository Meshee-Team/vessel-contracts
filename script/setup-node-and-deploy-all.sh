#!/bin/bash
# This script can be used to set up a testing environment on local machine

# kill and start node in background
PID=$(lsof -t -i:8545)
if [ ! -z "$PID" ]; then
    echo "Killing process on port 8545 with PID $PID"
    kill -9 $PID
else
    echo "No process is listening on port 8545"
fi
mkdir -p logs &&
nohup anvil --mnemonic "test test test test test test test test test test test junk" -a 10 --balance 1000000 -p 8545 --no-cors --chain-id 31337  > logs/anvil.log &

# build smart contract
cd .. &&
pnpm run clean &&
pnpm run build

# deploy staging environment
cd script &&
pnpm install &&
tsc &&
node prod-deploy-vault.js --nonce=0 > logs/staging_deploy.log
node test-deploy-tokens.js --nonce=10000 >> logs/staging_deploy.log &&
node prod-update-snark-verifier.js >> logs/staging_deploy.log &&
node test-register-and-activate-tokens.js >> logs/staging_deploy.log

status=$?
if [ $status -eq 0 ]; then
    echo "Staging environment contracts are deployed successfully."
else
    echo "Fail to deploy staging environment with exit code $status."
fi

# deploy test environemnt
node prod-deploy-vault.js --nonce=20000 > logs/test_deploy.log &&
node prod-update-snark-verifier.js >> logs/test_deploy.log &&
node test-register-and-activate-tokens.js >> logs/test_deploy.log

status=$?
if [ $status -eq 0 ]; then
    echo "Test environment contracts are deployed successfully."
else
    echo "Fail to deploy test environment with exit code $status."
fi

