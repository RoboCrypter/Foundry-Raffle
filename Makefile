-include .env

deploy:; forge script script/Raffle.s.sol --rpc-url $(ANVIL_RPC_URL) --private-key $(ANVIL_PRIVATE_KEY) --broadcast

deploy-sepolia-verify:; forge script script/Raffle.s.sol --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --verify --etherscan-api-key $(ETHERSCAN_API_KEY) --broadcast

cast-enter-raffle:; cast send 0x0358530Ce39E335156cf6E78d29EFDA4D5537E6a "enterRaffle()" --value 0.01ether --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY)

test-sepolia:; forge test --rpc-url $(SEPOLIA_RPC_URL)