(impl-trait .sip010-ft-trait.sip010-ft-trait)

(define-fungible-token mock-stx)

(define-constant err-owner-only (err u100))
(define-constant err-already-claimed (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-invalid-recipient (err u104))
(define-constant err-invalid-uri (err u105))
(define-constant savings-goals-contract .savings-goals)
(define-constant claim-amount u1000000)
(define-constant claim-cooldown u144)

(define-data-var contract-owner principal tx-sender)
(define-data-var token-name (string-ascii 32) "MockSTX")
(define-data-var token-symbol (string-ascii 10) "mSTX")
(define-data-var token-uri (optional (string-utf8 256)) none)

(define-map last-claim-block principal uint)

(define-read-only (get-name)
  (ok (var-get token-name))
)

(define-read-only (get-symbol)
  (ok (var-get token-symbol))
)

(define-read-only (get-decimals)
  (ok u6)
)

(define-read-only (get-balance (account principal))
  (ok (ft-get-balance mock-stx account))
)

(define-read-only (get-total-supply)
  (ok (ft-get-supply mock-stx))
)

(define-read-only (get-token-uri)
  (ok (var-get token-uri))
)

(define-read-only (can-claim (account principal))
  (let ((last-claim (default-to u0 (map-get? last-claim-block account))))
    (ok (>= (- block-height last-claim) claim-cooldown))
  )
)

(define-read-only (get-last-claim-block (account principal))
  (ok (default-to u0 (map-get? last-claim-block account)))
)

(define-read-only (blocks-until-next-claim (account principal))
  (let (
    (last-claim (default-to u0 (map-get? last-claim-block account)))
    (blocks-passed (- block-height last-claim))
  )
    (if (>= blocks-passed claim-cooldown)
      (ok u0)
      (ok (- claim-cooldown blocks-passed))
    )
  )
)

(define-private (assert-owner (caller principal))
  (ok (asserts! (is-eq caller (var-get contract-owner)) err-owner-only))
)

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (is-eq tx-sender sender) err-owner-only)
    (let (
      (allowed-recipient (if (is-eq recipient sender)
        sender
        (begin
          (asserts! (is-eq recipient savings-goals-contract) err-invalid-recipient)
          savings-goals-contract
        ))
      )
    )
      (try! (ft-transfer? mock-stx amount sender allowed-recipient))
      (match memo to-print (print to-print) 0x)
      (ok true)
    )
  )
)

(define-public (claim-tokens)
  (let (
    (claimer tx-sender)
    (last-claim (default-to u0 (map-get? last-claim-block claimer)))
  )
    (asserts! (>= (- block-height last-claim) claim-cooldown) err-already-claimed)
    (try! (ft-mint? mock-stx claim-amount claimer))
    (map-set last-claim-block claimer block-height)
    (print {
      event: "tokens-claimed",
      claimer: claimer,
      amount: claim-amount,
      block-height: block-height
    })
    (ok claim-amount)
  )
)

(define-public (set-token-uri (new-uri (optional (string-utf8 256))))
  (begin
    (try! (assert-owner tx-sender))
    (match new-uri uri
      (begin
        (asserts! (> (len uri) u0) err-invalid-uri)
        (var-set token-uri (some uri))
      )
      (var-set token-uri none)
    )
    (ok true)
  )
)

(define-public (mint (amount uint) (recipient principal))
  (begin
    (try! (assert-owner tx-sender))
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (is-eq recipient tx-sender) err-invalid-recipient)
    (try! (ft-mint? mock-stx amount tx-sender))
    (ok amount)
  )
)

(begin
  (unwrap-panic (ft-mint? mock-stx u10000000 tx-sender))
  true
)
