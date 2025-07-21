# Tumbex Smart Contract

**Contract Name:** `tumbex`  
**Version:** v1  
**Language:** Clarity (Stacks blockchain)

---

## Overview

Tumbex is a decentralized governance and treasury management smart contract for the Stacks blockchain. It enables community-driven proposals, voting, and fund allocation, with robust access control and upgradeability.

---

## Features

- **Proposals:**  
  - Submit funding or governance proposals.
  - Each proposal includes recipient, amount, description, deadline, type, required votes, and proposer.

- **Voting:**  
  - Users with voting power can vote on proposals.
  - Prevents double voting and tracks votes per proposal.

- **Execution:**  
  - Proposals can be executed if they pass quorum and are within the execution window.
  - Funding proposals transfer funds from the treasury.
  - Governance proposals are placeholders for future logic.

- **Administration:**  
  - Owner and admins can set voting power, add new admins, and pause/unpause the contract.

- **Treasury:**  
  - Tracks treasury balance.
  - Funds can be deposited and allocated via proposals.

- **Upgradeability:**  
  - Owner can update the contract implementation address.

---

## Data Structures

- **Maps:**
  - `proposals`: Stores proposal details.
  - `voted`: Tracks if a user has voted on a proposal.
  - `voting-power`: Voting power per principal.
  - `administrators`: Admin status per principal.
  - `proposal-types`: Human-readable proposal type names.

- **Data Vars:**
  - `prop-id`: Current proposal ID.
  - `contract-paused`: Pause status.
  - `implementation-address`: Address of contract implementation.
  - `treasury-balance`: Treasury funds.

---

## Key Constants

- `MINIMUM_VOTING_POWER`: Minimum voting power to submit proposals.
- `MAXIMUM_VOTING_POWER`: Maximum voting power allowed.
- `PROPOSAL_DURATION`: Voting period (in blocks).
- `EXECUTION_DELAY`: Execution window after voting ends.
- `QUORUM_THRESHOLD`: Minimum votes required for proposal to pass.

---

## Main Functions

### Read-Only

- `get-contract-info`: Returns contract name, version, and implementation address.
- `get-proposal`: Fetches proposal details.
- `get-voting-power`: Returns user's voting power.
- `get-treasury-balance`: Returns treasury balance.
- `is-contract-paused`: Checks if contract is paused.
- `get-current-proposal-id`: Returns current proposal ID.
- `has-user-voted`: Checks if user voted on a proposal.
- `can-execute-proposal`: Checks if proposal can be executed.
- `get-proposal-status`: Returns proposal status.

### Public

- `set-voting-power`: Admin sets voting power for a user.
- `add-administrator`: Owner adds a new admin.
- `pause-contract` / `unpause-contract`: Admin pauses/unpauses contract.
- `submit-proposal`: Submit a new proposal.
- `vote-on-proposal`: Vote on a proposal.
- `execute-proposal`: Execute a passed proposal.
- `deposit-funds`: Add funds to the treasury.
- `upgrade-implementation`: Owner upgrades contract implementation.

---

## Validation & Security

- Strict input validation for all functions.
- Role-based access control for admin actions.
- Prevents double voting and unauthorized actions.
- Proposal execution is strictly controlled by voting and timing rules.

---

## Usage

1. **Deposit Funds:**  
   Use `deposit-funds` to add funds to the treasury.

2. **Submit Proposal:**  
   Use `submit-proposal` to create a funding or governance proposal.

3. **Vote:**  
   Use `vote-on-proposal` to vote on active proposals.

4. **Execute Proposal:**  
   Use `execute-proposal` to execute proposals that have passed quorum and are within the execution window.

5. **Admin Actions:**  
   Owner/admins can set voting power, add admins, pause/unpause, and upgrade the contract.

---

## Notes

- **Funding Execution:**  
  Actual STX transfers are not implemented; treasury balance is updated internally.

- **Governance Execution:**  
  Placeholder for future governance logic.

- **Upgradeability:**  
  Owner can set a new implementation address for contract upgrades.

---

## License

MIT (or as specified by project)

---

## Author

[josephine dodo]

---

## Disclaimer

This contract is for educational and demonstration purposes. Review and audit before deploying on mainnet.
