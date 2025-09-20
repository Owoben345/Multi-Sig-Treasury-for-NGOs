(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-PROPOSAL (err u101))
(define-constant ERR-PROPOSAL-NOT-FOUND (err u102))
(define-constant ERR-ALREADY-VOTED (err u103))
(define-constant ERR-PROPOSAL-EXPIRED (err u104))
(define-constant ERR-PROPOSAL-NOT-APPROVED (err u105))
(define-constant ERR-INSUFFICIENT-FUNDS (err u106))
(define-constant ERR-INVALID-AMOUNT (err u107))
(define-constant ERR-DONOR-EXISTS (err u108))
(define-constant ERR-DONOR-NOT-FOUND (err u109))
(define-constant ERR-INVALID-STATE (err u110))
(define-constant ERR-EMERGENCY-ACTIVE (err u111))
(define-constant ERR-MILESTONE-NOT-FOUND (err u112))
(define-constant ERR-SPENDING-LIMIT-EXCEEDED (err u113))

(define-data-var contract-owner principal tx-sender)
(define-data-var proposal-counter uint u0)
(define-data-var total-treasury uint u0)
(define-data-var min-approval-percentage uint u60)
(define-data-var emergency-mode bool false)
(define-data-var emergency-withdrawal-count uint u0)
(define-data-var milestone-achievement-counter uint u0)
(define-data-var daily-spending-limit-percent uint u10)
(define-data-var weekly-spending-limit-percent uint u25)
(define-data-var current-day-start uint u0)
(define-data-var current-week-start uint u0)
(define-data-var daily-spent uint u0)
(define-data-var weekly-spent uint u0)

(define-map donors principal 
  {
    donation-amount: uint,
    is-active: bool,
    joined-at: uint,
    current-milestone-tier: uint,
    total-milestones-achieved: uint
  }
)

(define-map proposals uint
  {
    title: (string-ascii 100),
    description: (string-ascii 500),
    amount: uint,
    recipient: principal,
    created-by: principal,
    created-at: uint,
    expires-at: uint,
    yes-votes: uint,
    no-votes: uint,
    total-voting-power: uint,
    is-executed: bool,
    is-active: bool
  }
)

(define-map proposal-votes {proposal-id: uint, voter: principal}
  {
    vote: bool,
    voting-power: uint,
    voted-at: uint
  }
)

(define-map donor-list uint principal)
(define-data-var donor-count uint u0)

(define-map donation-history uint
  {
    donor: principal,
    amount: uint,
    timestamp: uint,
    block-height: uint
  }
)

(define-data-var donation-counter uint u0)

(define-map emergency-withdrawals uint
  {
    amount: uint,
    withdrawn-at: uint,
    block-height: uint,
    reason: (string-ascii 200)
  }
)

(define-map milestone-tiers uint
  {
    threshold: uint,
    voting-multiplier: uint,
    tier-name: (string-ascii 50)
  }
)

(define-map milestone-achievements uint
  {
    donor: principal,
    tier-achieved: uint,
    achieved-at: uint,
    block-height: uint,
    donation-amount-at-achievement: uint
  }
)

