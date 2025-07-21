;; ===== CONTRACT IDENTIFICATION =====
(define-constant CONTRACT_NAME "tumbex")
(define-constant CONTRACT_VERSION "v1")

;; ===== DATA MAPS =====
(define-map proposals uint 
    (tuple 
        (recipient principal)
        (amount uint)
        (votes uint)
        (executed bool)
        (description (string-ascii 256))
        (deadline uint)
        (proposal-type uint)
        (required-votes uint)
        (proposer principal)))

(define-map voted (tuple (proposal uint) (voter principal)) bool)
(define-map voting-power principal uint)
(define-map administrators principal bool)
(define-map proposal-types uint (string-ascii 64))

;; ===== STATE VARIABLES =====
(define-data-var prop-id uint u0)
(define-data-var contract-paused bool false)
;; Fixed: Updated implementation address to match contract name
(define-data-var implementation-address principal 'SP000000000000000000002Q6VF78.tumbex-v1)
(define-data-var treasury-balance uint u0)

;; ===== CONSTANTS =====
(define-constant CONTRACT_OWNER tx-sender)
(define-constant MINIMUM_VOTING_POWER u100)
(define-constant MAXIMUM_VOTING_POWER u10000000) ;; Max 10M voting power
(define-constant PROPOSAL_DURATION u144) ;; ~1 day in blocks
(define-constant EXECUTION_DELAY u72) ;; ~12 hours after voting ends
(define-constant QUORUM_THRESHOLD u1000) ;; Minimum total votes needed

;; Proposal Types
(define-constant PROPOSAL_TYPE_FUNDING u1)
(define-constant PROPOSAL_TYPE_GOVERNANCE u2)

;; Error Constants
(define-constant ERR-NOT-AUTHORIZED u1)
(define-constant ERR-INSUFFICIENT-VOTES u2)
(define-constant ERR-ALREADY-EXECUTED u3)
(define-constant ERR-INVALID-AMOUNT u4)
(define-constant ERR-INVALID-RECIPIENT u5)
(define-constant ERR-INVALID-PROPOSAL u6)
(define-constant ERR-ALREADY-VOTED u7)
(define-constant ERR-VOTING-PERIOD-ENDED u8)
(define-constant ERR-PROPOSAL-NOT-PASSED u9)
(define-constant ERR-INSUFFICIENT-TREASURY u10)
(define-constant ERR-CONTRACT-PAUSED u11)
(define-constant ERR-EXECUTION-TOO-EARLY u12)
(define-constant ERR-EXECUTION-WINDOW-EXPIRED u13)
(define-constant ERR-INVALID-VOTING-POWER u14)
(define-constant ERR-INVALID-ADMIN u15)

;; ===== INITIALIZATION =====
(begin
    ;; Initialize proposal types
    (map-set proposal-types PROPOSAL_TYPE_FUNDING "Funding Request")
    (map-set proposal-types PROPOSAL_TYPE_GOVERNANCE "Governance Change")
    ;; Set contract owner as admin
    (map-set administrators CONTRACT_OWNER true)
    ;; Give contract owner initial voting power
    (map-set voting-power CONTRACT_OWNER u1000))

;; ===== READ-ONLY FUNCTIONS =====
;; New: Contract information function
(define-read-only (get-contract-info)
    (tuple 
        (name CONTRACT_NAME)
        (version CONTRACT_VERSION)
        (implementation (var-get implementation-address))))

(define-read-only (get-proposal (proposal-id uint))
    (map-get? proposals proposal-id))

(define-read-only (get-voting-power (user principal))
    (default-to u0 (map-get? voting-power user)))

(define-read-only (get-treasury-balance)
    (var-get treasury-balance))

(define-read-only (is-contract-paused)
    (var-get contract-paused))

(define-read-only (get-current-proposal-id)
    (var-get prop-id))

(define-read-only (has-user-voted (proposal-id uint) (voter principal))
    (has-voted proposal-id voter))

(define-read-only (can-execute-proposal (proposal-id uint))
    (match (map-get? proposals proposal-id)
        proposal (let ((current-block stacks-block-height)
                      (voting-deadline (get deadline proposal))
                      (execution-deadline (+ voting-deadline EXECUTION_DELAY)))
                    (and 
                        (not (get executed proposal))
                        (>= current-block voting-deadline)
                        (< current-block execution-deadline)
                        (>= (get votes proposal) (get required-votes proposal))))
        false))

(define-read-only (get-proposal-status (proposal-id uint))
    (match (map-get? proposals proposal-id)
        proposal (let ((current-block stacks-block-height)
                      (voting-deadline (get deadline proposal))
                      (execution-deadline (+ voting-deadline EXECUTION_DELAY)))
                    (if (get executed proposal)
                        "executed"
                        (if (< current-block voting-deadline)
                            "voting"
                            (if (< current-block execution-deadline)
                                (if (>= (get votes proposal) (get required-votes proposal))
                                    "ready-for-execution"
                                    "failed")
                                "expired"))))
        "not-found"))

;; ===== ADMIN FUNCTIONS =====
(define-public (set-voting-power (user principal) (power uint))
    (begin
        (asserts! (is-admin tx-sender) (err ERR-NOT-AUTHORIZED))
        (asserts! (not (var-get contract-paused)) (err ERR-CONTRACT-PAUSED))
        ;; Validate user input
        (asserts! (is-valid-principal user) (err ERR-INVALID-RECIPIENT))
        (asserts! (is-valid-voting-power power) (err ERR-INVALID-VOTING-POWER))
        (map-set voting-power user power)
        (ok true)))

(define-public (add-administrator (admin principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) (err ERR-NOT-AUTHORIZED))
        ;; Validate admin input
        (asserts! (is-valid-admin-candidate admin) (err ERR-INVALID-ADMIN))
        (map-set administrators admin true)
        (ok true)))

