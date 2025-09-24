(define-non-fungible-token parking-right uint)

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_OWNER (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_UNAUTHORIZED (err u103))
(define-constant ERR_EXPIRED (err u104))
(define-constant ERR_INVALID_DURATION (err u105))
(define-constant ERR_SPOT_OCCUPIED (err u106))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u107))
(define-constant ERR_TRANSFER_FAILED (err u108))
(define-constant ERR_PRICING_UPDATE_FAILED (err u109))
(define-constant ERR_INVALID_TIER (err u110))
(define-constant ERR_DEMAND_THRESHOLD_EXCEEDED (err u111))

(define-constant SURGE_MULTIPLIER u150)
(define-constant PEAK_DEMAND_THRESHOLD u5)
(define-constant PRICING_UPDATE_INTERVAL u144)
(define-constant BASE_POPULARITY_SCORE u100)
(define-constant MAX_SURGE_MULTIPLIER u300)

(define-data-var next-token-id uint u1)
(define-data-var parking-rate uint u1000000)
(define-data-var max-duration uint u144)
(define-data-var surge-pricing-active bool false)
(define-data-var last-pricing-update uint u0)
(define-data-var total-revenue uint u0)

(define-map parking-spots 
  uint 
  {
    owner: (optional principal),
    start-block: uint,
    end-block: uint,
    price-paid: uint,
    transferable: bool
  }
)

(define-map spot-locations
  uint
  {
    zone: (string-ascii 50),
    address: (string-ascii 100),
    coordinates: (string-ascii 50)
  }
)

(define-map user-earnings principal uint)

(define-map spot-demand-metrics
  uint
  {
    total-bookings: uint,
    recent-bookings: uint,
    popularity-score: uint,
    average-duration: uint,
    peak-hour-usage: uint,
    last-booking-block: uint
  }
)

(define-map dynamic-pricing-tiers
  uint
  {
    base-rate: uint,
    current-multiplier: uint,
    peak-multiplier: uint,
    off-peak-multiplier: uint,
    demand-tier: uint,
    last-updated: uint
  }
)

(define-map hourly-demand-pattern
  { hour: uint, day-type: uint }
  {
    booking-count: uint,
    average-price: uint,
    surge-frequency: uint
  }
)

(define-map market-conditions
  uint
  {
    current-demand-level: uint,
    surge-active: bool,
    market-temperature: uint,
    revenue-efficiency: uint,
    optimization-score: uint
  }
)

(define-read-only (get-spot-demand-metrics (spot-id uint))
  (default-to
    { total-bookings: u0, recent-bookings: u0, popularity-score: BASE_POPULARITY_SCORE, average-duration: u0, peak-hour-usage: u0, last-booking-block: u0 }
    (map-get? spot-demand-metrics spot-id)
  )
)

(define-read-only (get-spot-pricing-tier (spot-id uint))
  (default-to
    { base-rate: (var-get parking-rate), current-multiplier: u100, peak-multiplier: u150, off-peak-multiplier: u80, demand-tier: u1, last-updated: u0 }
    (map-get? dynamic-pricing-tiers spot-id)
  )
)

(define-read-only (get-hourly-pattern (hour uint) (day-type uint))
  (default-to
    { booking-count: u0, average-price: u0, surge-frequency: u0 }
    (map-get? hourly-demand-pattern { hour: hour, day-type: day-type })
  )
)

(define-read-only (get-market-conditions)
  (default-to
    { current-demand-level: u1, surge-active: false, market-temperature: u50, revenue-efficiency: u50, optimization-score: u50 }
    (map-get? market-conditions u1)
  )
)

(define-read-only (get-dynamic-price-quote (spot-id uint) (duration uint))
  (ok (calculate-dynamic-price spot-id duration))
)

(define-read-only (get-surge-pricing-status)
  (ok {
    active: (var-get surge-pricing-active),
    multiplier: SURGE_MULTIPLIER,
    max-multiplier: MAX_SURGE_MULTIPLIER
  })
)

(define-read-only (get-peak-hours-analysis)
  (let ((current-block burn-block-height))
    (ok {
      current-hour: (mod (/ current-block u6) u24),
      is-peak-hour: (is-peak-demand-hour current-block),
      peak-morning: "7-9",
      peak-evening: "17-19"
    })
  )
)