(define-public (add-donor (donor principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (asserts! (is-none (map-get? donors donor)) ERR-DONOR-EXISTS)
    (map-set donors donor {
      donation-amount: u0,
      is-active: true,
      joined-at: stacks-block-height,
      current-milestone-tier: u0,
      total-milestones-achieved: u0
    })
    (map-set donor-list (var-get donor-count) donor)
    (var-set donor-count (+ (var-get donor-count) u1))
    (ok true)
  )
)

(define-public (donate)
  (let (
    (amount (stx-get-balance tx-sender))
    (donor-data (map-get? donors tx-sender))
    (donation-id (+ (var-get donation-counter) u1))
  )
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (is-some donor-data) ERR-DONOR-NOT-FOUND)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (let (
      (updated-amount (+ (get donation-amount (unwrap-panic donor-data)) amount))
      (new-tier (get-milestone-tier-for-amount updated-amount))
      (current-tier (get current-milestone-tier (unwrap-panic donor-data)))
    )
      (map-set donors tx-sender (merge (unwrap-panic donor-data) {
        donation-amount: updated-amount,
        current-milestone-tier: new-tier,
        total-milestones-achieved: (if (> new-tier current-tier)
          (+ (get total-milestones-achieved (unwrap-panic donor-data)) u1)
          (get total-milestones-achieved (unwrap-panic donor-data))
        )
      }))
      (if (> new-tier current-tier)
        (begin
          (var-set milestone-achievement-counter (+ (var-get milestone-achievement-counter) u1))
          (map-set milestone-achievements (var-get milestone-achievement-counter) {
            donor: tx-sender,
            tier-achieved: new-tier,
            achieved-at: burn-block-height,
            block-height: stacks-block-height,
            donation-amount-at-achievement: updated-amount
          })
        )
        true
      )
    )
    (map-set donation-history donation-id {
      donor: tx-sender,
      amount: amount,
      timestamp: burn-block-height,
      block-height: stacks-block-height
    })
    (var-set donation-counter donation-id)
    (var-set total-treasury (+ (var-get total-treasury) amount))
    (ok amount)
  )
)

(define-public (create-proposal (title (string-ascii 100)) (description (string-ascii 500)) (amount uint) (recipient principal))
  (let (
    (proposal-id (+ (var-get proposal-counter) u1))
    (donor-data (map-get? donors tx-sender))
  )
    (asserts! (not (var-get emergency-mode)) ERR-EMERGENCY-ACTIVE)
    (asserts! (is-some donor-data) ERR-DONOR-NOT-FOUND)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (<= amount (var-get total-treasury)) ERR-INSUFFICIENT-FUNDS)
    (asserts! (> (len title) u0) ERR-INVALID-PROPOSAL)
    (asserts! (> (len description) u0) ERR-INVALID-PROPOSAL)
    (asserts! (is-standard recipient) ERR-INVALID-PROPOSAL)
    (map-set proposals proposal-id {
      title: title,
      description: description,
      amount: amount,
      recipient: recipient,
      created-by: tx-sender,
      created-at: stacks-block-height,
      expires-at: (+ stacks-block-height u1440),
      yes-votes: u0,
      no-votes: u0,
      total-voting-power: (get-total-voting-power),
      is-executed: false,
      is-active: true
    })
    (var-set proposal-counter proposal-id)
    (ok proposal-id)
  )
)


(define-public (vote-on-proposal (proposal-id uint) (vote bool))
  (let (
    (proposal (unwrap! (map-get? proposals proposal-id) ERR-PROPOSAL-NOT-FOUND))
    (donor-data (unwrap! (map-get? donors tx-sender) ERR-DONOR-NOT-FOUND))
    (base-voting-power (get donation-amount donor-data))
    (milestone-tier (get current-milestone-tier donor-data))
    (voting-multiplier (get-voting-multiplier milestone-tier))
    (voting-power (/ (* base-voting-power voting-multiplier) u100))
    (vote-key {proposal-id: proposal-id, voter: tx-sender})
  )
    (asserts! (not (var-get emergency-mode)) ERR-EMERGENCY-ACTIVE)
    (asserts! (get is-active proposal) ERR-INVALID-PROPOSAL)
    (asserts! (< stacks-block-height (get expires-at proposal)) ERR-PROPOSAL-EXPIRED)
    (asserts! (is-none (map-get? proposal-votes vote-key)) ERR-ALREADY-VOTED)
    (asserts! (> voting-power u0) ERR-NOT-AUTHORIZED)
    (map-set proposal-votes vote-key {
      vote: vote,
      voting-power: voting-power,
      voted-at: stacks-block-height
    })
    (if vote
      (map-set proposals proposal-id (merge proposal {
        yes-votes: (+ (get yes-votes proposal) voting-power)
      }))
      (map-set proposals proposal-id (merge proposal {
        no-votes: (+ (get no-votes proposal) voting-power)
      }))
    )
    (ok true)
  )
)

