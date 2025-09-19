;; Air Quality Oracle Contract
;; Manages air quality data collection, sensor registration, and validation

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-SENSOR-EXISTS (err u101))
(define-constant ERR-SENSOR-NOT-FOUND (err u102))
(define-constant ERR-INVALID-DATA (err u103))
(define-constant ERR-INSUFFICIENT-VALIDATORS (err u104))
(define-constant ERR-ALREADY-VOTED (err u105))
(define-constant MIN-VALIDATORS-REQUIRED u3)
(define-constant SENSOR-BOND-AMOUNT u1000000) ;; 1 STX
(define-constant DATA-VALIDITY-PERIOD u144) ;; ~1 day in blocks

;; Data structures
(define-map sensors
  { sensor-id: (string-ascii 64) }
  {
    owner: principal,
    location: { lat: int, lng: int },
    authorized: bool,
    bond-amount: uint,
    reputation-score: uint,
    total-submissions: uint,
    last-active: uint
  }
)

(define-map air-quality-data
  { submission-id: uint }
  {
    sensor-id: (string-ascii 64),
    timestamp: uint,
    location: { lat: int, lng: int },
    pm25: uint, ;; ug/m3 * 100 for precision
    pm10: uint,
    no2: uint,
    so2: uint,
    co: uint,   ;; mg/m3 * 100
    o3: uint,
    aqi: uint,
    validator-votes: uint,
    validation-status: (string-ascii 20),
    reward-distributed: bool
  }
)

(define-map data-validators
  { submission-id: uint, validator: principal }
  { vote: bool, timestamp: uint }
)

(define-map sensor-rewards
  { sensor-id: (string-ascii 64) }
  { total-earned: uint, last-claim: uint }
)

;; Data variables
(define-data-var next-submission-id uint u1)
(define-data-var total-sensors uint u0)
(define-data-var reward-pool uint u0)

;; Public functions

;; Register a new sensor
(define-public (register-sensor (sensor-id (string-ascii 64)) (lat int) (lng int))
  (let ((existing-sensor (map-get? sensors { sensor-id: sensor-id })))
    (asserts! (is-none existing-sensor) ERR-SENSOR-EXISTS)
    (try! (stx-transfer? SENSOR-BOND-AMOUNT tx-sender CONTRACT-OWNER))
    (map-set sensors
      { sensor-id: sensor-id }
      {
        owner: tx-sender,
        location: { lat: lat, lng: lng },
        authorized: false,
        bond-amount: SENSOR-BOND-AMOUNT,
        reputation-score: u100,
        total-submissions: u0,
        last-active: stacks-block-height
      }
    )
    (var-set total-sensors (+ (var-get total-sensors) u1))
    (ok sensor-id)
  )
)

;; Authorize sensor (only contract owner)
(define-public (authorize-sensor (sensor-id (string-ascii 64)))
  (let ((sensor (unwrap! (map-get? sensors { sensor-id: sensor-id }) ERR-SENSOR-NOT-FOUND)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-set sensors
      { sensor-id: sensor-id }
      (merge sensor { authorized: true })
    )
    (ok true)
  )
)

;; Submit air quality data
(define-public (submit-air-quality-data 
  (sensor-id (string-ascii 64))
  (lat int) (lng int)
  (pm25 uint) (pm10 uint) (no2 uint) (so2 uint) (co uint) (o3 uint))
  (let (
    (sensor (unwrap! (map-get? sensors { sensor-id: sensor-id }) ERR-SENSOR-NOT-FOUND))
    (submission-id (var-get next-submission-id))
    (calculated-aqi (calculate-aqi pm25 pm10 no2 so2 co o3))
  )
    (asserts! (get authorized sensor) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq tx-sender (get owner sensor)) ERR-NOT-AUTHORIZED)
    (asserts! (validate-pollutant-levels pm25 pm10 no2 so2 co o3) ERR-INVALID-DATA)
    
    (map-set air-quality-data
      { submission-id: submission-id }
      {
        sensor-id: sensor-id,
        timestamp: stacks-block-height,
        location: { lat: lat, lng: lng },
        pm25: pm25,
        pm10: pm10,
        no2: no2,
        so2: so2,
        co: co,
        o3: o3,
        aqi: calculated-aqi,
        validator-votes: u0,
        validation-status: "pending",
        reward-distributed: false
      }
    )
    
    ;; Update sensor stats
    (map-set sensors
      { sensor-id: sensor-id }
      (merge sensor {
        total-submissions: (+ (get total-submissions sensor) u1),
        last-active: stacks-block-height
      })
    )
    
    (var-set next-submission-id (+ submission-id u1))
    (ok submission-id)
  )
)

;; Validate data submission (called by validators)
(define-public (validate-data (submission-id uint) (is-valid bool))
  (let (
    (data (unwrap! (map-get? air-quality-data { submission-id: submission-id }) ERR-INVALID-DATA))
    (existing-vote (map-get? data-validators { submission-id: submission-id, validator: tx-sender }))
  )
    (asserts! (is-none existing-vote) ERR-ALREADY-VOTED)
    (asserts! (< (- stacks-block-height (get timestamp data)) DATA-VALIDITY-PERIOD) ERR-INVALID-DATA)
    
    (map-set data-validators
      { submission-id: submission-id, validator: tx-sender }
      { vote: is-valid, timestamp: stacks-block-height }
    )
    
    (let ((new-votes (+ (get validator-votes data) u1)))
      (map-set air-quality-data
        { submission-id: submission-id }
        (merge data { validator-votes: new-votes })
      )
      
      ;; Check if we have enough votes to finalize
      (if (>= new-votes MIN-VALIDATORS-REQUIRED)
        (finalize-validation submission-id)
        (ok true)
      )
    )
  )
)