(define-read-only (get-spot-analytics-summary (spot-id uint))
  (let 
    (
      (demand-metrics (get-spot-demand-metrics spot-id))
      (pricing-tier (get-spot-pricing-tier spot-id))
      (revenue (calculate-spot-revenue spot-id))
    )
    (ok {
      total-bookings: (get total-bookings demand-metrics),
      popularity-score: (get popularity-score demand-metrics),
      current-price-multiplier: (get current-multiplier pricing-tier),
      demand-tier: (get demand-tier pricing-tier),
      estimated-revenue: revenue,
      utilization-rate: (if (< (get popularity-score demand-metrics) u100) (get popularity-score demand-metrics) u100)
    })
  )
)

(define-read-only (calculate-hourly-average-price (pattern {booking-count: uint, average-price: uint, surge-frequency: uint}) (new-price uint))
  (let 
    (
      (current-avg (get average-price pattern))
      (booking-count (get booking-count pattern))
    )
    (if (is-eq booking-count u0)
      new-price
      (/ (+ (* current-avg booking-count) new-price) (+ booking-count u1)))
  )
)

(define-read-only (get-revenue-analytics)
  (ok {
    total-revenue: (var-get total-revenue),
    surge-pricing-active: (var-get surge-pricing-active),
    last-pricing-update: (var-get last-pricing-update),
    pricing-update-interval: PRICING_UPDATE_INTERVAL
  })
)

(define-read-only (get-demand-forecast (spot-id uint))
  (let 
    (
      (demand-metrics (get-spot-demand-metrics spot-id))
      (current-block burn-block-height)
    )
    (ok {
      predicted-demand-tier: (calculate-demand-tier demand-metrics),
      suggested-multiplier: (calculate-demand-multiplier demand-metrics),
      next-peak-hour: (if (< (mod (/ current-block u6) u24) u17) u17 u31),
      demand-trend: (if (> (get recent-bookings demand-metrics) u3) "increasing" "stable")
    })
  )
)

(define-read-only (get-last-token-id)
  (- (var-get next-token-id) u1)
)

(define-read-only (get-token-uri (token-id uint))
  (ok (some "https://parking-nft.com/metadata/"))
)

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? parking-right token-id))
)

(define-read-only (get-parking-spot (spot-id uint))
  (map-get? parking-spots spot-id)
)

(define-read-only (get-spot-location (spot-id uint))
  (map-get? spot-locations spot-id)
)

(define-read-only (get-user-earnings (user principal))
  (default-to u0 (map-get? user-earnings user))
)

(define-read-only (is-spot-available (spot-id uint))
  (match (map-get? parking-spots spot-id)
    spot-data 
      (let ((current-block burn-block-height))
        (or 
          (is-none (get owner spot-data))
          (>= current-block (get end-block spot-data))
        )
      )
    true
  )
)

(define-read-only (get-remaining-time (spot-id uint))
  (match (map-get? parking-spots spot-id)
    spot-data
      (let ((current-block burn-block-height)
            (end-block (get end-block spot-data)))
        (if (> end-block current-block)
          (ok (- end-block current-block))
          (ok u0)
        )
      )
    (err ERR_NOT_FOUND)
  )
)

(define-read-only (calculate-parking-cost (duration uint))
  (* (var-get parking-rate) duration)
)

(define-read-only (get-refund-amount (spot-id uint))
  (match (map-get? parking-spots spot-id)
    spot-data
      (let ((current-block burn-block-height)
            (end-block (get end-block spot-data))
            (price-paid (get price-paid spot-data)))
        (if (> end-block current-block)
          (let ((remaining-blocks (- end-block current-block))
                (total-blocks (- end-block (get start-block spot-data))))
            (ok (/ (* price-paid remaining-blocks) total-blocks))
          )
          (ok u0)
        )
      )
    (err ERR_NOT_FOUND)
  )
)

