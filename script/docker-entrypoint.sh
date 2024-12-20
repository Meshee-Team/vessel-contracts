#!/usr/bin/env sh
# This script is the entrypoint of Dockerfile, which is used to set up a testing/staging environment
set -ex
tsx test-deploy-tokens.ts --nonce=1000
tsx test-deploy-weth.ts --nonce=2000
tsx prod-v2-deploy-new.ts --nonce=3000
tsx prod-update-snark-verifier.ts
echo "contracts are deployed successfully."