(define-public (execute-proposal (proposal-id uint))
  (let (
    (proposal (unwrap! (map-get? proposals proposal-id) ERR-PROPOSAL-NOT-FOUND))
    (approval-threshold (/ (* (get total-voting-power proposal) (var-get min-approval-percentage)) u100))
    (amount (get amount proposal))
  )
    (asserts! (not (var-get emergency-mode)) ERR-EMERGENCY-ACTIVE)
    (asserts! (get is-active proposal) ERR-INVALID-PROPOSAL)
    (asserts! (not (get is-executed proposal)) ERR-INVALID-PROPOSAL)
    (asserts! (>= (get yes-votes proposal) approval-threshold) ERR-PROPOSAL-NOT-APPROVED)
    (asserts! (<= amount (stx-get-balance (as-contract tx-sender))) ERR-INSUFFICIENT-FUNDS)
    (try! (check-spending-limits amount))
    (try! (as-contract (stx-transfer? amount tx-sender (get recipient proposal))))
    (update-spending-tracking amount)
    (map-set proposals proposal-id (merge proposal {
      is-executed: true,
      is-active: false
    }))
    (var-set total-treasury (- (var-get total-treasury) amount))
    (ok true)
  )
)

(define-public (set-min-approval-percentage (percentage uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (asserts! (and (> percentage u0) (<= percentage u100)) ERR-INVALID-AMOUNT)
    (var-set min-approval-percentage percentage)
    (ok true)
  )
)

(define-public (deactivate-donor (donor principal))
  (let (
    (donor-data (unwrap! (map-get? donors donor) ERR-DONOR-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (asserts! (get is-active donor-data) ERR-INVALID-STATE)
    (map-set donors donor {
      donation-amount: (get donation-amount donor-data),
      is-active: false,
      joined-at: (get joined-at donor-data),
      current-milestone-tier: (get current-milestone-tier donor-data),
      total-milestones-achieved: (get total-milestones-achieved donor-data)
    })
    (ok true)
  )
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id)
)

(define-read-only (get-donor-info (donor principal))
  (map-get? donors donor)
)

(define-read-only (get-vote (proposal-id uint) (voter principal))
  (map-get? proposal-votes {proposal-id: proposal-id, voter: voter})
)

(define-read-only (get-treasury-balance)
  (stx-get-balance (as-contract tx-sender))
)

(define-read-only (get-total-treasury)
  (var-get total-treasury)
)

(define-read-only (get-proposal-counter)
  (var-get proposal-counter)
)

(define-read-only (get-min-approval-percentage)
  (var-get min-approval-percentage)
)

(define-read-only (get-contract-owner)
  (var-get contract-owner)
)

(define-read-only (get-donor-count)
  (var-get donor-count)
)

(define-read-only (get-donation-history (donation-id uint))
  (map-get? donation-history donation-id)
)

(define-read-only (get-donation-counter)
  (var-get donation-counter)
)

(define-read-only (get-emergency-mode)
  (var-get emergency-mode)
)

(define-read-only (get-emergency-withdrawal-count)
  (var-get emergency-withdrawal-count)
)

(define-read-only (get-emergency-withdrawal (withdrawal-id uint))
  (map-get? emergency-withdrawals withdrawal-id)
)

(define-read-only (get-milestone-achievement-counter)
  (var-get milestone-achievement-counter)
)

(define-read-only (get-milestone-tier (tier-id uint))
  (map-get? milestone-tiers tier-id)
)

(define-read-only (get-milestone-achievement (achievement-id uint))
  (map-get? milestone-achievements achievement-id)
)

(define-read-only (get-donor-donations (donor principal))
  (fold filter-donor-donations (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20) (list))
)

(define-private (filter-donor-donations (donation-id uint) (result (list 20 uint)))
  (if (<= donation-id (var-get donation-counter))
    (match (map-get? donation-history donation-id)
      donation-record (if (is-eq (get donor donation-record) tx-sender)
        (unwrap-panic (as-max-len? (append result donation-id) u20))
        result
      )
      result
    )
    result
  )
)

(define-read-only (is-proposal-approved (proposal-id uint))
  (match (map-get? proposals proposal-id)
    proposal (let (
      (approval-threshold (/ (* (get total-voting-power proposal) (var-get min-approval-percentage)) u100))
    )
      (>= (get yes-votes proposal) approval-threshold)
    )
    false
  )
)

(define-private (get-total-voting-power)
  (fold calculate-voting-power (list u0 u1 u2 u3 u4 u5 u6 u7 u8 u9) u0)
)

(define-private (calculate-voting-power (index uint) (total uint))
  (if (< index (var-get donor-count))
    (match (map-get? donor-list index)
      donor (match (map-get? donors donor)
        donor-data (if (get is-active donor-data)
          (let (
            (base-amount (get donation-amount donor-data))
            (milestone-tier (get current-milestone-tier donor-data))
            (voting-multiplier (get-voting-multiplier milestone-tier))
          )
            (+ total (/ (* base-amount voting-multiplier) u100))
          )
          total
        )
        total
      )
      total
    )
    total
  )
)

(define-read-only (get-proposal-status (proposal-id uint))
  (match (map-get? proposals proposal-id)
    proposal (let (
      (approval-threshold (/ (* (get total-voting-power proposal) (var-get min-approval-percentage)) u100))
      (is-approved (>= (get yes-votes proposal) approval-threshold))
      (is-expired (>= stacks-block-height (get expires-at proposal)))
    )
      (ok {
        is-approved: is-approved,
        is-expired: is-expired,
        is-executed: (get is-executed proposal),
        yes-votes: (get yes-votes proposal),
        no-votes: (get no-votes proposal),
        approval-threshold: approval-threshold
      })
    )
    ERR-PROPOSAL-NOT-FOUND
  )
)

(define-public (toggle-emergency-mode (enable bool))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (var-set emergency-mode enable)
    (ok enable)
  )
)

(define-public (emergency-withdraw (amount uint) (reason (string-ascii 200)))
  (let (
    (withdrawal-id (+ (var-get emergency-withdrawal-count) u1))
    (contract-balance (stx-get-balance (as-contract tx-sender)))
  )
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (asserts! (var-get emergency-mode) ERR-INVALID-STATE)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (<= amount contract-balance) ERR-INSUFFICIENT-FUNDS)
    (asserts! (> (len reason) u0) ERR-INVALID-PROPOSAL)
    (try! (as-contract (stx-transfer? amount tx-sender (var-get contract-owner))))
    (map-set emergency-withdrawals withdrawal-id {
      amount: amount,
      withdrawn-at: burn-block-height,
      block-height: stacks-block-height,
      reason: reason
    })
    (var-set emergency-withdrawal-count withdrawal-id)
    (var-set total-treasury (- (var-get total-treasury) amount))
    (var-set emergency-mode false)
    (ok withdrawal-id)
  )
)

(define-public (initialize-milestone-tiers)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (map-set milestone-tiers u1 {
      threshold: u1000000,
      voting-multiplier: u110,
      tier-name: "Bronze Supporter"
    })
    (map-set milestone-tiers u2 {
      threshold: u5000000,
      voting-multiplier: u125,
      tier-name: "Silver Guardian"
    })
    (map-set milestone-tiers u3 {
      threshold: u10000000,
      voting-multiplier: u150,
      tier-name: "Gold Champion"
    })
    (map-set milestone-tiers u4 {
      threshold: u25000000,
      voting-multiplier: u200,
      tier-name: "Platinum Benefactor"
    })
    (ok true)
  )
)