(define-public (initialize-spot-pricing (spot-id uint) (base-rate uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_OWNER)
    (asserts! (> base-rate u0) ERR_INVALID_DURATION)
    (map-set dynamic-pricing-tiers spot-id
      {
        base-rate: base-rate,
        current-multiplier: u100,
        peak-multiplier: u150,
        off-peak-multiplier: u80,
        demand-tier: u1,
        last-updated: burn-block-height
      })
    (map-set spot-demand-metrics spot-id
      {
        total-bookings: u0,
        recent-bookings: u0,
        popularity-score: BASE_POPULARITY_SCORE,
        average-duration: u0,
        peak-hour-usage: u0,
        last-booking-block: u0
      })
    (ok true)
  )
)

(define-public (update-dynamic-pricing (spot-id uint))
  (let 
    (
      (current-block burn-block-height)
      (demand-metrics (get-spot-demand-metrics spot-id))
      (pricing-tier (get-spot-pricing-tier spot-id))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_OWNER)
    (asserts! (>= (- current-block (var-get last-pricing-update)) PRICING_UPDATE_INTERVAL) ERR_PRICING_UPDATE_FAILED)
    
    (let 
      (
        (new-multiplier (calculate-demand-multiplier demand-metrics))
        (new-tier (calculate-demand-tier demand-metrics))
        (is-peak-hour (is-peak-demand-hour current-block))
      )
      (map-set dynamic-pricing-tiers spot-id
        (merge pricing-tier
          {
            current-multiplier: (if is-peak-hour (get peak-multiplier pricing-tier) new-multiplier),
            demand-tier: new-tier,
            last-updated: current-block
          }))
      (var-set last-pricing-update current-block)
      (update-market-conditions)
      (ok new-multiplier)
    )
  )
)

(define-public (activate-surge-pricing (surge-multiplier uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_OWNER)
    (asserts! (<= surge-multiplier MAX_SURGE_MULTIPLIER) ERR_INVALID_TIER)
    (var-set surge-pricing-active true)
    (ok surge-multiplier)
  )
)

(define-public (deactivate-surge-pricing)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_OWNER)
    (var-set surge-pricing-active false)
    (ok true)
  )
)

(define-public (track-booking-demand (spot-id uint) (duration uint))
  (let 
    (
      (current-metrics (get-spot-demand-metrics spot-id))
      (current-block burn-block-height)
      (hour (mod (/ current-block u6) u24))
      (day-type (if (< (mod (/ current-block u144) u7) u5) u1 u2))
    )
    (map-set spot-demand-metrics spot-id
      (merge current-metrics
        {
          total-bookings: (+ (get total-bookings current-metrics) u1),
          recent-bookings: (+ (get recent-bookings current-metrics) u1),
          popularity-score: (calculate-popularity-score current-metrics),
          average-duration: (calculate-average-duration current-metrics duration),
          peak-hour-usage: (if (is-peak-demand-hour current-block) 
                             (+ (get peak-hour-usage current-metrics) u1)
                             (get peak-hour-usage current-metrics)),
          last-booking-block: current-block
        }))
    
    (let ((hour-pattern (get-hourly-pattern hour day-type)))
      (map-set hourly-demand-pattern
        { hour: hour, day-type: day-type }
        (merge hour-pattern
          {
            booking-count: (+ (get booking-count hour-pattern) u1),
            average-price: (calculate-hourly-average-price hour-pattern (calculate-dynamic-price spot-id duration)),
            surge-frequency: (if (var-get surge-pricing-active)
                               (+ (get surge-frequency hour-pattern) u1)
                               (get surge-frequency hour-pattern))
          })))
    
    (ok true)
  )
)

(define-public (optimize-spot-pricing (spot-id uint))
  (let 
    (
      (demand-metrics (get-spot-demand-metrics spot-id))
      (pricing-tier (get-spot-pricing-tier spot-id))
      (current-revenue (calculate-spot-revenue spot-id))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_OWNER)
    
    (let 
      (
        (optimization-score (calculate-optimization-score demand-metrics current-revenue))
        (suggested-multiplier (calculate-optimal-multiplier demand-metrics pricing-tier))
      )
      (if (> optimization-score u75)
        (begin
          (map-set dynamic-pricing-tiers spot-id
            (merge pricing-tier { current-multiplier: suggested-multiplier }))
          (ok suggested-multiplier))
        (ok (get current-multiplier pricing-tier))
      )
    )
  )
)