;; Claim rewards for validated data
(define-public (claim-sensor-reward (sensor-id (string-ascii 64)))
  (let (
    (sensor (unwrap! (map-get? sensors { sensor-id: sensor-id }) ERR-SENSOR-NOT-FOUND))
    (rewards (default-to { total-earned: u0, last-claim: u0 } 
                         (map-get? sensor-rewards { sensor-id: sensor-id })))
  )
    (asserts! (is-eq tx-sender (get owner sensor)) ERR-NOT-AUTHORIZED)
    (let ((pending-reward (- (get total-earned rewards) (get last-claim rewards))))
      (asserts! (> pending-reward u0) ERR-INVALID-DATA)
      (try! (as-contract (stx-transfer? pending-reward tx-sender (get owner sensor))))
      (map-set sensor-rewards
        { sensor-id: sensor-id }
        (merge rewards { last-claim: (get total-earned rewards) })
      )
      (ok pending-reward)
    )
  )
)

;; Read-only functions

(define-read-only (get-sensor-info (sensor-id (string-ascii 64)))
  (map-get? sensors { sensor-id: sensor-id })
)

(define-read-only (get-air-quality-data (submission-id uint))
  (map-get? air-quality-data { submission-id: submission-id })
)

(define-read-only (get-sensor-rewards (sensor-id (string-ascii 64)))
  (map-get? sensor-rewards { sensor-id: sensor-id })
)

(define-read-only (get-validation-vote (submission-id uint) (validator principal))
  (map-get? data-validators { submission-id: submission-id, validator: validator })
)

(define-read-only (get-total-sensors)
  (var-get total-sensors)
)

(define-read-only (get-next-submission-id)
  (var-get next-submission-id)
)

;; Private functions

(define-private (calculate-aqi (pm25 uint) (pm10 uint) (no2 uint) (so2 uint) (co uint) (o3 uint))
  ;; Simplified AQI calculation - returns highest individual pollutant AQI
  (let (
    (pm25-aqi (if (<= pm25 u1200) ;; 12.0 ug/m3
                  (/ (* pm25 u50) u1200)
                  (if (<= pm25 u3550) ;; 35.5 ug/m3
                      (+ u50 (/ (* (- pm25 u1200) u50) u2350))
                      u150)))
    (pm10-aqi (if (<= pm10 u5400) ;; 54 ug/m3
                  (/ (* pm10 u50) u5400)
                  (if (<= pm10 u15400) ;; 154 ug/m3
                      (+ u50 (/ (* (- pm10 u5400) u50) u10000))
                      u150)))
  )
    (if (> pm25-aqi pm10-aqi) pm25-aqi pm10-aqi)
  )
)

(define-private (validate-pollutant-levels (pm25 uint) (pm10 uint) (no2 uint) (so2 uint) (co uint) (o3 uint))
  ;; Basic validation - ensure values are within reasonable ranges
  (and
    (<= pm25 u50000)   ;; max 500 ug/m3
    (<= pm10 u100000)  ;; max 1000 ug/m3
    (<= no2 u20000)    ;; max 200 ug/m3
    (<= so2 u100000)   ;; max 1000 ug/m3
    (<= co u10000)     ;; max 100 mg/m3
    (<= o3 u50000)     ;; max 500 ug/m3
  )
)

(define-private (finalize-validation (submission-id uint))
  (let (
    (data (unwrap! (map-get? air-quality-data { submission-id: submission-id }) ERR-INVALID-DATA))
    (valid-votes (count-valid-votes submission-id))
    (total-votes (get validator-votes data))
  )
    (let (
      (is-data-valid (> (* valid-votes u2) total-votes)) ;; majority rule
      (new-status (if is-data-valid "validated" "rejected"))
    )
      (map-set air-quality-data
        { submission-id: submission-id }
        (merge data { validation-status: new-status })
      )
      
      ;; Distribute rewards if validated
      (if is-data-valid
        (unwrap-panic (distribute-sensor-reward (get sensor-id data) submission-id))
        u0
      )
      (ok is-data-valid)
    )
  )
)

(define-private (count-valid-votes (submission-id uint))
  ;; This is a simplified version - in practice, you'd need to iterate through validators
  ;; For this contract, we'll assume 2/3 votes are valid as an example
  (let ((data (unwrap-panic (map-get? air-quality-data { submission-id: submission-id }))))
    (/ (* (get validator-votes data) u2) u3)
  )
)

(define-private (distribute-sensor-reward (sensor-id (string-ascii 64)) (submission-id uint))
  (let (
    (base-reward u1000) ;; base reward amount
    (current-rewards (default-to { total-earned: u0, last-claim: u0 }
                                  (map-get? sensor-rewards { sensor-id: sensor-id })))
  )
    (map-set sensor-rewards
      { sensor-id: sensor-id }
      (merge current-rewards { 
        total-earned: (+ (get total-earned current-rewards) base-reward) 
      })
    )
    (ok base-reward)
  )
)

