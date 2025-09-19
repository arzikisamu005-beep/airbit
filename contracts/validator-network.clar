;; Validator Network Contract
;; Handles validator registration, consensus voting, and data verification

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-VALIDATOR-EXISTS (err u201))
(define-constant ERR-VALIDATOR-NOT-FOUND (err u202))
(define-constant ERR-INSUFFICIENT-STAKE (err u203))
(define-constant ERR-ALREADY-SLASHED (err u204))
(define-constant ERR-INVALID-REPUTATION (err u205))
(define-constant ERR-COOLDOWN-ACTIVE (err u206))
(define-constant MIN-VALIDATOR-STAKE u5000000) ;; 5 STX minimum
(define-constant BASE-REPUTATION-SCORE u1000)
(define-constant SLASH-PENALTY u500000) ;; 0.5 STX
(define-constant WITHDRAWAL-COOLDOWN u1008) ;; ~1 week in blocks
(define-constant REWARD-MULTIPLIER u100)

;; Data structures
(define-map validators
  { validator: principal }
  {
    stake-amount: uint,
    reputation-score: uint,
    total-votes: uint,
    correct-votes: uint,
    registration-height: uint,
    last-activity: uint,
    is-active: bool,
    withdrawal-requested: uint
  }
)

(define-map validator-votes
  { proposal-id: uint, validator: principal }
  {
    vote-type: (string-ascii 20),
    vote-weight: uint,
    timestamp: uint,
    is-final: bool
  }
)

(define-map governance-proposals
  { proposal-id: uint }
  {
    proposer: principal,
    proposal-type: (string-ascii 30),
    description: (string-ascii 256),
    target-value: uint,
    votes-for: uint,
    votes-against: uint,
    total-weight: uint,
    created-at: uint,
    expires-at: uint,
    executed: bool
  }
)

(define-map validator-earnings
  { validator: principal }
  {
    total-earned: uint,
    last-claim: uint,
    pending-rewards: uint
  }
)

(define-map consensus-rounds
  { round-id: uint }
  {
    data-submission-id: uint,
    total-participants: uint,
    consensus-reached: bool,
    final-decision: bool,
    round-start: uint,
    round-end: uint
  }
)

;; Data variables
(define-data-var next-proposal-id uint u1)
(define-data-var next-round-id uint u1)
(define-data-var total-validators uint u0)
(define-data-var total-staked uint u0)
(define-data-var governance-threshold uint u6000) ;; 60% threshold

;; Public functions

;; Register as validator with stake
(define-public (register-validator (stake-amount uint))
  (let ((existing-validator (map-get? validators { validator: tx-sender })))
    (asserts! (is-none existing-validator) ERR-VALIDATOR-EXISTS)
    (asserts! (>= stake-amount MIN-VALIDATOR-STAKE) ERR-INSUFFICIENT-STAKE)
    
    (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))
    
    (map-set validators
      { validator: tx-sender }
      {
        stake-amount: stake-amount,
        reputation-score: BASE-REPUTATION-SCORE,
        total-votes: u0,
        correct-votes: u0,
        registration-height: stacks-block-height,
        last-activity: stacks-block-height,
        is-active: true,
        withdrawal-requested: u0
      }
    )
    
    (var-set total-validators (+ (var-get total-validators) u1))
    (var-set total-staked (+ (var-get total-staked) stake-amount))
    
    (ok tx-sender)
  )
)

;; Add additional stake
(define-public (add-stake (additional-amount uint))
  (let ((validator (unwrap! (map-get? validators { validator: tx-sender }) ERR-VALIDATOR-NOT-FOUND)))
    (asserts! (get is-active validator) ERR-NOT-AUTHORIZED)
    
    (try! (stx-transfer? additional-amount tx-sender (as-contract tx-sender)))
    
    (map-set validators
      { validator: tx-sender }
      (merge validator {
        stake-amount: (+ (get stake-amount validator) additional-amount),
        last-activity: stacks-block-height
      })
    )
    
    (var-set total-staked (+ (var-get total-staked) additional-amount))
    (ok (+ (get stake-amount validator) additional-amount))
  )
)

