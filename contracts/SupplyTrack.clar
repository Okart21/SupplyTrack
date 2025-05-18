;; SupplyTrack - A decentralized supply chain tracking and verification platform
;; Enables transparent product tracking from manufacturer to consumer

;; Data storage
(define-map participant-profiles principal {
  active: bool,
  certifications: (list 10 uint),
  reputation: uint,
  last-action: uint,
  transaction-count: uint
})

(define-map product-batches uint {
  manufacturer: principal,
  quantity: uint,
  quality-score: uint,
  active: bool,
  product-type: uint,
  total-transfers: uint,
  created-at: uint
})

(define-map transfer-records {participant: principal, batch-id: uint} {
  timestamp: uint,
  verified: bool
})

(define-map product-types uint (string-ascii 64))

;; Constants
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_INVALID_PARAMS (err u101))
(define-constant ERR_PARTICIPANT_NOT_FOUND (err u102))
(define-constant ERR_BATCH_NOT_FOUND (err u103))
(define-constant ERR_INSUFFICIENT_QUANTITY (err u104))
(define-constant ERR_ALREADY_REGISTERED (err u105))
(define-constant ERR_ALREADY_TRANSFERRED (err u106))
(define-constant ERR_INVALID_PRINCIPAL (err u107))
(define-constant ERR_INVALID_VALUE (err u108))
(define-constant ERR_PRODUCT_TYPE_NOT_FOUND (err u109))

(define-constant ZERO_ADDRESS 'SP000000000000000000002Q6VF78)
(define-constant MIN_QUALITY_SCORE u1)
(define-constant MAX_QUALITY_SCORE u1000)
(define-constant MIN_BATCH_QUANTITY u1000)
(define-constant MAX_PRODUCT_TYPE_ID u1000)

;; Data variables
(define-data-var contract-owner principal tx-sender)
(define-data-var next-batch-id uint u1)
(define-data-var network-fee-percent uint u5) ;; 5% fee
(define-data-var network-balance uint u0)

;; Admin functions
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (asserts! (not (is-eq new-owner ZERO_ADDRESS)) ERR_INVALID_PRINCIPAL)
    (ok (var-set contract-owner new-owner))))

(define-public (set-network-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (asserts! (<= new-fee u20) ERR_INVALID_PARAMS) ;; Max 20% fee
    (ok (var-set network-fee-percent new-fee))))

(define-public (add-product-type (type-id uint) (type-name (string-ascii 64)))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (asserts! (> (len type-name) u0) ERR_INVALID_PARAMS)
    ;; Validate type ID
    (asserts! (< type-id MAX_PRODUCT_TYPE_ID) ERR_INVALID_PARAMS)
    (asserts! (is-none (map-get? product-types type-id)) ERR_ALREADY_REGISTERED)
    (ok (map-set product-types type-id type-name))))

;; User functions
(define-public (register-participant (certifications (list 10 uint)))
  (begin
    (asserts! (is-none (map-get? participant-profiles tx-sender)) ERR_ALREADY_REGISTERED)
    (asserts! (validate-certifications certifications) ERR_INVALID_PARAMS)
    (ok (map-set participant-profiles tx-sender {
      active: true,
      certifications: certifications,
      reputation: u0,
      last-action: u0,
      transaction-count: u0
    }))))

(define-public (update-certifications (certifications (list 10 uint)))
  (let ((participant-profile (unwrap! (map-get? participant-profiles tx-sender) ERR_PARTICIPANT_NOT_FOUND)))
    (asserts! (validate-certifications certifications) ERR_INVALID_PARAMS)
    (ok (map-set participant-profiles tx-sender (merge participant-profile {certifications: certifications})))))

(define-public (deactivate-participant)
  (let ((participant-profile (unwrap! (map-get? participant-profiles tx-sender) ERR_PARTICIPANT_NOT_FOUND)))
    (ok (map-set participant-profiles tx-sender (merge participant-profile {active: false})))))

(define-public (reactivate-participant)
  (let ((participant-profile (unwrap! (map-get? participant-profiles tx-sender) ERR_PARTICIPANT_NOT_FOUND)))
    (ok (map-set participant-profiles tx-sender (merge participant-profile {active: true})))))

