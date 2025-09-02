# Tumbex Smart Contract v2

A decentralized governance and treasury management contract for the Stacks blockchain, now with advanced delegation, timelock, and veto features.

---

## Overview

Tumbex v2 enables decentralized communities to propose, vote, and execute funding or governance actions with robust security and flexibility. This upgrade introduces **voting power delegation**, **timelock queues**, and **community veto** mechanisms, making governance more transparent and resistant to abuse.

---

## Features

### 🗳️ Proposals & Voting
- **Submit proposals** for funding or governance changes.
- **Vote** on proposals using your effective voting power (base + delegated).
- **Quorum and deadlines** enforced for proposal passage.

### 👥 Delegation System
- **Delegate your voting power** to another user.
- **Revoke delegation** at any time.
- **Limits** on delegation depth and number of delegations per user to prevent abuse.
- **Effective voting power** is cached and updated automatically.

### ⏳ Timelock & Veto
- **Timelock queue**: Passed proposals enter a waiting period before execution.
- **Review period**: Community can veto proposals during this window.
- **Veto threshold**: If enough veto power is used, the proposal fails.

### 🏦 Treasury Management
- **Deposit funds** into the contract treasury.
- **Funding proposals** can allocate treasury funds if passed and executed.

### 🔒 Administration
- **Admins** can set voting power, add new admins, and pause/unpause the contract.
- **Owner** can upgrade the contract implementation address.

---

## Data Structures

- **proposals**: Proposal details (recipient, amount, votes, etc.)
- **voted**: Tracks who voted on which proposal.
- **voting-power**: Base voting power per user.
- **delegations**: Delegation relationships.
- **delegation-counts**: Number of delegations received.
- **effective-voting-power**: Cached effective voting power.
- **timelocks**: Timelock and veto status for proposals.
- **veto-votes**: Tracks who vetoed a proposal.
- **administrators**: Admin status.
- **proposal-types**: Human-readable proposal type names.

---

## Key Constants

- **MINIMUM_VOTING_POWER**: Minimum to submit proposals.
- **MAXIMUM_VOTING_POWER**: Maximum allowed.
- **PROPOSAL_DURATION**: Voting period (in blocks).
- **EXECUTION_DELAY**: Time after voting ends before execution.
- **QUORUM_THRESHOLD**: Minimum votes for passage.
- **TIMELOCK_QUEUE_PERIOD**: Timelock queue duration.
- **TIMELOCK_REVIEW_PERIOD**: Veto review duration.
- **VETO_THRESHOLD_PERCENTAGE**: % of total voting power needed to veto.
- **MAX_DELEGATION_DEPTH**: Prevents delegation cycles.
- **MAX_DELEGATIONS_PER_USER**: Prevents spam.

---

## Main Functions

### Read-Only
- `get-contract-info`
- `get-proposal`
- `get-voting-power`
- `get-effective-voting-power`
- `get-delegation`
- `get-timelock`
- `get-treasury-balance`
- `is-contract-paused`
- `get-current-proposal-id`
- `has-user-voted`
- `has-user-vetoed`
- `can-execute-proposal`
- `get-proposal-status`

### Public
- `delegate-voting-power`
- `revoke-delegation`
- `queue-proposal`
- `veto-proposal`
- `set-voting-power`
- `add-administrator`
- `pause-contract`
- `unpause-contract`
- `submit-proposal`
- `vote-on-proposal`
- `execute-proposal`
- `deposit-funds`
- `upgrade-implementation`

---

## Security & Validation

- **Strict input validation** and error handling.
- **Role-based access control** for admin actions.
- **Cycle detection** in delegation.
- **Timelock and veto** add extra security to proposal execution.
- **Double voting and abuse prevention** mechanisms.

---

## Usage Example

1. **Deposit funds:**  
   `deposit-funds (amount)`

2. **Submit a proposal:**  
   `submit-proposal (recipient) (amount) (description) (proposal-type)`

3. **Vote:**  
   `vote-on-proposal (proposal-id) (vote-amount)`

4. **Delegate voting power:**  
   `delegate-voting-power (delegate)`

5. **Queue and execute proposal:**  
   `queue-proposal (proposal-id)` → `execute-proposal (proposal-id)`

6. **Veto during review:**  
   `veto-proposal (proposal-id) (veto-power)`

---

## License

MIT (or as specified by project)

---

## Disclaimer

This contract is for demonstration and educational purposes. Review and audit before deploying on mainnet.