(define-private (get-milestone-tier-for-amount (amount uint))
  (if (>= amount u25000000) u4
    (if (>= amount u10000000) u3
      (if (>= amount u5000000) u2
        (if (>= amount u1000000) u1 u0)
      )
    )
  )
)

(define-private (get-voting-multiplier (tier uint))
  (match (map-get? milestone-tiers tier)
    tier-data (get voting-multiplier tier-data)
    u100
  )
)

(define-public (set-spending-limits (daily-percent uint) (weekly-percent uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (asserts! (and (> daily-percent u0) (<= daily-percent u100)) ERR-INVALID-AMOUNT)
    (asserts! (and (> weekly-percent u0) (<= weekly-percent u100)) ERR-INVALID-AMOUNT)
    (asserts! (<= daily-percent weekly-percent) ERR-INVALID-AMOUNT)
    (var-set daily-spending-limit-percent daily-percent)
    (var-set weekly-spending-limit-percent weekly-percent)
    (ok true)
  )
)

(define-private (check-spending-limits (amount uint))
  (let (
    (current-block stacks-block-height)
    (day-blocks u144)
    (week-blocks u1008)
    (treasury-balance (var-get total-treasury))
    (daily-limit (/ (* treasury-balance (var-get daily-spending-limit-percent)) u100))
    (weekly-limit (/ (* treasury-balance (var-get weekly-spending-limit-percent)) u100))
  )
    (begin
      (update-spending-periods current-block day-blocks week-blocks)
      (asserts! (<= (+ (var-get daily-spent) amount) daily-limit) ERR-SPENDING-LIMIT-EXCEEDED)
      (asserts! (<= (+ (var-get weekly-spent) amount) weekly-limit) ERR-SPENDING-LIMIT-EXCEEDED)
      (ok true)
    )
  )
)

(define-private (update-spending-periods (current-block uint) (day-blocks uint) (week-blocks uint))
  (let (
    (day-start-block (var-get current-day-start))
    (week-start-block (var-get current-week-start))
  )
    (begin
      (if (or (is-eq day-start-block u0) (>= current-block (+ day-start-block day-blocks)))
        (begin
          (var-set current-day-start current-block)
          (var-set daily-spent u0)
        )
        true
      )
      (if (or (is-eq week-start-block u0) (>= current-block (+ week-start-block week-blocks)))
        (begin
          (var-set current-week-start current-block)
          (var-set weekly-spent u0)
        )
        true
      )
    )
  )
)

(define-private (update-spending-tracking (amount uint))
  (begin
    (var-set daily-spent (+ (var-get daily-spent) amount))
    (var-set weekly-spent (+ (var-get weekly-spent) amount))
  )
)

(define-read-only (get-spending-limits)
  {
    daily-limit-percent: (var-get daily-spending-limit-percent),
    weekly-limit-percent: (var-get weekly-spending-limit-percent),
    daily-limit-amount: (/ (* (var-get total-treasury) (var-get daily-spending-limit-percent)) u100),
    weekly-limit-amount: (/ (* (var-get total-treasury) (var-get weekly-spending-limit-percent)) u100)
  }
)

(define-read-only (get-current-spending)
  {
    daily-spent: (var-get daily-spent),
    weekly-spent: (var-get weekly-spent),
    daily-remaining: (- (/ (* (var-get total-treasury) (var-get daily-spending-limit-percent)) u100) (var-get daily-spent)),
    weekly-remaining: (- (/ (* (var-get total-treasury) (var-get weekly-spending-limit-percent)) u100) (var-get weekly-spent))
  }
)

(define-read-only (get-spending-periods)
  {
    current-day-start: (var-get current-day-start),
    current-week-start: (var-get current-week-start),
    day-blocks-remaining: (- (+ (var-get current-day-start) u144) stacks-block-height),
    week-blocks-remaining: (- (+ (var-get current-week-start) u1008) stacks-block-height)
  }
)
