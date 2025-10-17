;; Standard error helpers I reuse around the goal logic
(define-constant err-owner-only (err u200))
(define-constant err-not-found (err u201))
(define-constant err-unauthorized (err u202))
(define-constant err-invalid-amount (err u203))
(define-constant err-goal-completed (err u204))
(define-constant err-goal-not-completed (err u205))
(define-constant err-already-claimed-nft (err u206))
(define-constant err-invalid-duration (err u207))
(define-constant err-empty-purpose (err u208))

;; 10% penalty on early withdrawals
(define-constant emergency-withdrawal-penalty u10)

;; Track who deployed this contract and the running goal id counter
(define-data-var contract-owner principal tx-sender)
(define-data-var goal-nonce uint u0)

;; Primary store for each savings goal
(define-map savings-goals
  uint
  {
    owner: principal,
    target-amount: uint,
    current-amount: uint,
    purpose: (string-utf8 256),
    start-block: uint,
    duration-blocks: uint,
    completed: bool,
    nft-claimed: bool,
    active: bool
  }
)

;; Quick lookup of goal ids owned by a principal
(define-map user-goals principal (list 100 uint))

;; Simple owner check used by admin-only calls
(define-private (assert-owner (caller principal))
  (ok (asserts! (is-eq caller (var-get contract-owner)) err-owner-only))
)

;; Convenience wrapper that returns this contract principal
(define-private (contract-principal)
  (as-contract tx-sender)
)

;; Read: get a goal by id
(define-read-only (get-goal (goal-id uint))
  (ok (map-get? savings-goals goal-id))
)

;; Read: list all goal ids for a user
(define-read-only (get-user-goals (user principal))
  (ok (default-to (list) (map-get? user-goals user)))
)

;; Read: surface key progress metrics for a goal
(define-read-only (get-goal-progress (goal-id uint))
  (match (map-get? savings-goals goal-id)
    goal (ok {
      target: (get target-amount goal),
      current: (get current-amount goal),
      percentage: (/ (* (get current-amount goal) u100) (get target-amount goal)),
      completed: (get completed goal)
    })
    err-not-found
  )
)

;; Read: check whether a goal has expired based on duration
(define-read-only (is-goal-expired (goal-id uint))
  (match (map-get? savings-goals goal-id)
    goal (ok (>= block-height (+ (get start-block goal) (get duration-blocks goal))))
    err-not-found
  )
)

;; Read: calculate how much a saver would get back in an emergency
(define-read-only (calculate-emergency-withdrawal (goal-id uint))
  (match (map-get? savings-goals goal-id)
    goal 
      (let (
        (current (get current-amount goal))
        (penalty-amount (/ (* current emergency-withdrawal-penalty) u100))
        (withdrawal-amount (- current penalty-amount))
      )
        (ok {
          total: current,
          penalty: penalty-amount,
          withdrawal: withdrawal-amount
        })
      )
    err-not-found
  )
)

;; Read: expose the next goal id so the UI can display it
(define-read-only (get-next-goal-id)
  (ok (var-get goal-nonce))
)

;; Public: create a fresh savings goal
;; target-amount -> how much to save, duration-blocks -> max lifetime, purpose -> goal story
(define-public (create-goal (target-amount uint) (duration-blocks uint) (purpose (string-utf8 256)))
  (let (
    (goal-id (var-get goal-nonce))
    (creator tx-sender)
  )
    (asserts! (> target-amount u0) err-invalid-amount)
    (asserts! (> duration-blocks u0) err-invalid-duration)
    (asserts! (> (len purpose) u0) err-empty-purpose)
    (map-set savings-goals goal-id {
      owner: creator,
      target-amount: target-amount,
      current-amount: u0,
      purpose: purpose,
      start-block: block-height,
      duration-blocks: duration-blocks,
      completed: false,
      nft-claimed: false,
      active: true
    })
    (map-set user-goals creator 
      (unwrap! (as-max-len? (append (default-to (list) (map-get? user-goals creator)) goal-id) u100) err-invalid-amount)
    )
    (var-set goal-nonce (+ goal-id u1))
    (print {
      event: "goal-created",
      goal-id: goal-id,
      owner: creator,
      target-amount: target-amount,
      duration-blocks: duration-blocks,
      purpose: purpose
    })
    (ok goal-id)
  )
)