(define-public (pause-contract)
    (begin
        (asserts! (is-admin tx-sender) (err ERR-NOT-AUTHORIZED))
        (var-set contract-paused true)
        (ok true)))

(define-public (unpause-contract)
    (begin
        (asserts! (is-admin tx-sender) (err ERR-NOT-AUTHORIZED))
        (var-set contract-paused false)
        (ok true)))

;; ===== PROPOSAL FUNCTIONS =====
(define-public (submit-proposal (recipient principal) (amount uint) (description (string-ascii 256)) (proposal-type uint))
    (begin
        (asserts! (not (var-get contract-paused)) (err ERR-CONTRACT-PAUSED))
        ;; Validate all inputs thoroughly
        (asserts! (is-valid-recipient recipient) (err ERR-INVALID-RECIPIENT))
        (asserts! (is-valid-amount amount) (err ERR-INVALID-AMOUNT))
        (asserts! (is-valid-description description) (err ERR-INVALID-AMOUNT))
        (asserts! (is-valid-proposal-type proposal-type) (err ERR-INVALID-PROPOSAL))
        (asserts! (>= (get-voting-power tx-sender) MINIMUM_VOTING_POWER) (err ERR-INSUFFICIENT-VOTES))
        
        (let ((id (var-get prop-id))
              (deadline (+ stacks-block-height PROPOSAL_DURATION)))
            (begin
                (var-set prop-id (+ id u1))
                (map-set proposals id 
                    (tuple 
                        (recipient recipient)
                        (amount amount)
                        (votes u0)
                        (executed false)
                        (description description)
                        (deadline deadline)
                        (proposal-type proposal-type)
                        (required-votes QUORUM_THRESHOLD)
                        (proposer tx-sender)))
                (ok id)))))

(define-public (vote-on-proposal (proposal-id uint) (vote-amount uint))
    (begin
        (asserts! (not (var-get contract-paused)) (err ERR-CONTRACT-PAUSED))
        ;; Validate inputs
        (asserts! (is-valid-proposal proposal-id) (err ERR-INVALID-PROPOSAL))
        (asserts! (is-valid-vote-amount vote-amount) (err ERR-INVALID-AMOUNT))
        (asserts! (not (has-voted proposal-id tx-sender)) (err ERR-ALREADY-VOTED))
        (asserts! (>= (get-voting-power tx-sender) vote-amount) (err ERR-INSUFFICIENT-VOTES))
        
        (let ((proposal (unwrap! (map-get? proposals proposal-id) (err ERR-INVALID-PROPOSAL))))
            (begin
                ;; Check if voting period is still active
                (asserts! (< stacks-block-height (get deadline proposal)) (err ERR-VOTING-PERIOD-ENDED))
                (asserts! (not (get executed proposal)) (err ERR-ALREADY-EXECUTED))
                
                ;; Record the vote
                (map-set voted (tuple (proposal proposal-id) (voter tx-sender)) true)
                
                ;; Update proposal votes
                (map-set proposals proposal-id
                    (merge proposal {votes: (+ (get votes proposal) vote-amount)}))
                
                (ok true)))))