;; Vote on data validation consensus
(define-public (vote-on-consensus (round-id uint) (data-valid bool) (confidence uint))
  (let (
    (validator (unwrap! (map-get? validators { validator: tx-sender }) ERR-VALIDATOR-NOT-FOUND))
    (round (unwrap! (map-get? consensus-rounds { round-id: round-id }) ERR-INVALID-REPUTATION))
    (existing-vote (map-get? validator-votes { proposal-id: round-id, validator: tx-sender }))
  )
    (asserts! (get is-active validator) ERR-NOT-AUTHORIZED)
    (asserts! (is-none existing-vote) ERR-NOT-AUTHORIZED)
    (asserts! (<= confidence u100) ERR-INVALID-REPUTATION)
    (asserts! (not (get consensus-reached round)) ERR-NOT-AUTHORIZED)
    
    (let (
      (vote-weight (calculate-vote-weight 
                     (get stake-amount validator) 
                     (get reputation-score validator) 
                     confidence))
    )
      (map-set validator-votes
        { proposal-id: round-id, validator: tx-sender }
        {
          vote-type: (if data-valid "valid" "invalid"),
          vote-weight: vote-weight,
          timestamp: stacks-block-height,
          is-final: false
        }
      )
      
      ;; Update validator stats
      (map-set validators
        { validator: tx-sender }
        (merge validator {
          total-votes: (+ (get total-votes validator) u1),
          last-activity: stacks-block-height
        })
      )
      
      ;; Update round participation
      (map-set consensus-rounds
        { round-id: round-id }
        (merge round {
          total-participants: (+ (get total-participants round) u1)
        })
      )
      
      (ok vote-weight)
    )
  )
)

;; Create governance proposal
(define-public (create-proposal 
  (proposal-type (string-ascii 30)) 
  (description (string-ascii 256)) 
  (target-value uint))
  (let (
    (validator (unwrap! (map-get? validators { validator: tx-sender }) ERR-VALIDATOR-NOT-FOUND))
    (proposal-id (var-get next-proposal-id))
  )
    (asserts! (get is-active validator) ERR-NOT-AUTHORIZED)
    (asserts! (>= (get reputation-score validator) u800) ERR-INVALID-REPUTATION)
    
    (map-set governance-proposals
      { proposal-id: proposal-id }
      {
        proposer: tx-sender,
        proposal-type: proposal-type,
        description: description,
        target-value: target-value,
        votes-for: u0,
        votes-against: u0,
        total-weight: u0,
        created-at: stacks-block-height,
        expires-at: (+ stacks-block-height u1008), ;; 1 week voting period
        executed: false
      }
    )
    
    (var-set next-proposal-id (+ proposal-id u1))
    (ok proposal-id)
  )
)

;; Vote on governance proposal
(define-public (vote-on-proposal (proposal-id uint) (vote-for bool))
  (let (
    (validator (unwrap! (map-get? validators { validator: tx-sender }) ERR-VALIDATOR-NOT-FOUND))
    (proposal (unwrap! (map-get? governance-proposals { proposal-id: proposal-id }) ERR-INVALID-REPUTATION))
    (existing-vote (map-get? validator-votes { proposal-id: proposal-id, validator: tx-sender }))
  )
    (asserts! (get is-active validator) ERR-NOT-AUTHORIZED)
    (asserts! (is-none existing-vote) ERR-NOT-AUTHORIZED)
    (asserts! (< stacks-block-height (get expires-at proposal)) ERR-NOT-AUTHORIZED)
    (asserts! (not (get executed proposal)) ERR-NOT-AUTHORIZED)
    
    (let (
      (vote-weight (get stake-amount validator))
      (new-votes-for (if vote-for (+ (get votes-for proposal) vote-weight) (get votes-for proposal)))
      (new-votes-against (if vote-for (get votes-against proposal) (+ (get votes-against proposal) vote-weight)))
    )
      (map-set validator-votes
        { proposal-id: proposal-id, validator: tx-sender }
        {
          vote-type: (if vote-for "for" "against"),
          vote-weight: vote-weight,
          timestamp: stacks-block-height,
          is-final: true
        }
      )
      
      (map-set governance-proposals
        { proposal-id: proposal-id }
        (merge proposal {
          votes-for: new-votes-for,
          votes-against: new-votes-against,
          total-weight: (+ (get total-weight proposal) vote-weight)
        })
      )
      
      (ok vote-weight)
    )
  )
)

;; Request withdrawal of stake
(define-public (request-withdrawal)
  (let ((validator (unwrap! (map-get? validators { validator: tx-sender }) ERR-VALIDATOR-NOT-FOUND)))
    (asserts! (get is-active validator) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get withdrawal-requested validator) u0) ERR-COOLDOWN-ACTIVE)
    
    (map-set validators
      { validator: tx-sender }
      (merge validator {
        withdrawal-requested: stacks-block-height,
        is-active: false
      })
    )
    
    (ok stacks-block-height)
  )
)

