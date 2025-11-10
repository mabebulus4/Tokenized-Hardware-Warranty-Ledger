(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-expired (err u103))
(define-constant err-invalid-warranty (err u104))
(define-constant err-already-exists (err u105))

(define-constant err-not-certified (err u106))
(define-constant err-job-not-available (err u107))
(define-constant err-invalid-bid (err u108))

(define-constant err-already-rated (err u109))
(define-constant err-cannot-rate (err u110))
(define-constant err-invalid-rating (err u111))

(define-constant err-insufficient-funds (err u112))
(define-constant err-escrow-not-found (err u113))
(define-constant err-job-not-completed (err u114))
(define-constant err-already-disputed (err u115))

(define-non-fungible-token warranty-token uint)

(define-data-var warranty-counter uint u0)

(define-data-var job-counter uint u0)

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

(define-map service-providers
  { provider: principal }
  {
    certification-level: uint,
    reputation-score: uint,
    total-jobs: uint,
    is-active: bool
  }
)

(define-map repair-jobs
  { job-id: uint }
  {
    warranty-id: uint,
    customer: principal,
    description: (string-ascii 200),
    max-budget: uint,
    status: (string-ascii 20),
    selected-provider: (optional principal),
    completion-block: (optional uint)
  }
)

(define-map service-bids
  { job-id: uint, provider: principal }
  {
    bid-amount: uint,
    estimated-duration: uint,
    bid-block: uint
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

(define-public (register-service-provider (certification-level uint))
  (begin
    (asserts! (not (is-some (map-get? service-providers { provider: tx-sender }))) err-already-exists)
    (asserts! (>= certification-level u1) err-invalid-warranty)
    (map-set service-providers
      { provider: tx-sender }
      {
        certification-level: certification-level,
        reputation-score: u100,
        total-jobs: u0,
        is-active: true
      }
    )
    (ok true)
  )
)

(define-public (post-repair-job (warranty-id uint) (description (string-ascii 200)) (max-budget uint))
  (let ((warranty-data (unwrap! (get-warranty warranty-id) err-not-found))
        (job-id (+ (var-get job-counter) u1)))
    (asserts! (is-eq tx-sender (get owner warranty-data)) err-unauthorized)
    (asserts! (get is-active warranty-data) err-invalid-warranty)
    (asserts! (> max-budget u0) err-invalid-warranty)
    (map-set repair-jobs
      { job-id: job-id }
      {
        warranty-id: warranty-id,
        customer: tx-sender,
        description: description,
        max-budget: max-budget,
        status: "open",
        selected-provider: none,
        completion-block: none
      }
    )
    (var-set job-counter job-id)
    (ok job-id)
  )
)

(define-public (submit-service-bid (job-id uint) (bid-amount uint) (estimated-duration uint))
  (let ((job-data (unwrap! (map-get? repair-jobs { job-id: job-id }) err-not-found))
        (provider-data (unwrap! (map-get? service-providers { provider: tx-sender }) err-not-certified)))
    (asserts! (get is-active provider-data) err-not-certified)
    (asserts! (is-eq (get status job-data) "open") err-job-not-available)
    (asserts! (<= bid-amount (get max-budget job-data)) err-invalid-bid)
    (asserts! (> estimated-duration u0) err-invalid-bid)
    (map-set service-bids
      { job-id: job-id, provider: tx-sender }
      {
        bid-amount: bid-amount,
        estimated-duration: estimated-duration,
        bid-block: stacks-block-height
      }
    )
    (ok true)
  )
)

(define-public (accept-service-bid (job-id uint) (provider principal))
  (let ((job-data (unwrap! (map-get? repair-jobs { job-id: job-id }) err-not-found))
        (bid-data (unwrap! (map-get? service-bids { job-id: job-id, provider: provider }) err-not-found)))
    (asserts! (is-eq tx-sender (get customer job-data)) err-unauthorized)
    (asserts! (is-eq (get status job-data) "open") err-job-not-available)
    (map-set repair-jobs
      { job-id: job-id }
      (merge job-data { status: "assigned", selected-provider: (some provider) })
    )
    (ok true)
  )
)


(define-map manufacturer-reputation
  { manufacturer: principal }
  {
    total-ratings: uint,
    rating-sum: uint,
    average-rating: uint
  }
)

(define-map warranty-ratings
  { warranty-id: uint }
  {
    rating: uint,
    comment: (string-ascii 150),
    rater: principal,
    rating-block: uint,
    has-been-rated: bool
  }
)

(define-read-only (get-manufacturer-reputation (manufacturer principal))
  (default-to 
    { total-ratings: u0, rating-sum: u0, average-rating: u0 }
    (map-get? manufacturer-reputation { manufacturer: manufacturer })
  )
)

(define-read-only (get-warranty-rating (warranty-id uint))
  (map-get? warranty-ratings { warranty-id: warranty-id })
)

(define-public (rate-warranty (warranty-id uint) (rating uint) (comment (string-ascii 150)))
  (let (
    (warranty-data (unwrap! (get-warranty warranty-id) err-not-found))
    (current-owner (unwrap! (get-warranty-owner warranty-id) err-not-found))
    (existing-rating (map-get? warranty-ratings { warranty-id: warranty-id }))
  )
    (asserts! (is-eq tx-sender current-owner) err-unauthorized)
    (asserts! (and (>= rating u1) (<= rating u5)) err-invalid-rating)
    (asserts! (or (not (get is-active warranty-data)) (unwrap! (is-warranty-expired warranty-id) err-not-found)) err-cannot-rate)
    (asserts! (is-none existing-rating) err-already-rated)
    
    (map-set warranty-ratings
      { warranty-id: warranty-id }
      {
        rating: rating,
        comment: comment,
        rater: tx-sender,
        rating-block: stacks-block-height,
        has-been-rated: true
      }
    )
    
    (let (
      (manufacturer (get manufacturer warranty-data))
      (current-rep (get-manufacturer-reputation manufacturer))
      (new-total (+ (get total-ratings current-rep) u1))
      (new-sum (+ (get rating-sum current-rep) rating))
      (new-average (/ new-sum new-total))
    )
      (map-set manufacturer-reputation
        { manufacturer: manufacturer }
        {
          total-ratings: new-total,
          rating-sum: new-sum,
          average-rating: new-average
        }
      )
      (ok new-average)
    )
  )
)

(define-map job-escrow
  { job-id: uint }
  {
    deposited-amount: uint,
    depositor: principal,
    is-deposited: bool,
    is-disputed: bool,
    dispute-reason: (string-ascii 150),
    arbiter-decision: (optional bool)
  }
)

(define-read-only (get-escrow-status (job-id uint))
  (map-get? job-escrow { job-id: job-id })
)

(define-public (deposit-to-escrow (job-id uint) (amount uint))
  (let ((job-data (unwrap! (map-get? repair-jobs { job-id: job-id }) err-not-found)))
    (asserts! (is-eq tx-sender (get customer job-data)) err-unauthorized)
    (asserts! (is-eq (get status job-data) "assigned") err-job-not-available)
    (asserts! (>= amount (get max-budget job-data)) err-insufficient-funds)
    (asserts! (is-none (map-get? job-escrow { job-id: job-id })) err-already-exists)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set job-escrow
      { job-id: job-id }
      {
        deposited-amount: amount,
        depositor: tx-sender,
        is-deposited: true,
        is-disputed: false,
        dispute-reason: "",
        arbiter-decision: none
      }
    )
    (map-set repair-jobs { job-id: job-id } (merge job-data { status: "in-progress" }))
    (ok true)
  )
)

(define-public (complete-job-and-release (job-id uint))
  (let (
    (job-data (unwrap! (map-get? repair-jobs { job-id: job-id }) err-not-found))
    (escrow-data (unwrap! (map-get? job-escrow { job-id: job-id }) err-escrow-not-found))
    (provider (unwrap! (get selected-provider job-data) err-not-found))
  )
    (asserts! (is-eq tx-sender (get customer job-data)) err-unauthorized)
    (asserts! (is-eq (get status job-data) "in-progress") err-job-not-available)
    (asserts! (not (get is-disputed escrow-data)) err-already-disputed)
    (try! (as-contract (stx-transfer? (get deposited-amount escrow-data) tx-sender provider)))
    (map-set repair-jobs { job-id: job-id } (merge job-data { status: "completed", completion-block: (some stacks-block-height) }))
    (ok true)
  )
)

(define-public (raise-dispute (job-id uint) (reason (string-ascii 150)))
  (let (
    (job-data (unwrap! (map-get? repair-jobs { job-id: job-id }) err-not-found))
    (escrow-data (unwrap! (map-get? job-escrow { job-id: job-id }) err-escrow-not-found))
  )
    (asserts! (is-eq tx-sender (get customer job-data)) err-unauthorized)
    (asserts! (get is-deposited escrow-data) err-escrow-not-found)
    (asserts! (not (get is-disputed escrow-data)) err-already-disputed)
    (map-set job-escrow { job-id: job-id } (merge escrow-data { is-disputed: true, dispute-reason: reason }))
    (ok true)
  )
)

(define-public (resolve-dispute (job-id uint) (favor-customer bool))
  (let (
    (job-data (unwrap! (map-get? repair-jobs { job-id: job-id }) err-not-found))
    (escrow-data (unwrap! (map-get? job-escrow { job-id: job-id }) err-escrow-not-found))
    (provider (unwrap! (get selected-provider job-data) err-not-found))
    (customer (get customer job-data))
  )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (get is-disputed escrow-data) err-invalid-warranty)
    (if favor-customer
      (try! (as-contract (stx-transfer? (get deposited-amount escrow-data) tx-sender customer)))
      (try! (as-contract (stx-transfer? (get deposited-amount escrow-data) tx-sender provider)))
    )
    (map-set job-escrow { job-id: job-id } (merge escrow-data { arbiter-decision: (some favor-customer) }))
    (map-set repair-jobs { job-id: job-id } (merge job-data { status: "disputed-resolved" }))
    (ok favor-customer)
  )
)