;; Public: deposit mock STX into a goal
;; goal-id -> which goal, amount -> how much to add
(define-public (deposit (goal-id uint) (amount uint))
  (let (
    (goal (unwrap! (map-get? savings-goals goal-id) err-not-found))
    (depositor tx-sender)
    (vault (contract-principal))
  )
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (get active goal) err-goal-completed)
    (asserts! (not (get completed goal)) err-goal-completed)
  (try! (contract-call? .mock-stx-token transfer amount depositor vault none))
    (let (
      (new-amount (+ (get current-amount goal) amount))
      (is-completed (>= new-amount (get target-amount goal)))
    )
      (map-set savings-goals goal-id (merge goal {
        current-amount: new-amount,
        completed: is-completed
      }))
      (print {
        event: "deposit-made",
        goal-id: goal-id,
        depositor: depositor,
        amount: amount,
        new-total: new-amount,
        completed: is-completed
      })
      (ok {
        new-total: new-amount,
        completed: is-completed
      })
    )
  )
)

;; Public: withdraw funds once the goal target is met
;; goal-id -> the completed goal we are cashing out
(define-public (withdraw-completed (goal-id uint))
  (let (
    (goal (unwrap! (map-get? savings-goals goal-id) err-not-found))
    (withdrawer tx-sender)
    (vault (contract-principal))
  )
    (asserts! (is-eq (get owner goal) withdrawer) err-unauthorized)
    (asserts! (get completed goal) err-goal-not-completed)
    (asserts! (get active goal) err-goal-completed)
  (try! (as-contract (contract-call? .mock-stx-token transfer (get current-amount goal) vault withdrawer none)))
    (map-set savings-goals goal-id (merge goal {
      active: false,
      current-amount: u0
    }))
    (print {
      event: "goal-withdrawn",
      goal-id: goal-id,
      owner: withdrawer,
      amount: (get current-amount goal)
    })
    (ok (get current-amount goal))
  )
)

;; Public: let the saver break their goal early with a penalty
;; goal-id -> target goal to close early
(define-public (emergency-withdraw (goal-id uint))
  (let (
    (goal (unwrap! (map-get? savings-goals goal-id) err-not-found))
    (withdrawer tx-sender)
    (current-amount (get current-amount goal))
    (penalty-amount (/ (* current-amount emergency-withdrawal-penalty) u100))
    (withdrawal-amount (- current-amount penalty-amount))
    (vault (contract-principal))
  )
    (asserts! (is-eq (get owner goal) withdrawer) err-unauthorized)
    (asserts! (get active goal) err-goal-completed)
    (asserts! (> current-amount u0) err-invalid-amount)
  (try! (as-contract (contract-call? .mock-stx-token transfer withdrawal-amount vault withdrawer none)))
    (map-set savings-goals goal-id (merge goal {
      active: false,
      current-amount: penalty-amount
    }))
    (print {
      event: "emergency-withdrawal",
      goal-id: goal-id,
      owner: withdrawer,
      original-amount: current-amount,
      penalty: penalty-amount,
      withdrawn: withdrawal-amount
    })
    (ok {
      withdrawn: withdrawal-amount,
      penalty: penalty-amount
    })
  )
)

;; Public: mint the achievement NFT linked to the goal
;; goal-id -> goal that just completed
(define-public (claim-achievement-nft (goal-id uint))
  (let (
    (goal (unwrap! (map-get? savings-goals goal-id) err-not-found))
    (claimer tx-sender)
  )
    (asserts! (is-eq (get owner goal) claimer) err-unauthorized)
    (asserts! (get completed goal) err-goal-not-completed)
    (asserts! (not (get nft-claimed goal)) err-already-claimed-nft)
    (try! (contract-call? .achievement-nft mint-achievement goal-id claimer (get target-amount goal) (get purpose goal)))
    (map-set savings-goals goal-id (merge goal {
      nft-claimed: true
    }))
    (print {
      event: "nft-claimed",
      goal-id: goal-id,
      owner: claimer
    })
    (ok true)
  )
)

;; Public: admin withdrawal of accumulated emergency penalties
;; amount -> how much to pull, recipient -> where funds should land
(define-public (withdraw-penalties (amount uint) (recipient principal))
  (let ((vault (contract-principal)))
    (try! (assert-owner tx-sender))
    (asserts! (> amount u0) err-invalid-amount)
  (try! (as-contract (contract-call? .mock-stx-token transfer amount vault recipient none)))
    (ok amount)
  )
)