;; Manufacturer functions
(define-public (create-product-batch (quantity uint) (quality-score uint) (product-type uint) (stx-amount uint))
  (begin
    (asserts! (>= quantity MIN_BATCH_QUANTITY) ERR_INVALID_PARAMS)
    (asserts! (and (>= quality-score MIN_QUALITY_SCORE) (<= quality-score MAX_QUALITY_SCORE)) ERR_INVALID_PARAMS)
    (asserts! (is-some (map-get? product-types product-type)) ERR_PRODUCT_TYPE_NOT_FOUND)
    (asserts! (>= stx-amount quantity) ERR_INSUFFICIENT_QUANTITY)
    
    ;; Transfer STX to contract
    (try! (stx-transfer? stx-amount tx-sender (as-contract tx-sender)))
    
    (let ((batch-id (var-get next-batch-id)))
      ;; Create batch
      (map-set product-batches batch-id {
        manufacturer: tx-sender,
        quantity: quantity,
        quality-score: quality-score,
        active: true,
        product-type: product-type,
        total-transfers: u0,
        created-at: u0
      })
      
      ;; Increment batch ID
      (var-set next-batch-id (+ batch-id u1))
      (ok batch-id))))

(define-public (recall-batch (batch-id uint))
  (let ((batch (unwrap! (map-get? product-batches batch-id) ERR_BATCH_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get manufacturer batch)) ERR_NOT_AUTHORIZED)
    (ok (map-set product-batches batch-id (merge batch {active: false})))))

(define-public (reactivate-batch (batch-id uint))
  (let ((batch (unwrap! (map-get? product-batches batch-id) ERR_BATCH_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get manufacturer batch)) ERR_NOT_AUTHORIZED)
    (ok (map-set product-batches batch-id (merge batch {active: true})))))

(define-public (add-batch-quantity (batch-id uint) (additional-quantity uint))
  (let ((batch (unwrap! (map-get? product-batches batch-id) ERR_BATCH_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get manufacturer batch)) ERR_NOT_AUTHORIZED)
    (asserts! (> additional-quantity u0) ERR_INVALID_PARAMS)
    
    ;; Transfer STX to contract
    (try! (stx-transfer? additional-quantity tx-sender (as-contract tx-sender)))
    
    (ok (map-set product-batches batch-id 
      (merge batch {quantity: (+ (get quantity batch) additional-quantity)})))))

;; Helper function to check if a product type matches participant certifications
(define-private (check-certification-match (product-type uint) (certifications (list 10 uint)))
  (or
    (and (> (len certifications) u0) (is-eq product-type (unwrap-panic (element-at certifications u0))))
    (and (> (len certifications) u1) (is-eq product-type (unwrap-panic (element-at certifications u1))))
    (and (> (len certifications) u2) (is-eq product-type (unwrap-panic (element-at certifications u2))))
    (and (> (len certifications) u3) (is-eq product-type (unwrap-panic (element-at certifications u3))))
    (and (> (len certifications) u4) (is-eq product-type (unwrap-panic (element-at certifications u4))))
    (and (> (len certifications) u5) (is-eq product-type (unwrap-panic (element-at certifications u5))))
    (and (> (len certifications) u6) (is-eq product-type (unwrap-panic (element-at certifications u6))))
    (and (> (len certifications) u7) (is-eq product-type (unwrap-panic (element-at certifications u7))))
    (and (> (len certifications) u8) (is-eq product-type (unwrap-panic (element-at certifications u8))))
    (and (> (len certifications) u9) (is-eq product-type (unwrap-panic (element-at certifications u9))))
  ))

;; Transfer and verification
(define-public (verify-transfer (batch-id uint))
  (let (
    (participant-profile (unwrap! (map-get? participant-profiles tx-sender) ERR_PARTICIPANT_NOT_FOUND))
    (batch (unwrap! (map-get? product-batches batch-id) ERR_BATCH_NOT_FOUND))
    (transfer-key {participant: tx-sender, batch-id: batch-id})
  )
    ;; Validate conditions
    (asserts! (get active participant-profile) ERR_PARTICIPANT_NOT_FOUND)
    (asserts! (get active batch) ERR_BATCH_NOT_FOUND)
    (asserts! (is-none (map-get? transfer-records transfer-key)) ERR_ALREADY_TRANSFERRED)
    (asserts! (>= (get quantity batch) (get quality-score batch)) ERR_INSUFFICIENT_QUANTITY)
    (asserts! (check-certification-match (get product-type batch) (get certifications participant-profile)) ERR_INVALID_PARAMS)
    
    ;; Calculate reputation gain
    (let (
      (quality-score (get quality-score batch))
      (network-fee (/ (* quality-score (var-get network-fee-percent)) u100))
      (participant-reputation (- quality-score network-fee))
    )
      ;; Record the transfer
      (map-set transfer-records transfer-key {timestamp: u0, verified: true})
      
      ;; Update batch stats
      (map-set product-batches batch-id (merge batch {
        quantity: (- (get quantity batch) quality-score),
        total-transfers: (+ (get total-transfers batch) u1)
      }))
      
      ;; Update participant stats
      (map-set participant-profiles tx-sender (merge participant-profile {
        reputation: (+ (get reputation participant-profile) participant-reputation),
        transaction-count: (+ (get transaction-count participant-profile) u1)
      }))
      
      ;; Update network balance
      (var-set network-balance (+ (var-get network-balance) network-fee))
      
      (ok participant-reputation))))

