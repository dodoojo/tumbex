;; ===== CONTRACT IDENTIFICATION =====
(define-constant CONTRACT_NAME "tumbex")
(define-constant CONTRACT_VERSION "v2")

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

;; ===== NEW: DELEGATION SYSTEM =====
(define-map delegations principal principal) ;; delegator -> delegate
(define-map delegation-counts principal uint) ;; count of delegations received
(define-map effective-voting-power principal uint) ;; cached effective power

;; ===== NEW: TIMELOCK SYSTEM =====
(define-map timelocks uint (tuple
    (proposal-id uint)
    (stage uint) ;; 1=queued, 2=review, 3=ready, 4=executed
    (queue-time uint)
    (review-deadline uint)
    (execution-deadline uint)
    (veto-threshold uint)
    (veto-votes uint)))

(define-map veto-votes (tuple (proposal uint) (voter principal)) bool)

;; ===== STATE VARIABLES =====
(define-data-var prop-id uint u0)
(define-data-var contract-paused bool false)
(define-data-var implementation-address principal 'SP000000000000000000002Q6VF78.tumbex-v1)
(define-data-var treasury-balance uint u0)

;; ===== CONSTANTS =====
(define-constant CONTRACT_OWNER tx-sender)
(define-constant MINIMUM_VOTING_POWER u100)
(define-constant MAXIMUM_VOTING_POWER u10000000) ;; Max 10M voting power
(define-constant PROPOSAL_DURATION u144) ;; ~1 day in blocks
(define-constant EXECUTION_DELAY u72) ;; ~12 hours after voting ends
(define-constant QUORUM_THRESHOLD u1000) ;; Minimum total votes needed

;; NEW: Timelock Constants
(define-constant TIMELOCK_QUEUE_PERIOD u288) ;; 2 days
(define-constant TIMELOCK_REVIEW_PERIOD u432) ;; 3 days
(define-constant VETO_THRESHOLD_PERCENTAGE u25) ;; 25% can veto

;; NEW: Delegation Constants
(define-constant MAX_DELEGATION_DEPTH u5) ;; Prevent long delegation chains
(define-constant MAX_DELEGATIONS_PER_USER u100) ;; Prevent spam

;; Proposal Types
(define-constant PROPOSAL_TYPE_FUNDING u1)
(define-constant PROPOSAL_TYPE_GOVERNANCE u2)

;; Timelock Stages
(define-constant STAGE_QUEUED u1)
(define-constant STAGE_REVIEW u2)
(define-constant STAGE_READY u3)
(define-constant STAGE_EXECUTED u4)

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
(define-constant ERR-DELEGATION-CYCLE u16)
(define-constant ERR-ALREADY-DELEGATED u17)
(define-constant ERR-NO-DELEGATION u18)
(define-constant ERR-TIMELOCK-NOT-READY u19)
(define-constant ERR-ALREADY-VETOED u20)
(define-constant ERR-VETO-PERIOD-ENDED u21)
(define-constant ERR-MAX-DELEGATIONS-EXCEEDED u22)

;; ===== BASIC HELPER FUNCTIONS (NO DEPENDENCIES) =====
(define-private (has-voted (proposal-id uint) (voter principal))
    (default-to false (map-get? voted (tuple (proposal proposal-id) (voter voter)))))

(define-private (is-admin (user principal))
    (default-to false (map-get? administrators user)))

(define-private (is-valid-principal (address principal))
    (not (is-eq address 'SP000000000000000000002Q6VF78)))

(define-private (is-valid-recipient (address principal))
    (and 
        (not (is-eq address (as-contract tx-sender)))
        (not (is-eq address tx-sender))
        (not (is-eq address CONTRACT_OWNER))
        (is-valid-principal address)))

(define-private (is-valid-admin-candidate (admin principal))
    (and 
        (is-valid-principal admin)
        (not (is-eq admin (as-contract tx-sender)))
        (not (is-eq admin tx-sender))
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
        (<= amount u1000000000)))

(define-private (is-valid-description (description (string-ascii 256)))
    (and 
        (> (len description) u0)
        (<= (len description) u256)))

(define-private (is-valid-proposal-type (proposal-type uint))
    (or (is-eq proposal-type PROPOSAL_TYPE_FUNDING)
        (is-eq proposal-type PROPOSAL_TYPE_GOVERNANCE)))

(define-private (is-valid-implementation (address principal))
    (and 
        (is-valid-principal address)
        (not (is-eq address (as-contract tx-sender)))
        (not (is-eq address tx-sender))
        (not (is-eq address CONTRACT_OWNER))))

;; ===== POWER CALCULATION FUNCTIONS (NO DELEGATION DEPENDENCIES) =====
(define-private (get-base-voting-power (user principal))
    (default-to u0 (map-get? voting-power user)))

(define-private (get-delegation-count (delegate principal))
    (default-to u0 (map-get? delegation-counts delegate)))

(define-private (calculate-delegated-power (delegate principal))
    ;; Simplified implementation - returns delegation count * 100
    ;; In full implementation, would iterate through all delegators
    (* (get-delegation-count delegate) u100))

(define-private (calculate-total-power)
    ;; Simplified calculation - in full implementation would sum all effective voting power
    u1000000)

;; ===== INITIALIZATION =====
(begin
    ;; Initialize proposal types
    (map-set proposal-types PROPOSAL_TYPE_FUNDING "Funding Request")
    (map-set proposal-types PROPOSAL_TYPE_GOVERNANCE "Governance Change")
    ;; Set contract owner as admin
    (map-set administrators CONTRACT_OWNER true)
    ;; Give contract owner initial voting power
    (map-set voting-power CONTRACT_OWNER u1000)
    ;; Initialize effective voting power
    (map-set effective-voting-power CONTRACT_OWNER u1000))

;; ===== READ-ONLY FUNCTIONS =====
(define-read-only (get-contract-info)
    (tuple 
        (name CONTRACT_NAME)
        (version CONTRACT_VERSION)
        (implementation (var-get implementation-address))))

(define-read-only (get-proposal (proposal-id uint))
    (map-get? proposals proposal-id))

(define-read-only (get-voting-power (user principal))
    (get-base-voting-power user))

(define-read-only (get-effective-voting-power (user principal))
    (default-to u0 (map-get? effective-voting-power user)))

(define-read-only (get-delegation (delegator principal))
    (map-get? delegations delegator))

(define-read-only (get-timelock (proposal-id uint))
    (map-get? timelocks proposal-id))

(define-read-only (get-treasury-balance)
    (var-get treasury-balance))

(define-read-only (is-contract-paused)
    (var-get contract-paused))

(define-read-only (get-current-proposal-id)
    (var-get prop-id))

(define-read-only (has-user-voted (proposal-id uint) (voter principal))
    (has-voted proposal-id voter))

(define-read-only (has-user-vetoed (proposal-id uint) (voter principal))
    (default-to false (map-get? veto-votes (tuple (proposal proposal-id) (voter voter)))))

(define-read-only (can-execute-proposal (proposal-id uint))
    (match (map-get? proposals proposal-id)
        proposal (match (map-get? timelocks proposal-id)
            timelock (let ((current-block stacks-block-height))
                        (and 
                            (not (get executed proposal))
                            (is-eq (get stage timelock) STAGE_READY)
                            (>= current-block (get execution-deadline timelock))
                            (>= (get votes proposal) (get required-votes proposal))
                            (< (get veto-votes timelock) (get veto-threshold timelock))))
            ;; Fallback to old execution logic for proposals without timelock
            (let ((current-block stacks-block-height)
                  (voting-deadline (get deadline proposal))
                  (execution-deadline (+ voting-deadline EXECUTION_DELAY)))
                (and 
                    (not (get executed proposal))
                    (>= current-block voting-deadline)
                    (< current-block execution-deadline)
                    (>= (get votes proposal) (get required-votes proposal)))))
        false))

(define-read-only (get-proposal-status (proposal-id uint))
    (match (map-get? proposals proposal-id)
        proposal (match (map-get? timelocks proposal-id)
            timelock (let ((current-block stacks-block-height)
                          (stage (get stage timelock)))
                        (if (get executed proposal)
                            "executed"
                            (if (is-eq stage STAGE_QUEUED)
                                "queued"
                                (if (is-eq stage STAGE_REVIEW)
                                    "under-review"
                                    (if (is-eq stage STAGE_READY)
                                        "ready-for-execution"
                                        "failed")))))
            ;; Fallback for proposals without timelock
            (let ((current-block stacks-block-height)
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
                            "expired")))))
        "not-found"))

;; ===== DELEGATION FUNCTIONS (COMPLETELY INDEPENDENT) =====
(define-public (delegate-voting-power (delegate principal))
    (begin
        (asserts! (not (var-get contract-paused)) (err ERR-CONTRACT-PAUSED))
        (asserts! (is-valid-principal delegate) (err ERR-INVALID-RECIPIENT))
        (asserts! (not (is-eq delegate tx-sender)) (err ERR-INVALID-RECIPIENT))
        (asserts! (is-none (map-get? delegations tx-sender)) (err ERR-ALREADY-DELEGATED))
        
        ;; Inline cycle detection to avoid function dependencies
        (let ((cycle-check-result 
                ;; Check if delegate already delegates to tx-sender (simple 2-level check)
                (match (map-get? delegations delegate)
                    delegate-target (is-eq delegate-target tx-sender)
                    false)))
            (asserts! (not cycle-check-result) (err ERR-DELEGATION-CYCLE))
            
            ;; Check delegation limits
            (let ((current-delegations (get-delegation-count delegate)))
                (asserts! (< current-delegations MAX_DELEGATIONS_PER_USER) (err ERR-MAX-DELEGATIONS-EXCEEDED))
                
                ;; Set delegation
                (map-set delegations tx-sender delegate)
                (map-set delegation-counts delegate (+ current-delegations u1))
                
                ;; Update effective voting powers
                (let ((delegator-base-power (get-base-voting-power tx-sender))
                      (delegator-delegated-power (calculate-delegated-power tx-sender))
                      (delegate-base-power (get-base-voting-power delegate))
                      (delegate-delegated-power (calculate-delegated-power delegate)))
                    (map-set effective-voting-power tx-sender (+ delegator-base-power delegator-delegated-power))
                    (map-set effective-voting-power delegate (+ delegate-base-power delegate-delegated-power)))
                
                (ok true)))))

(define-public (revoke-delegation)
    (begin
        (asserts! (not (var-get contract-paused)) (err ERR-CONTRACT-PAUSED))
        (match (map-get? delegations tx-sender)
            delegate (begin
                ;; Remove delegation
                (map-delete delegations tx-sender)
                
                ;; Update delegation count
                (let ((current-delegations (get-delegation-count delegate)))
                    (if (> current-delegations u1)
                        (map-set delegation-counts delegate (- current-delegations u1))
                        (map-delete delegation-counts delegate)))
                
                ;; Update effective voting powers
                (let ((delegator-base-power (get-base-voting-power tx-sender))
                      (delegator-delegated-power (calculate-delegated-power tx-sender))
                      (delegate-base-power (get-base-voting-power delegate))
                      (delegate-delegated-power (calculate-delegated-power delegate)))
                    (map-set effective-voting-power tx-sender (+ delegator-base-power delegator-delegated-power))
                    (map-set effective-voting-power delegate (+ delegate-base-power delegate-delegated-power)))
                
                (ok true))
            (err ERR-NO-DELEGATION))))

;; ===== TIMELOCK FUNCTIONS =====
(define-public (queue-proposal (proposal-id uint))
    (begin
        (asserts! (not (var-get contract-paused)) (err ERR-CONTRACT-PAUSED))
        (asserts! (is-valid-proposal proposal-id) (err ERR-INVALID-PROPOSAL))
        
        (let ((proposal (unwrap! (map-get? proposals proposal-id) (err ERR-INVALID-PROPOSAL)))
              (current-block stacks-block-height)
              (total-voting-power (calculate-total-power))
              (veto-threshold (/ (* total-voting-power VETO_THRESHOLD_PERCENTAGE) u100)))
            
            ;; Check if proposal passed and voting period ended
            (asserts! (>= current-block (get deadline proposal)) (err ERR-VOTING-PERIOD-ENDED))
            (asserts! (>= (get votes proposal) (get required-votes proposal)) (err ERR-PROPOSAL-NOT-PASSED))
            (asserts! (not (get executed proposal)) (err ERR-ALREADY-EXECUTED))
            (asserts! (is-none (map-get? timelocks proposal-id)) (err ERR-ALREADY-EXECUTED))
            
            ;; Create timelock
            (map-set timelocks proposal-id
                (tuple
                    (proposal-id proposal-id)
                    (stage STAGE_QUEUED)
                    (queue-time current-block)
                    (review-deadline (+ current-block TIMELOCK_REVIEW_PERIOD))
                    (execution-deadline (+ current-block (+ TIMELOCK_QUEUE_PERIOD TIMELOCK_REVIEW_PERIOD)))
                    (veto-threshold veto-threshold)
                    (veto-votes u0)))
            
            (ok true))))

(define-public (veto-proposal (proposal-id uint) (veto-power uint))
    (begin
        (asserts! (not (var-get contract-paused)) (err ERR-CONTRACT-PAUSED))
        (asserts! (is-valid-proposal proposal-id) (err ERR-INVALID-PROPOSAL))
        (asserts! (not (has-user-vetoed proposal-id tx-sender)) (err ERR-ALREADY-VETOED))
        (asserts! (>= (get-effective-voting-power tx-sender) veto-power) (err ERR-INSUFFICIENT-VOTES))
        
        (match (map-get? timelocks proposal-id)
            timelock (let ((current-block stacks-block-height))
                        ;; Check if in review period
                        (asserts! (< current-block (get review-deadline timelock)) (err ERR-VETO-PERIOD-ENDED))
                        (asserts! (is-eq (get stage timelock) STAGE_QUEUED) (err ERR-TIMELOCK-NOT-READY))
                        
                        ;; Record veto vote
                        (map-set veto-votes (tuple (proposal proposal-id) (voter tx-sender)) true)
                        
                        ;; Update veto count
                        (let ((new-veto-votes (+ (get veto-votes timelock) veto-power)))
                            (map-set timelocks proposal-id
                                (merge timelock {veto-votes: new-veto-votes}))
                            
                            ;; Check if veto threshold reached
                            (if (>= new-veto-votes (get veto-threshold timelock))
                                ;; Proposal vetoed - mark as failed
                                (map-set timelocks proposal-id
                                    (merge timelock {stage: u99})) ;; Special failed stage
                                ;; Continue to review stage if time passed
                                (if (>= current-block (get review-deadline timelock))
                                    (map-set timelocks proposal-id
                                        (merge timelock {stage: STAGE_READY}))
                                    true))
                            
                            (ok true)))
            (err ERR-INVALID-PROPOSAL))))

;; ===== ADMIN FUNCTIONS =====
(define-public (set-voting-power (user principal) (power uint))
    (begin
        (asserts! (is-admin tx-sender) (err ERR-NOT-AUTHORIZED))
        (asserts! (not (var-get contract-paused)) (err ERR-CONTRACT-PAUSED))
        (asserts! (is-valid-principal user) (err ERR-INVALID-RECIPIENT))
        (asserts! (is-valid-voting-power power) (err ERR-INVALID-VOTING-POWER))
        
        (map-set voting-power user power)
        ;; Update effective voting power inline
        (let ((base-power (get-base-voting-power user))
              (delegated-power (calculate-delegated-power user)))
            (map-set effective-voting-power user (+ base-power delegated-power)))
        (ok true)))

(define-public (add-administrator (admin principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) (err ERR-NOT-AUTHORIZED))
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
        (asserts! (is-valid-recipient recipient) (err ERR-INVALID-RECIPIENT))
        (asserts! (is-valid-amount amount) (err ERR-INVALID-AMOUNT))
        (asserts! (is-valid-description description) (err ERR-INVALID-AMOUNT))
        (asserts! (is-valid-proposal-type proposal-type) (err ERR-INVALID-PROPOSAL))
        (asserts! (>= (get-effective-voting-power tx-sender) MINIMUM_VOTING_POWER) (err ERR-INSUFFICIENT-VOTES))
        
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
        (asserts! (is-valid-proposal proposal-id) (err ERR-INVALID-PROPOSAL))
        (asserts! (is-valid-vote-amount vote-amount) (err ERR-INVALID-AMOUNT))
        (asserts! (not (has-voted proposal-id tx-sender)) (err ERR-ALREADY-VOTED))
        (asserts! (>= (get-effective-voting-power tx-sender) vote-amount) (err ERR-INSUFFICIENT-VOTES))
        
        (let ((proposal (unwrap! (map-get? proposals proposal-id) (err ERR-INVALID-PROPOSAL))))
            (begin
                (asserts! (< stacks-block-height (get deadline proposal)) (err ERR-VOTING-PERIOD-ENDED))
                (asserts! (not (get executed proposal)) (err ERR-ALREADY-EXECUTED))
                
                (map-set voted (tuple (proposal proposal-id) (voter tx-sender)) true)
                (map-set proposals proposal-id
                    (merge proposal {votes: (+ (get votes proposal) vote-amount)}))
                
                (ok true)))))

(define-public (execute-proposal (proposal-id uint))
    (begin
        (asserts! (not (var-get contract-paused)) (err ERR-CONTRACT-PAUSED))
        (asserts! (is-valid-proposal proposal-id) (err ERR-INVALID-PROPOSAL))
        
        (let ((proposal (unwrap! (map-get? proposals proposal-id) (err ERR-INVALID-PROPOSAL))))
            (begin
                (asserts! (not (get executed proposal)) (err ERR-ALREADY-EXECUTED))
                (asserts! (can-execute-proposal proposal-id) (err ERR-TIMELOCK-NOT-READY))
                
                (match (execute-proposal-by-type proposal-id (get proposal-type proposal))
                    success (begin
                        (map-set proposals proposal-id
                            (merge proposal {executed: true}))
                        ;; Update timelock stage if exists
                        (match (map-get? timelocks proposal-id)
                            timelock (map-set timelocks proposal-id
                                        (merge timelock {stage: STAGE_EXECUTED}))
                            true)
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
                        (var-set treasury-balance (- (var-get treasury-balance) (get amount proposal)))
                        (ok true))
                    (err ERR-INSUFFICIENT-TREASURY))
        (err ERR-INVALID-PROPOSAL)))

(define-private (execute-governance-proposal (proposal-id uint))
    (ok true))

;; ===== TREASURY MANAGEMENT =====
(define-public (deposit-funds (amount uint))
    (begin
        (asserts! (is-valid-amount amount) (err ERR-INVALID-AMOUNT))
        (var-set treasury-balance (+ (var-get treasury-balance) amount))
        (ok true)))

;; ===== UPGRADE FUNCTION =====
(define-public (upgrade-implementation (new-implementation principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) (err ERR-NOT-AUTHORIZED))
        (asserts! (is-valid-implementation new-implementation) (err ERR-INVALID-RECIPIENT))
        (var-set implementation-address new-implementation)
        (ok true)))
