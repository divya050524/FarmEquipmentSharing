;; FarmEquipment Sharing Contract
;; A peer-to-peer agricultural equipment rental system with usage tracking and maintenance scheduling

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-equipment-not-found (err u101))
(define-constant err-equipment-not-available (err u102))
(define-constant err-unauthorized (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-already-rented (err u105))
(define-constant err-maintenance-required (err u106))

;; Equipment status constants
(define-constant status-available u1)
(define-constant status-rented u2)
(define-constant status-maintenance u3)

;; Data structures
(define-map equipment-registry 
  uint 
  {
    owner: principal,
    name: (string-ascii 50),
    equipment-type: (string-ascii 30),
    rental-rate-per-day: uint,
    status: uint,
    total-usage-hours: uint,
    last-maintenance-block: uint,
    maintenance-interval-blocks: uint,
    location: (string-ascii 100)
  })

(define-map rental-agreements
  uint
  {
    equipment-id: uint,
    renter: principal,
    start-block: uint,
    end-block: uint,
    total-cost: uint,
    usage-hours: uint,
    is-active: bool
  })

;; Tracking variables
(define-data-var next-equipment-id uint u1)
(define-data-var next-rental-id uint u1)

;; Function 1: Register Equipment
;; Allows farmers to register their equipment for rental
(define-public (register-equipment 
    (name (string-ascii 50))
    (equipment-type (string-ascii 30))
    (rental-rate-per-day uint)
    (maintenance-interval-blocks uint)
    (location (string-ascii 100)))
  (let ((equipment-id (var-get next-equipment-id)))
    (begin
      (asserts! (> rental-rate-per-day u0) err-invalid-amount)
      (asserts! (> maintenance-interval-blocks u0) err-invalid-amount)
      
      ;; Register the equipment
      (map-set equipment-registry equipment-id {
        owner: tx-sender,
        name: name,
        equipment-type: equipment-type,
        rental-rate-per-day: rental-rate-per-day,
        status: status-available,
        total-usage-hours: u0,
        last-maintenance-block: stacks-block-height,
        maintenance-interval-blocks: maintenance-interval-blocks,
        location: location
      })
      
      ;; Increment the equipment ID counter
      (var-set next-equipment-id (+ equipment-id u1))
      
      ;; Print event for off-chain tracking
      (print {
        event: "equipment-registered",
        equipment-id: equipment-id,
        owner: tx-sender,
        name: name,
        equipment-type: equipment-type
      })
      
      (ok equipment-id))))

;; Function 2: Rent Equipment
;; Allows farmers to rent equipment from others with automatic maintenance checking
(define-public (rent-equipment 
    (equipment-id uint)
    (rental-duration-days uint)
    (estimated-usage-hours uint))
  (let ((equipment-data (unwrap! (map-get? equipment-registry equipment-id) err-equipment-not-found))
        (rental-id (var-get next-rental-id))
        (total-cost (* (get rental-rate-per-day equipment-data) rental-duration-days))
        (rental-end-block (+ stacks-block-height (* rental-duration-days u144)))) ;; Assuming ~144 blocks per day
    (begin
      ;; Validate equipment availability
      (asserts! (is-eq (get status equipment-data) status-available) err-equipment-not-available)
      (asserts! (> rental-duration-days u0) err-invalid-amount)
      (asserts! (> estimated-usage-hours u0) err-invalid-amount)
      
      ;; Check if maintenance is required
      (asserts! (< (- stacks-block-height (get last-maintenance-block equipment-data)) 
                   (get maintenance-interval-blocks equipment-data)) err-maintenance-required)
      
      ;; Transfer rental payment (simplified - in reality would use STX or custom token)
      (try! (stx-transfer? total-cost tx-sender (get owner equipment-data)))
      
      ;; Create rental agreement
      (map-set rental-agreements rental-id {
        equipment-id: equipment-id,
        renter: tx-sender,
        start-block: stacks-block-height,
        end-block: rental-end-block,
        total-cost: total-cost,
        usage-hours: estimated-usage-hours,
        is-active: true
      })
      
      ;; Update equipment status to rented
      (map-set equipment-registry equipment-id (merge equipment-data {
        status: status-rented,
        total-usage-hours: (+ (get total-usage-hours equipment-data) estimated-usage-hours)
      }))
      
      ;; Increment rental ID counter
      (var-set next-rental-id (+ rental-id u1))
      
      ;; Print event for off-chain tracking
      (print {
        event: "equipment-rented",
        rental-id: rental-id,
        equipment-id: equipment-id,
        renter: tx-sender,
        duration-days: rental-duration-days,
        total-cost: total-cost
      })
      
      (ok rental-id))))

;; Read-only functions for data retrieval

;; Get equipment details
(define-read-only (get-equipment (equipment-id uint))
  (map-get? equipment-registry equipment-id))

;; Get rental details
(define-read-only (get-rental (rental-id uint))
  (map-get? rental-agreements rental-id))

;; Check if equipment needs maintenance
(define-read-only (needs-maintenance (equipment-id uint))
  (match (map-get? equipment-registry equipment-id)
    equipment-data (ok (>= (- stacks-block-height (get last-maintenance-block equipment-data))
                           (get maintenance-interval-blocks equipment-data)))
    (err err-equipment-not-found)))

;; Get equipment status
(define-read-only (get-equipment-status (equipment-id uint))
  (match (map-get? equipment-registry equipment-id)
    equipment-data (ok (get status equipment-data))
    (err err-equipment-not-found)))