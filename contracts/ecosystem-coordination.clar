;; Ecosystem Coordination Contract
;; Manages autonomous mobility network coordination

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_SERVICE_NOT_FOUND (err u201))
(define-constant ERR_INVALID_COORDINATES (err u202))
(define-constant ERR_SERVICE_UNAVAILABLE (err u203))

;; Data Variables
(define-data-var next-service-id uint u1)
(define-data-var network-status bool true)

;; Data Maps
(define-map mobility-services
  { service-id: uint }
  {
    provider: principal,
    service-type: (string-ascii 20),
    location-lat: int,
    location-lon: int,
    capacity: uint,
    available: bool,
    price-per-km: uint
  }
)

(define-map service-requests
  { request-id: uint }
  {
    requester: principal,
    service-id: uint,
    pickup-lat: int,
    pickup-lon: int,
    destination-lat: int,
    destination-lon: int,
    status: (string-ascii 20),
    timestamp: uint
  }
)

(define-map provider-stats
  { provider: principal }
  {
    total-services: uint,
    active-services: uint,
    rating: uint
  }
)

;; Public Functions
(define-public (register-service (service-type (string-ascii 20)) (location-lat int) (location-lon int) (capacity uint) (price-per-km uint))
  (let ((service-id (var-get next-service-id)))
    (asserts! (and (>= location-lat -90000000) (<= location-lat 90000000)) ERR_INVALID_COORDINATES)
    (asserts! (and (>= location-lon -180000000) (<= location-lon 180000000)) ERR_INVALID_COORDINATES)
    (asserts! (> capacity u0) ERR_INVALID_COORDINATES)

    (map-set mobility-services
      { service-id: service-id }
      {
        provider: tx-sender,
        service-type: service-type,
        location-lat: location-lat,
        location-lon: location-lon,
        capacity: capacity,
        available: true,
        price-per-km: price-per-km
      }
    )

    (map-set provider-stats
      { provider: tx-sender }
      {
        total-services: (+ (get-provider-total-services tx-sender) u1),
        active-services: (+ (get-provider-active-services tx-sender) u1),
        rating: (get-provider-rating tx-sender)
      }
    )

    (var-set next-service-id (+ service-id u1))
    (ok service-id)
  )
)

(define-public (request-service (service-id uint) (pickup-lat int) (pickup-lon int) (destination-lat int) (destination-lon int))
  (let ((service (unwrap! (map-get? mobility-services { service-id: service-id }) ERR_SERVICE_NOT_FOUND)))
    (asserts! (var-get network-status) ERR_SERVICE_UNAVAILABLE)
    (asserts! (get available service) ERR_SERVICE_UNAVAILABLE)

    (map-set service-requests
      { request-id: service-id }
      {
        requester: tx-sender,
        service-id: service-id,
        pickup-lat: pickup-lat,
        pickup-lon: pickup-lon,
        destination-lat: destination-lat,
        destination-lon: destination-lon,
        status: "pending",
        timestamp: block-height
      }
    )
    (ok true)
  )
)

(define-public (update-service-availability (service-id uint) (available bool))
  (let ((service (unwrap! (map-get? mobility-services { service-id: service-id }) ERR_SERVICE_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get provider service)) ERR_UNAUTHORIZED)

    (map-set mobility-services
      { service-id: service-id }
      (merge service { available: available })
    )
    (ok true)
  )
)

(define-public (toggle-network-status)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set network-status (not (var-get network-status)))
    (ok (var-get network-status))
  )
)

;; Read-only Functions
(define-read-only (get-service (service-id uint))
  (map-get? mobility-services { service-id: service-id })
)

(define-read-only (get-service-request (request-id uint))
  (map-get? service-requests { request-id: request-id })
)

(define-read-only (get-network-status)
  (var-get network-status)
)

(define-read-only (get-provider-total-services (provider principal))
  (default-to u0 (get total-services (map-get? provider-stats { provider: provider })))
)

(define-read-only (get-provider-active-services (provider principal))
  (default-to u0 (get active-services (map-get? provider-stats { provider: provider })))
)

(define-read-only (get-provider-rating (provider principal))
  (default-to u0 (get rating (map-get? provider-stats { provider: provider })))
)
