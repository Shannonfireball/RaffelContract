-include .env

DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

.PHONY: all test deploy help

help: 
	@echo "Usage:"
	@echo "make deploy [ARGS=...]"


build:; forge build

install:; forge install Cyfrin/foundry-devops && forge install transmissions11/solmate && forge install smartcontractkit/chainlink-evm

test:; forge test

NETWORK_ARGS := --rpc-url $(RPC_URL) --private-key $(PRIVATE_KEY) --broadcast
# if --network sepolia 
ifeq ($(findstring --network sepolia,$(ARGS)), --network sepolia)
	NETWORK_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY_METAMASK_ETH) --broadcast --verify --etherscan-api-key $(ETHER_SCAN_API_KEY) -vvvv
endif

deploy: 
	@forge script script/DeployRaffle.s.sol:DeployRaffle