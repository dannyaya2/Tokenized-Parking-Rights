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

(define-data-var next-token-id uint u1)
(define-data-var parking-rate uint u1000000)
(define-data-var max-duration uint u144)

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
        (cost (calculate-parking-cost duration))
        (token-id spot-id))
    (asserts! (> duration u0) ERR_INVALID_DURATION)
    (asserts! (<= duration (var-get max-duration)) ERR_INVALID_DURATION)
    (asserts! (is-spot-available spot-id) ERR_SPOT_OCCUPIED)
    
    (try! (stx-transfer? cost tx-sender CONTRACT_OWNER))
    
    (try! (nft-mint? parking-right token-id tx-sender))
    
    (map-set parking-spots spot-id {
      owner: (some tx-sender),
      start-block: current-block,
      end-block: (+ current-block duration),
      price-paid: cost,
      transferable: true
    })
    
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