(define-public (claim-reputation)
  (let ((participant-profile (unwrap! (map-get? participant-profiles tx-sender) ERR_PARTICIPANT_NOT_FOUND)))
    (let ((reputation (get reputation participant-profile)))
      (asserts! (> reputation u0) ERR_INSUFFICIENT_QUANTITY)
      
      ;; Transfer STX to participant
      (try! (as-contract (stx-transfer? reputation tx-sender tx-sender)))
      
      ;; Update participant profile
      (map-set participant-profiles tx-sender (merge participant-profile {
        reputation: u0,
        last-action: u0
      }))
      
      (ok reputation))))

(define-public (withdraw-network-fees)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (let ((amount (var-get network-balance)))
      (asserts! (> amount u0) ERR_INSUFFICIENT_QUANTITY)
      
      ;; Transfer STX to contract owner
      (try! (as-contract (stx-transfer? amount tx-sender (var-get contract-owner))))
      
      ;; Reset network balance
      (var-set network-balance u0)
      
      (ok amount))))

;; Helper function to check if a product type is valid
(define-private (is-valid-product-type (product-type uint))
  (is-some (map-get? product-types product-type)))

;; Helper function to count valid product types in a list
(define-private (count-valid-product-types (certifications (list 10 uint)))
  (+ 
    (if (and (> (len certifications) u0) (is-valid-product-type (unwrap-panic (element-at certifications u0)))) u1 u0)
    (if (and (> (len certifications) u1) (is-valid-product-type (unwrap-panic (element-at certifications u1)))) u1 u0)
    (if (and (> (len certifications) u2) (is-valid-product-type (unwrap-panic (element-at certifications u2)))) u1 u0)
    (if (and (> (len certifications) u3) (is-valid-product-type (unwrap-panic (element-at certifications u3)))) u1 u0)
    (if (and (> (len certifications) u4) (is-valid-product-type (unwrap-panic (element-at certifications u4)))) u1 u0)
    (if (and (> (len certifications) u5) (is-valid-product-type (unwrap-panic (element-at certifications u5)))) u1 u0)
    (if (and (> (len certifications) u6) (is-valid-product-type (unwrap-panic (element-at certifications u6)))) u1 u0)
    (if (and (> (len certifications) u7) (is-valid-product-type (unwrap-panic (element-at certifications u7)))) u1 u0)
    (if (and (> (len certifications) u8) (is-valid-product-type (unwrap-panic (element-at certifications u8)))) u1 u0)
    (if (and (> (len certifications) u9) (is-valid-product-type (unwrap-panic (element-at certifications u9)))) u1 u0)
  ))

;; Validate participant certifications
(define-private (validate-certifications (certifications (list 10 uint)))
  (let ((certs-len (len certifications)))
    (and 
      (> certs-len u0)
      (<= certs-len u10)
      (is-eq certs-len (count-valid-product-types certifications)))))

;; Read-only functions
(define-read-only (get-participant-profile (participant principal))
  (map-get? participant-profiles participant))

(define-read-only (get-batch (batch-id uint))
  (map-get? product-batches batch-id))

(define-read-only (get-product-type (type-id uint))
  (map-get? product-types type-id))

(define-read-only (get-network-fee)
  (var-get network-fee-percent))

(define-read-only (get-network-balance)
  (var-get network-balance))

(define-read-only (get-transfer-record (participant principal) (batch-id uint))
  (map-get? transfer-records {participant: participant, batch-id: batch-id}))