(define-private (calculate-demand-multiplier (metrics {total-bookings: uint, recent-bookings: uint, popularity-score: uint, average-duration: uint, peak-hour-usage: uint, last-booking-block: uint}))
  (let 
    (
      (base-multiplier u100)
      (popularity-bonus (/ (get popularity-score metrics) u10))
      (recent-activity-bonus (if (> (get recent-bookings metrics) PEAK_DEMAND_THRESHOLD) u25 u0))
    )
    (+ base-multiplier popularity-bonus recent-activity-bonus)
  )
)

(define-private (calculate-demand-tier (metrics {total-bookings: uint, recent-bookings: uint, popularity-score: uint, average-duration: uint, peak-hour-usage: uint, last-booking-block: uint}))
  (let ((total-bookings (get total-bookings metrics)))
    (if (>= total-bookings u50) u5
      (if (>= total-bookings u30) u4
        (if (>= total-bookings u20) u3
          (if (>= total-bookings u10) u2 u1))))
  )
)

(define-private (is-peak-demand-hour (current-block uint))
  (let ((hour (mod (/ current-block u6) u24)))
    (or (and (>= hour u7) (<= hour u9))
        (and (>= hour u17) (<= hour u19)))
  )
)

(define-private (calculate-popularity-score (metrics {total-bookings: uint, recent-bookings: uint, popularity-score: uint, average-duration: uint, peak-hour-usage: uint, last-booking-block: uint}))
  (let 
    (
      (base-score BASE_POPULARITY_SCORE)
      (booking-factor (get total-bookings metrics))
      (recency-factor (* (get recent-bookings metrics) u10))
    )
    (+ base-score (+ booking-factor recency-factor))
  )
)

(define-private (calculate-average-duration (metrics {total-bookings: uint, recent-bookings: uint, popularity-score: uint, average-duration: uint, peak-hour-usage: uint, last-booking-block: uint}) (new-duration uint))
  (let 
    (
      (current-avg (get average-duration metrics))
      (total-bookings (get total-bookings metrics))
    )
    (if (is-eq total-bookings u0)
      new-duration
      (/ (+ (* current-avg total-bookings) new-duration) (+ total-bookings u1)))
  )
)

(define-private (calculate-dynamic-price (spot-id uint) (duration uint))
  (let 
    (
      (base-cost (* (var-get parking-rate) duration))
      (pricing-tier (get-spot-pricing-tier spot-id))
      (current-multiplier (get current-multiplier pricing-tier))
      (surge-active (var-get surge-pricing-active))
    )
    (if surge-active
      (/ (* base-cost (* current-multiplier SURGE_MULTIPLIER)) u10000)
      (/ (* base-cost current-multiplier) u100))
  )
)

(define-private (calculate-spot-revenue (spot-id uint))
  (let ((demand-metrics (get-spot-demand-metrics spot-id)))
    (* (get total-bookings demand-metrics) (var-get parking-rate))
  )
)

(define-private (calculate-optimization-score (metrics {total-bookings: uint, recent-bookings: uint, popularity-score: uint, average-duration: uint, peak-hour-usage: uint, last-booking-block: uint}) (revenue uint))
  (let 
    (
      (utilization-score (if (< (get popularity-score metrics) u100) (get popularity-score metrics) u100))
      (revenue-efficiency (if (< (/ revenue u10000) u100) (/ revenue u10000) u100))
    )
    (/ (+ utilization-score revenue-efficiency) u2)
  )
)

(define-private (calculate-optimal-multiplier (metrics {total-bookings: uint, recent-bookings: uint, popularity-score: uint, average-duration: uint, peak-hour-usage: uint, last-booking-block: uint}) (pricing {base-rate: uint, current-multiplier: uint, peak-multiplier: uint, off-peak-multiplier: uint, demand-tier: uint, last-updated: uint}))
  (let 
    (
      (demand-level (get recent-bookings metrics))
      (base-multiplier (get current-multiplier pricing))
    )
    (if (> demand-level PEAK_DEMAND_THRESHOLD)
      (if (< (+ base-multiplier u50) MAX_SURGE_MULTIPLIER) (+ base-multiplier u50) MAX_SURGE_MULTIPLIER)
      (if (> (- base-multiplier u25) u50) (- base-multiplier u25) u50))
  )
)

