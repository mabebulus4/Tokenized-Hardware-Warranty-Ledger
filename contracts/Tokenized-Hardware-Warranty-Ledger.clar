(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-expired (err u103))
(define-constant err-invalid-warranty (err u104))
(define-constant err-already-exists (err u105))

(define-non-fungible-token warranty-token uint)

(define-data-var warranty-counter uint u0)

(define-map warranties
  { warranty-id: uint }
  {
    manufacturer: principal,
    product-serial: (string-ascii 50),
    product-model: (string-ascii 50),
    purchase-date: uint,
    warranty-duration: uint,
    owner: principal,
    is-active: bool,
    transfer-count: uint
  }
)

(define-map warranty-history
  { warranty-id: uint, transfer-id: uint }
  {
    from-owner: principal,
    to-owner: principal,
    transfer-date: uint,
    reason: (string-ascii 100)
  }
)

(define-read-only (get-warranty (warranty-id uint))
  (map-get? warranties { warranty-id: warranty-id })
)

(define-read-only (get-warranty-owner (warranty-id uint))
  (nft-get-owner? warranty-token warranty-id)
)

(define-read-only (is-warranty-expired (warranty-id uint))
  (match (map-get? warranties { warranty-id: warranty-id })
    warranty-data
    (let ((expiry-block (+ (get purchase-date warranty-data) (get warranty-duration warranty-data))))
      (ok (>= stacks-block-height expiry-block)))
    (err err-not-found)
  )
)

(define-read-only (get-warranty-expiry-block (warranty-id uint))
  (match (map-get? warranties { warranty-id: warranty-id })
    warranty-data
    (ok (+ (get purchase-date warranty-data) (get warranty-duration warranty-data)))
    (err err-not-found)
  )
)

(define-read-only (get-warranty-history (warranty-id uint) (transfer-id uint))
  (map-get? warranty-history { warranty-id: warranty-id, transfer-id: transfer-id })
)

(define-read-only (get-total-warranties)
  (var-get warranty-counter)
)

(define-public (issue-warranty 
  (product-serial (string-ascii 50))
  (product-model (string-ascii 50))
  (warranty-duration uint)
  (customer principal))
  (let ((warranty-id (+ (var-get warranty-counter) u1)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> warranty-duration u0) err-invalid-warranty)
    (try! (nft-mint? warranty-token warranty-id customer))
    (map-set warranties
      { warranty-id: warranty-id }
      {
        manufacturer: tx-sender,
        product-serial: product-serial,
        product-model: product-model,
        purchase-date: stacks-block-height,
        warranty-duration: warranty-duration,
        owner: customer,
        is-active: true,
        transfer-count: u0
      }
    )
    (var-set warranty-counter warranty-id)
    (ok warranty-id)
  )
)

(define-public (transfer-warranty (warranty-id uint) (new-owner principal))
  (let ((current-owner (unwrap! (get-warranty-owner warranty-id) err-not-found))
        (warranty-data (unwrap! (get-warranty warranty-id) err-not-found)))
    (asserts! (is-eq tx-sender current-owner) err-unauthorized)
    (asserts! (get is-active warranty-data) err-invalid-warranty)
    (asserts! (not (unwrap! (is-warranty-expired warranty-id) err-not-found)) err-expired)
    (try! (nft-transfer? warranty-token warranty-id current-owner new-owner))
    (let ((transfer-count (+ (get transfer-count warranty-data) u1)))
      (map-set warranties
        { warranty-id: warranty-id }
        (merge warranty-data { owner: new-owner, transfer-count: transfer-count })
      )
      (map-set warranty-history
        { warranty-id: warranty-id, transfer-id: transfer-count }
        {
          from-owner: current-owner,
          to-owner: new-owner,
          transfer-date: stacks-block-height,
          reason: "manual-transfer"
        }
      )
      (ok true)
    )
  )
)

(define-public (claim-warranty (warranty-id uint) (claim-reason (string-ascii 100)))
  (let ((warranty-data (unwrap! (get-warranty warranty-id) err-not-found))
        (current-owner (unwrap! (get-warranty-owner warranty-id) err-not-found)))
    (asserts! (is-eq tx-sender current-owner) err-unauthorized)
    (asserts! (get is-active warranty-data) err-invalid-warranty)
    (asserts! (not (unwrap! (is-warranty-expired warranty-id) err-not-found)) err-expired)
    (map-set warranties
      { warranty-id: warranty-id }
      (merge warranty-data { is-active: false })
    )
    (ok true)
  )
)

(define-public (extend-warranty (warranty-id uint) (additional-duration uint))
  (let ((warranty-data (unwrap! (get-warranty warranty-id) err-not-found)))
    (asserts! (is-eq tx-sender (get manufacturer warranty-data)) err-unauthorized)
    (asserts! (get is-active warranty-data) err-invalid-warranty)
    (asserts! (> additional-duration u0) err-invalid-warranty)
    (map-set warranties
      { warranty-id: warranty-id }
      (merge warranty-data { warranty-duration: (+ (get warranty-duration warranty-data) additional-duration) })
    )
    (ok true)
  )
)

(define-public (deactivate-warranty (warranty-id uint))
  (let ((warranty-data (unwrap! (get-warranty warranty-id) err-not-found)))
    (asserts! (is-eq tx-sender (get manufacturer warranty-data)) err-unauthorized)
    (map-set warranties
      { warranty-id: warranty-id }
      (merge warranty-data { is-active: false })
    )
    (ok true)
  )
)

(define-public (batch-issue-warranties 
  (warranty-requests (list 10 { 
    product-serial: (string-ascii 50), 
    product-model: (string-ascii 50), 
    warranty-duration: uint, 
    customer: principal 
  })))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map issue-single-warranty warranty-requests))
  )
)

(define-private (issue-single-warranty (request { 
  product-serial: (string-ascii 50), 
  product-model: (string-ascii 50), 
  warranty-duration: uint, 
  customer: principal 
}))
  (let ((warranty-id (+ (var-get warranty-counter) u1)))
    (unwrap-panic (nft-mint? warranty-token warranty-id (get customer request)))
    (map-set warranties
      { warranty-id: warranty-id }
      {
        manufacturer: tx-sender,
        product-serial: (get product-serial request),
        product-model: (get product-model request),
        purchase-date: stacks-block-height,
        warranty-duration: (get warranty-duration request),
        owner: (get customer request),
        is-active: true,
        transfer-count: u0
      }
    )
    (var-set warranty-counter warranty-id)
    warranty-id
  )
)
