# Piggy Boss

Piggy Boss is a target-based savings dApp designed to help individuals build a consistent savings habit on the Stacks blockchain. Savers lock funds toward personal goals, track their progress on-chain, and unlock non-transferable achievement NFTs as proof of discipline once a target is met. The project currently ships with a mock STX token for local development and testing.

## Why Piggy Boss?
- **Solve financial procrastination:** Encourage users to break large ambitions into actionable, measurable savings goals.
- **Reward discipline:** Completed goals automatically mint a commemorative NFT that cannot be traded away, reinforcing the personal achievement.
- **Build healthy habits:** Transparent progress tracking and gentle penalty mechanics make it easier to stay committed without eliminating flexibility.

## Core Features
- **Target Savings Goals:** Create individual savings goals with a target amount, time horizon, and purpose description.
- **Progress Tracking:** Read-only views expose current balance, completion percentage, and expiration status per goal.
- **Secure Deposits:** Users deposit the supported SIP-010 token into a goal vault controlled by the contract.
- **Goal Completion Withdrawals:** Once a goal is fulfilled, owners can withdraw their full balance and close the goal.
- **Emergency Withdrawals:** Users can unlock funds early with a configurable penalty that feeds the protocol treasury.
- **Achievement NFTs:** Successful goals mint a soulbound NFT, cementing the user’s habit-building milestone.
- **Admin Controls:** The contract owner can withdraw accumulated penalties, configure metadata, and manage mock token settings for local testing.

## Contract Overview

| Contract | Purpose |
| --- | --- |
| `contracts/savings-goals.clar` | Core vault logic for creating goals, handling deposits, processing withdrawals, and minting achievement NFTs upon completion. |
| `contracts/achievement-nft.clar` | SIP-009 compliant but soulbound NFT contract that mints a unique token per completed goal. |
| `contracts/mock-stx-token.clar` | SIP-010 compatible fungible token used for local development and Clarinet testing. |
| `contracts/sip010-ft-trait.clar` | Trait declaration for SIP-010 fungible tokens. |
| `contracts/sip009-nft-trait.clar` | Trait declaration for SIP-009 NFTs. |

## Getting Started

### Prerequisites
- [Clarinet](https://docs.hiro.so/clarinet/getting-started) CLI
- Node.js 18+ and npm (for TypeScript unit tests)
- Git

### Clone the Repository
```bash
git clone https://github.com/Akanimoh12/stacks-piggy-boss.git
cd stacks-piggy-boss/contract
```

### Install Node Dependencies
```bash
npm install
```

### Run Static Analysis
Clarinet validates contracts and ensures all invariants compile cleanly.
```bash
clarinet check
```

### Execute Tests
```bash
npm test
```

## Usage Guide

### 1. Create a Savings Goal
```clarity
(contract-call? .savings-goals create-goal u1000000 u720 "Travel Fund")
```
- `target-amount`: amount of the supported token to save.
- `duration-blocks`: number of blocks the goal remains active.
- `purpose`: UTF-8 description stored on-chain.

### 2. Deposit Toward a Goal
```clarity
(contract-call? .savings-goals deposit u0 u5000)
```
- Transfers `u5000` mock STX from the sender into the goal vault.
- Emits a `deposit-made` event with updated totals.

### 3. Check Progress
```clarity
(contract-call? .savings-goals get-goal-progress u0)
```
- Returns target, current balance, completion percentage, and completion flag.

### 4. Withdraw Upon Completion
```clarity
(contract-call? .savings-goals withdraw-completed u0)
```
- Only callable by the goal owner when the target has been met.
- Moves funds back to the saver and deactivates the goal.

### 5. Emergency Withdraw (With Penalty)
```clarity
(contract-call? .savings-goals emergency-withdraw u0)
```
- Allows the owner to access funds early while allocating 10% to the protocol penalty reserve.

### 6. Claim Achievement NFT
```clarity
(contract-call? .savings-goals claim-achievement-nft u0)
```
- Mints a soulbound NFT from `achievement-nft.clar` that references the goal metadata.

## Mock Token Notes
- The mock SIP-010 token is purposely restrictive to mimic production controls.
- Only the contract owner can mint new tokens, and they must mint to themselves for clarity.
- Transfers are only permitted between the owner and the savings vault to keep local testing deterministic.
- Replace `.mock-stx-token` with a production SIP-010 contract when deploying to testnet/mainnet.

## Habit-Building Mechanisms
- **Purpose Field:** Enforces a non-empty narrative for each goal, encouraging mindful saving.
- **Progress Transparency:** Regular progress calls and events keep users accountable.
- **Penalty Structure:** Early exits are possible but disincentivized, reinforcing discipline without locking users out of emergencies.
- **Soulbound Rewards:** NFTs cannot be traded, emphasizing personal achievement instead of speculation.

## Security Considerations
- Single-owner admin actions are limited to minting test tokens and withdrawing penalties.
- Clarinet check passes with zero warnings, ensuring no consumer-controlled principal is forwarded unchecked.
- Emergency withdrawal mechanics always move penalties into the contract-controlled reserve.
- Achievement NFTs refuse third-party transfers, protecting each user’s badge from social engineering or loss.

## Roadmap Ideas
- Integrate a production SIP-010 token (e.g., Wrapped STX or USDC).
- Add recurring deposit schedules via off-chain automation or SIP-010 allowances.
- Expand the NFT metadata with on-chain badge tiers or streak counters.
- Build a frontend dashboard that visualizes savings milestones and NFT galleries.

## Contributing
Pull requests are welcome. Please:
1. Create an issue describing the proposed enhancement or bug fix.
2. Run `clarinet check` and `npm test` before submitting.
3. Include tests that demonstrate the behavior change where possible.

## License
Released under the [MIT License](LICENSE).