;; Execute withdrawal after cooldown
(define-public (execute-withdrawal)
  (let ((validator (unwrap! (map-get? validators { validator: tx-sender }) ERR-VALIDATOR-NOT-FOUND)))
    (asserts! (> (get withdrawal-requested validator) u0) ERR-NOT-AUTHORIZED)
    (asserts! (>= (- stacks-block-height (get withdrawal-requested validator)) WITHDRAWAL-COOLDOWN) ERR-COOLDOWN-ACTIVE)
    
    (let ((stake-amount (get stake-amount validator)))
      (try! (as-contract (stx-transfer? stake-amount tx-sender tx-sender)))
      
      (map-delete validators { validator: tx-sender })
      (var-set total-validators (- (var-get total-validators) u1))
      (var-set total-staked (- (var-get total-staked) stake-amount))
      
      (ok stake-amount)
    )
  )
)

;; Claim validator rewards
(define-public (claim-rewards)
  (let (
    (validator (unwrap! (map-get? validators { validator: tx-sender }) ERR-VALIDATOR-NOT-FOUND))
    (earnings (default-to { total-earned: u0, last-claim: u0, pending-rewards: u0 }
                          (map-get? validator-earnings { validator: tx-sender })))
  )
    (let ((pending-amount (get pending-rewards earnings)))
      (asserts! (> pending-amount u0) ERR-INSUFFICIENT-STAKE)
      
      (try! (as-contract (stx-transfer? pending-amount tx-sender tx-sender)))
      
      (map-set validator-earnings
        { validator: tx-sender }
        (merge earnings {
          last-claim: stacks-block-height,
          pending-rewards: u0
        })
      )
      
      (ok pending-amount)
    )
  )
)

;; Read-only functions

(define-read-only (get-validator-info (validator principal))
  (map-get? validators { validator: validator })
)

(define-read-only (get-validator-vote (proposal-id uint) (validator principal))
  (map-get? validator-votes { proposal-id: proposal-id, validator: validator })
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? governance-proposals { proposal-id: proposal-id })
)

(define-read-only (get-consensus-round (round-id uint))
  (map-get? consensus-rounds { round-id: round-id })
)

(define-read-only (get-validator-earnings (validator principal))
  (map-get? validator-earnings { validator: validator })
)

(define-read-only (get-total-validators)
  (var-get total-validators)
)

(define-read-only (get-total-staked)
  (var-get total-staked)
)

(define-read-only (get-governance-threshold)
  (var-get governance-threshold)
)

;; Private functions

(define-private (calculate-vote-weight (stake uint) (reputation uint) (confidence uint))
  (let (
    (base-weight (/ stake u1000000)) ;; Normalize stake to reasonable range
    (reputation-multiplier (/ reputation u1000)) ;; Normalize reputation
    (confidence-factor (/ confidence u100)) ;; Normalize confidence
  )
    (* (* base-weight reputation-multiplier) confidence-factor)
  )
)

(define-private (update-validator-reputation (validator principal) (correct-vote bool))
  (match (map-get? validators { validator: validator })
    validator-info
    (let (
      (current-reputation (get reputation-score validator-info))
      (reputation-change (if correct-vote u50 (- u0 u25)))
      (new-reputation (if correct-vote 
                        (+ current-reputation reputation-change)
                        (if (> current-reputation u25) 
                            (- current-reputation u25) 
                            u0)))
    )
      (map-set validators
        { validator: validator }
        (merge validator-info {
          reputation-score: new-reputation,
          correct-votes: (if correct-vote (+ (get correct-votes validator-info) u1) (get correct-votes validator-info))
        })
      )
      (ok new-reputation)
    )
    (err ERR-VALIDATOR-NOT-FOUND)
  )
)

(define-private (distribute-validator-reward (validator principal) (reward-amount uint))
  (let (
    (current-earnings (default-to { total-earned: u0, last-claim: u0, pending-rewards: u0 }
                                   (map-get? validator-earnings { validator: validator })))
  )
    (map-set validator-earnings
      { validator: validator }
      (merge current-earnings {
        total-earned: (+ (get total-earned current-earnings) reward-amount),
        pending-rewards: (+ (get pending-rewards current-earnings) reward-amount)
      })
    )
    (ok reward-amount)
  )
)

(define-private (slash-validator (validator principal))
  (match (map-get? validators { validator: validator })
    validator-info
    (let (
      (current-stake (get stake-amount validator-info))
      (new-stake (if (> current-stake SLASH-PENALTY)
                     (- current-stake SLASH-PENALTY)
                     u0))
      (new-reputation (/ (get reputation-score validator-info) u2)) ;; Halve reputation
    )
      (map-set validators
        { validator: validator }
        (merge validator-info {
          stake-amount: new-stake,
          reputation-score: new-reputation,
          is-active: (> new-stake u0)
        })
      )
      
      (var-set total-staked (- (var-get total-staked) SLASH-PENALTY))
      (ok SLASH-PENALTY)
    )
    (err ERR-VALIDATOR-NOT-FOUND)
  )
)