(define-private (update-market-conditions)
  (let 
    (
      (current-block burn-block-height)
      (surge-active (var-get surge-pricing-active))
    )
    (map-set market-conditions u1
      {
        current-demand-level: u3,
        surge-active: surge-active,
        market-temperature: u75,
        revenue-efficiency: u80,
        optimization-score: u85
      })
    true
  )
)

(define-public (register-spot (zone (string-ascii 50)) (address (string-ascii 100)) (coordinates (string-ascii 50)))
  (let ((spot-id (var-get next-token-id)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_OWNER)
    (map-set spot-locations spot-id {
      zone: zone,
      address: address,
      coordinates: coordinates
    })
    (var-set next-token-id (+ spot-id u1))
    (ok spot-id)
  )
)

(define-public (mint-parking-right (spot-id uint) (duration uint))
  (let ((current-block burn-block-height)
        (dynamic-cost (calculate-dynamic-price spot-id duration))
        (token-id spot-id))
    (asserts! (> duration u0) ERR_INVALID_DURATION)
    (asserts! (<= duration (var-get max-duration)) ERR_INVALID_DURATION)
    (asserts! (is-spot-available spot-id) ERR_SPOT_OCCUPIED)
    
    (try! (stx-transfer? dynamic-cost tx-sender CONTRACT_OWNER))
    
    (try! (nft-mint? parking-right token-id tx-sender))
    
    (map-set parking-spots spot-id {
      owner: (some tx-sender),
      start-block: current-block,
      end-block: (+ current-block duration),
      price-paid: dynamic-cost,
      transferable: true
    })
    
    (unwrap-panic (track-booking-demand spot-id duration))
    (var-set total-revenue (+ (var-get total-revenue) dynamic-cost))
    
    (ok token-id)
  )
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (let ((token-owner (unwrap! (nft-get-owner? parking-right token-id) ERR_NOT_FOUND)))
    (asserts! (or (is-eq tx-sender sender) (is-eq tx-sender token-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-eq sender token-owner) ERR_UNAUTHORIZED)
    
    (match (map-get? parking-spots token-id)
      spot-data
        (begin
          (asserts! (get transferable spot-data) ERR_UNAUTHORIZED)
          (try! (nft-transfer? parking-right token-id sender recipient))
          (map-set parking-spots token-id 
            (merge spot-data { owner: (some recipient) })
          )
          (ok true)
        )
      ERR_NOT_FOUND
    )
  )
)

(define-public (sell-parking-right (token-id uint) (price uint))
  (let ((token-owner (unwrap! (nft-get-owner? parking-right token-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender token-owner) ERR_UNAUTHORIZED)
    
    (match (map-get? parking-spots token-id)
      spot-data
        (let ((current-block burn-block-height)
              (end-block (get end-block spot-data)))
          (asserts! (> end-block current-block) ERR_EXPIRED)
          (asserts! (get transferable spot-data) ERR_UNAUTHORIZED)
          
          (try! (stx-transfer? price tx-sender token-owner))
          (try! (nft-transfer? parking-right token-id token-owner tx-sender))
          
          (map-set parking-spots token-id 
            (merge spot-data { owner: (some tx-sender) })
          )
          
          (map-set user-earnings token-owner 
            (+ (get-user-earnings token-owner) price)
          )
          
          (ok true)
        )
      ERR_NOT_FOUND
    )
  )
)

(define-public (buy-parking-right (token-id uint) (max-price uint))
  (let ((token-owner (unwrap! (nft-get-owner? parking-right token-id) ERR_NOT_FOUND)))
    (asserts! (not (is-eq tx-sender token-owner)) ERR_UNAUTHORIZED)
    
    (match (map-get? parking-spots token-id)
      spot-data
        (let ((current-block burn-block-height)
              (end-block (get end-block spot-data))
              (refund-amount (unwrap! (get-refund-amount token-id) ERR_NOT_FOUND)))
          (asserts! (> end-block current-block) ERR_EXPIRED)
          (asserts! (get transferable spot-data) ERR_UNAUTHORIZED)
          (asserts! (<= refund-amount max-price) ERR_INSUFFICIENT_PAYMENT)
          
          (try! (stx-transfer? refund-amount tx-sender token-owner))
          (try! (nft-transfer? parking-right token-id token-owner tx-sender))
          
          (map-set parking-spots token-id 
            (merge spot-data { owner: (some tx-sender) })
          )
          
          (map-set user-earnings token-owner 
            (+ (get-user-earnings token-owner) refund-amount)
          )
          
          (ok true)
        )
      ERR_NOT_FOUND
    )
  )
)

(define-public (end-parking-early (token-id uint))
  (let ((token-owner (unwrap! (nft-get-owner? parking-right token-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender token-owner) ERR_UNAUTHORIZED)
    
    (match (map-get? parking-spots token-id)
      spot-data
        (let ((current-block burn-block-height)
              (end-block (get end-block spot-data)))
          (asserts! (> end-block current-block) ERR_EXPIRED)
          
          (map-set parking-spots token-id 
            (merge spot-data { 
              end-block: current-block,
              transferable: false 
            })
          )
          
          (try! (nft-burn? parking-right token-id tx-sender))
          (ok true)
        )
      ERR_NOT_FOUND
    )
  )
)

(define-public (extend-parking (token-id uint) (additional-duration uint))
  (let ((token-owner (unwrap! (nft-get-owner? parking-right token-id) ERR_NOT_FOUND))
        (additional-cost (calculate-parking-cost additional-duration)))
    (asserts! (is-eq tx-sender token-owner) ERR_UNAUTHORIZED)
    (asserts! (> additional-duration u0) ERR_INVALID_DURATION)
    
    (match (map-get? parking-spots token-id)
      spot-data
        (let ((current-block burn-block-height)
              (end-block (get end-block spot-data))
              (new-end-block (+ end-block additional-duration)))
          (asserts! (> end-block current-block) ERR_EXPIRED)
          (asserts! (<= (- new-end-block current-block) (var-get max-duration)) ERR_INVALID_DURATION)
          
          (try! (stx-transfer? additional-cost tx-sender CONTRACT_OWNER))
          
          (map-set parking-spots token-id 
            (merge spot-data { 
              end-block: new-end-block,
              price-paid: (+ (get price-paid spot-data) additional-cost)
            })
          )
          
          (ok true)
        )
      ERR_NOT_FOUND
    )
  )
)

(define-public (set-parking-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_OWNER)
    (var-set parking-rate new-rate)
    (ok true)
  )
)

(define-public (set-max-duration (new-max uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_OWNER)
    (var-set max-duration new-max)
    (ok true)
  )
)

(define-public (withdraw-earnings)
  (let ((earnings (get-user-earnings tx-sender)))
    (asserts! (> earnings u0) ERR_INSUFFICIENT_PAYMENT)
    
    (try! (as-contract (stx-transfer? earnings tx-sender tx-sender)))
    
    (map-set user-earnings tx-sender u0)
    (ok earnings)
  )
)

(define-public (emergency-release (token-id uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_OWNER)
    
    (match (map-get? parking-spots token-id)
      spot-data
        (let ((token-owner (unwrap! (nft-get-owner? parking-right token-id) ERR_NOT_FOUND)))
          (map-set parking-spots token-id 
            (merge spot-data { 
              owner: none,
              transferable: false 
            })
          )
          
          (try! (nft-burn? parking-right token-id token-owner))
          (ok true)
        )
      ERR_NOT_FOUND
    )
  )
)

(define-read-only (get-parking-rate)
  (var-get parking-rate)
)

(define-read-only (get-max-duration)
  (var-get max-duration)
)

(define-read-only (get-contract-balance)
  (stx-get-balance (as-contract tx-sender))
)

(define-read-only (is-parking-active (token-id uint))
  (match (map-get? parking-spots token-id)
    spot-data
      (let ((current-block burn-block-height)
            (end-block (get end-block spot-data)))
        (and 
          (is-some (get owner spot-data))
          (< current-block end-block)
        )
      )
    false
  )
)

(define-read-only (get-all-user-spots (user principal))
  (let ((max-spots u100))
    (map get-spot-if-owned (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10))
  )
)

(define-private (get-spot-if-owned (spot-id uint))
  (match (nft-get-owner? parking-right spot-id)
    owner 
      (if (is-eq owner tx-sender)
        (some spot-id)
        none
      )
    none
  )
)