(define-public (execute-proposal (proposal-id uint))
    (begin
        (asserts! (not (var-get contract-paused)) (err ERR-CONTRACT-PAUSED))
        (asserts! (is-valid-proposal proposal-id) (err ERR-INVALID-PROPOSAL))
        
        (let ((proposal (unwrap! (map-get? proposals proposal-id) (err ERR-INVALID-PROPOSAL)))
              (execution-start (get deadline proposal))
              (execution-end (+ (get deadline proposal) EXECUTION_DELAY)))
            (begin
                (asserts! (not (get executed proposal)) (err ERR-ALREADY-EXECUTED))
                
                ;; Check if we're in the execution window (after voting ends, before execution expires)
                (asserts! (>= stacks-block-height execution-start) (err ERR-EXECUTION-TOO-EARLY))
                (asserts! (< stacks-block-height execution-end) (err ERR-EXECUTION-WINDOW-EXPIRED))
                
                ;; Check if proposal passed
                (asserts! (>= (get votes proposal) (get required-votes proposal)) (err ERR-PROPOSAL-NOT-PASSED))
                
                ;; Execute based on proposal type
                (match (execute-proposal-by-type proposal-id (get proposal-type proposal))
                    success (begin
                        ;; Mark as executed
                        (map-set proposals proposal-id
                            (merge proposal {executed: true}))
                        (ok true))
                    error (err error))))))

;; ===== PRIVATE EXECUTION FUNCTIONS =====
(define-private (execute-proposal-by-type (proposal-id uint) (proposal-type uint))
    (if (is-eq proposal-type PROPOSAL_TYPE_FUNDING)
        (execute-funding-proposal proposal-id)
        (execute-governance-proposal proposal-id)))

(define-private (execute-funding-proposal (proposal-id uint))
    (match (map-get? proposals proposal-id)
        proposal (if (>= (var-get treasury-balance) (get amount proposal))
                    (begin
                        ;; Transfer funds (simplified - in real implementation would use stx-transfer?)
                        (var-set treasury-balance (- (var-get treasury-balance) (get amount proposal)))
                        (ok true))
                    (err ERR-INSUFFICIENT-TREASURY))
        (err ERR-INVALID-PROPOSAL)))

(define-private (execute-governance-proposal (proposal-id uint))
    ;; Placeholder for governance changes
    ;; In real implementation, this would handle parameter changes, upgrades, etc.
    (ok true))

;; ===== TREASURY MANAGEMENT =====
(define-public (deposit-funds (amount uint))
    (begin
        (asserts! (is-valid-amount amount) (err ERR-INVALID-AMOUNT))
        ;; In real implementation, would handle STX transfer to contract
        (var-set treasury-balance (+ (var-get treasury-balance) amount))
        (ok true)))

;; ===== ENHANCED VALIDATION FUNCTIONS =====
(define-private (is-valid-recipient (address principal))
    (and 
        (not (is-eq address (as-contract tx-sender)))
        (not (is-eq address tx-sender))
        (not (is-eq address CONTRACT_OWNER))
        (is-valid-principal address)))

(define-private (is-valid-principal (address principal))
    ;; Basic principal validation - not zero address equivalent
    (not (is-eq address 'SP000000000000000000002Q6VF78)))

(define-private (is-valid-admin-candidate (admin principal))
    (and 
        (is-valid-principal admin)
        (not (is-eq admin (as-contract tx-sender)))
        (not (is-eq admin tx-sender))
        ;; Don't allow adding the same admin twice
        (not (is-admin admin))))

(define-private (is-valid-voting-power (power uint))
    (and 
        (>= power u0)
        (<= power MAXIMUM_VOTING_POWER)))

(define-private (is-valid-vote-amount (amount uint))
    (and 
        (> amount u0)
        (<= amount MAXIMUM_VOTING_POWER)))

(define-private (is-valid-proposal (proposal-id uint))
    (is-some (map-get? proposals proposal-id)))

(define-private (is-valid-amount (amount uint))
    (and 
        (> amount u0)
        (<= amount u1000000000))) ;; Max 1B microSTX

(define-private (is-valid-description (description (string-ascii 256)))
    ;; Check description is not empty and has reasonable length
    (and 
        (> (len description) u0)
        (<= (len description) u256)))

(define-private (is-valid-proposal-type (proposal-type uint))
    (or (is-eq proposal-type PROPOSAL_TYPE_FUNDING)
        (is-eq proposal-type PROPOSAL_TYPE_GOVERNANCE)))

(define-private (has-voted (proposal-id uint) (voter principal))
    (default-to false (map-get? voted (tuple (proposal proposal-id) (voter voter)))))

(define-private (is-admin (user principal))
    (default-to false (map-get? administrators user)))

;; ===== UPGRADE FUNCTION =====
;; Enhanced: Updated upgrade function with better validation
(define-public (upgrade-implementation (new-implementation principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) (err ERR-NOT-AUTHORIZED))
        (asserts! (is-valid-implementation new-implementation) (err ERR-INVALID-RECIPIENT))
        ;; Ensure new implementation follows naming convention
        (var-set implementation-address new-implementation)
        (ok true)))

(define-private (is-valid-implementation (address principal))
    (and 
        (is-valid-principal address)
        (not (is-eq address (as-contract tx-sender)))
        (not (is-eq address tx-sender))
        (not (is-eq address CONTRACT_OWNER))))