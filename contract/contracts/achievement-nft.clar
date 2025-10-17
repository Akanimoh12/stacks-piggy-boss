(impl-trait .sip009-nft-trait.sip009-nft-trait)

(define-constant err-owner-only (err u300))
(define-constant err-not-found (err u301))
(define-constant err-unauthorized (err u302))
(define-constant err-already-minted (err u303))
(define-constant err-invalid-target (err u304))
(define-constant err-invalid-purpose (err u305))
(define-constant err-empty-base-uri (err u306))

(define-data-var contract-owner principal tx-sender)
(define-data-var token-name (string-ascii 32) "Savings Achievement")
(define-data-var token-symbol (string-ascii 10) "SAVES")
(define-data-var last-token-id uint u0)
(define-data-var base-uri (string-ascii 256) "ipfs://")

(define-constant savings-goals-contract .savings-goals)

(define-non-fungible-token savings-achievement uint)

(define-map token-metadata
  uint
  {
    goal-id: uint,
    target-amount: uint,
    purpose: (string-utf8 256),
    completion-block: uint,
    minted-at: uint
  }
)

(define-map goal-nft-map uint uint)

(define-private (assert-owner (caller principal))
  (ok (asserts! (is-eq caller (var-get contract-owner)) err-owner-only))
)

(define-private (is-authorized-minter (caller principal))
  (is-eq caller savings-goals-contract)
)

(define-read-only (get-last-token-id)
  (ok (var-get last-token-id))
)

(define-read-only (get-token-uri (token-id uint))
  (match (nft-get-owner? savings-achievement token-id)
    some-owner (ok (some (var-get base-uri)))
    err-not-found
  )
)

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? savings-achievement token-id))
)

(define-read-only (get-token-metadata (token-id uint))
  (ok (map-get? token-metadata token-id))
)

(define-read-only (get-nft-by-goal (goal-id uint))
  (ok (map-get? goal-nft-map goal-id))
)

(define-read-only (get-name)
  (ok (var-get token-name))
)

(define-read-only (get-symbol)
  (ok (var-get token-symbol))
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (let ((owner (unwrap! (nft-get-owner? savings-achievement token-id) err-not-found)))
    (asserts! (is-eq tx-sender sender) err-unauthorized)
    (asserts! (is-eq owner sender) err-unauthorized)
    (asserts! (is-eq sender recipient) err-unauthorized)
    (ok true)
  )
)

(define-public (mint-achievement (goal-id uint) (recipient principal) (target-amount uint) (purpose (string-utf8 256)))
  (let ((caller contract-caller))
    (asserts! (is-authorized-minter caller) err-unauthorized)
    (asserts! (> target-amount u0) err-invalid-target)
    (asserts! (> (len purpose) u0) err-invalid-purpose)
    (asserts! (is-eq recipient tx-sender) err-unauthorized)
    (asserts! (is-none (map-get? goal-nft-map goal-id)) err-already-minted)
    (let ((token-id (+ (var-get last-token-id) u1)))
      (try! (nft-mint? savings-achievement token-id recipient))
      (map-set token-metadata token-id {
        goal-id: goal-id,
        target-amount: target-amount,
        purpose: purpose,
        completion-block: block-height,
        minted-at: block-height
      })
      (map-set goal-nft-map goal-id token-id)
      (var-set last-token-id token-id)
      (print {
        event: "achievement-minted",
        token-id: token-id,
        goal-id: goal-id,
        recipient: recipient,
        target-amount: target-amount
      })
      (ok token-id)
    )
  )
)

(define-public (set-base-uri (new-base-uri (string-ascii 256)))
  (begin
    (try! (assert-owner tx-sender))
    (asserts! (> (len new-base-uri) u0) err-empty-base-uri)
    (var-set base-uri new-base-uri)
    (ok true)
  )
)
