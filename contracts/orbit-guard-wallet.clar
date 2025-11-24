;; -----------------------------------------------------------
;; Contract: orbit-guard-wallet.clar
;; Purpose:  Multi-signature rotating custody wallet
;; Author:   aish
;; -----------------------------------------------------------

(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-NO-CUSTODIANS (err u101))
(define-constant ERR-INVALID-AMOUNT (err u102))
(define-constant ERR-RECIPIENT-INVALID (err u103))
(define-constant ERR-ONLY-ADMIN (err u104))

(define-data-var admin principal tx-sender)
(define-data-var rotation-period uint u1440) ;; e.g., 10 hours (25s block time)
(define-data-var custodian-count uint u0)
(define-data-var next-id uint u1)

;; -----------------------------------------------------------
;; MAP: Store custodians by index
;; -----------------------------------------------------------

(define-map custodians
  { id: uint }
  { address: principal, active: bool }
)

;; -----------------------------------------------------------
;; EVENTS (Emitted via print statements)
;; -----------------------------------------------------------

;; -----------------------------------------------------------
;; ADMIN FUNCTIONS
;; -----------------------------------------------------------

;; Add a new custodian
(define-public (add-custodian (addr principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-ONLY-ADMIN)
    (asserts! (not (is-eq addr tx-sender)) ERR-RECIPIENT-INVALID)
    (let ((id (var-get next-id)))
      (begin
        (map-set custodians { id: id } { address: addr, active: true })
        (var-set next-id (+ id u1))
        (var-set custodian-count (+ (var-get custodian-count) u1))
        (print { event: "custodian-added", id: id, address: addr })
        (ok true)
      )
    )
  )
)

;; Remove a custodian by marking as inactive
(define-public (remove-custodian (id uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-ONLY-ADMIN)
    (asserts! (> id u0) ERR-INVALID-AMOUNT)
    (match (map-get? custodians { id: id })
      custodian
        (begin
          (let ((addr (get address custodian)))
            (begin
              (map-set custodians { id: id } { address: addr, active: false })
              (var-set custodian-count (- (var-get custodian-count) u1))
              (print { event: "custodian-removed", id: id })
              (ok true)
            )
          )
        )
      ERR-NO-CUSTODIANS
    )
  )
)

;; Update rotation period
(define-public (set-rotation-period (new-period uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-ONLY-ADMIN)
    (asserts! (> new-period u0) ERR-INVALID-AMOUNT)
    (var-set rotation-period new-period)
    (ok true)
  )
)

;; -----------------------------------------------------------
;; ROTATION LOGIC
;; -----------------------------------------------------------

(define-read-only (get-active-custodian)
  (let (
        (count (var-get custodian-count))
        (period (var-get rotation-period))
       )
    (if (<= count u0)
        ERR-NO-CUSTODIANS
        (let ((index (mod (/ (var-get rotation-period) period) count)))
          (match (map-get? custodians { id: (+ index u1) }) data
            (ok (get address data))
            ERR-NO-CUSTODIANS
          )
        )
    )
  )
)

;; -----------------------------------------------------------
;; CORE FUNCTION
;; -----------------------------------------------------------

;; Only current custodian can transfer funds
(define-public (transfer-stx (recipient principal) (amount uint))
  (begin
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (not (is-eq recipient tx-sender)) ERR-RECIPIENT-INVALID)
    (let ((active (unwrap! (get-active-custodian) ERR-NO-CUSTODIANS)))
      (begin
        (asserts! (is-eq tx-sender active) ERR-NOT-AUTHORIZED)
        (try! (stx-transfer? amount (as-contract tx-sender) recipient))
        (print { event: "funds-transferred", to: recipient, amount: amount })
        (ok true)
      )
    )
  )
)

;; -----------------------------------------------------------
;; READ-ONLY FUNCTIONS
;; -----------------------------------------------------------

(define-read-only (get-custodians)
  (ok (var-get custodian-count))
)

(define-read-only (get-rotation-info)
  (match (get-active-custodian)
    custodian
      (ok {
        active-custodian: custodian,
        rotation-period: (var-get rotation-period),
        custodian-count: (var-get custodian-count)
      })
    error-val
      (err error-val)
  )
)
