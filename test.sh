#!/bin/bash

RPC_URL=http://localhost:8545
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
CONTRACT_ADDR=0x5FbDB2315678afecb367f032d93F642f64180aa3

forge create --rpc-url $RPC_URL --private-key $PRIVATE_KEY src/Test.sol:ModifiersExecution
cast call --rpc-url $RPC_URL $CONTRACT_ADDR "number()(uint256)"
cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY $CONTRACT_ADDR "func()"
cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY $CONTRACT_ADDR "setNumber(uint256)" 42
