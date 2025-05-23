;; aid-distribution.clar - Transparent humanitarian aid distribution

;; Error codes - consolidated
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_INVALID_STATE (err u102))
(define-constant ERR_INSUFFICIENT_FUNDS (err u103))
(define-constant ERR_INVALID_INPUT (err u104))

;; Constants
(define-constant ORG_TYPES {donor: u1, implementer: u2, auditor: u3})
(define-constant CAMPAIGN_STATUS {active: u1, completed: u2})
(define-constant ZERO_PRINCIPAL 'SP000000000000000000002Q6VF78)

;; Data variables
(define-data-var admin principal tx-sender)
(define-data-var campaign-counter uint u0)

;; Data maps
(define-map organizations principal {
  org-type: uint,
  verified: bool,
  name: (string-utf8 50)
})

(define-map campaigns uint {
  name: (string-utf8 50),
  implementer: principal,
  target: uint,
  raised: uint,
  distributed: uint,
  status: uint,
  region: (string-utf8 50)
})

(define-map beneficiaries {campaign-id: uint, beneficiary-id: (string-utf8 30)} {
  name: (string-utf8 50),
  allocated: uint,
  received: uint
})

;; Read-only functions
(define-read-only (get-organization (org principal))
  (map-get? organizations org))

(define-read-only (get-campaign (id uint))
  (map-get? campaigns id))

(define-read-only (get-beneficiary (campaign-id uint) (beneficiary-id (string-utf8 30)))
  (map-get? beneficiaries {campaign-id: campaign-id, beneficiary-id: beneficiary-id}))

;; Helper functions
(define-private (is-admin)
  (is-eq tx-sender (var-get admin)))

(define-private (is-verified-implementer)
  (match (get-organization tx-sender)
    org (and (is-eq (get org-type org) (get implementer ORG_TYPES)) 
             (get verified org))
    false))

(define-private (validate-string (input (string-utf8 50)))
  (> (len input) u0))

(define-private (validate-short-string (input (string-utf8 30)))
  (> (len input) u0))

(define-private (validate-principal (input principal))
  (not (is-eq input ZERO_PRINCIPAL)))

;; Public functions
(define-public (register-organization (org-type uint) (name (string-utf8 50)))
  (begin
    (asserts! (and (>= org-type (get donor ORG_TYPES)) 
                  (<= org-type (get auditor ORG_TYPES))) 
              ERR_UNAUTHORIZED)
    (asserts! (validate-string name) ERR_INVALID_INPUT)
    (let ((validated-name name))
      (map-set organizations tx-sender {
        org-type: org-type,
        verified: false,
        name: validated-name
      })
      (ok true))))

(define-public (create-campaign (name (string-utf8 50)) (target uint) (region (string-utf8 50)))
  (begin
    (asserts! (is-verified-implementer) ERR_UNAUTHORIZED)
    (asserts! (validate-string name) ERR_INVALID_INPUT)
    (asserts! (> target u0) ERR_INVALID_INPUT)
    (asserts! (validate-string region) ERR_INVALID_INPUT)
    (let ((id (+ (var-get campaign-counter) u1))
          (validated-name name)
          (validated-target target)
          (validated-region region))
      (var-set campaign-counter id)
      (map-set campaigns id {
        name: validated-name,
        implementer: tx-sender,
        target: validated-target,
        raised: u0,
        distributed: u0,
        status: (get active CAMPAIGN_STATUS),
        region: validated-region
      })
      (ok id))))

(define-public (donate (campaign-id uint) (amount uint))
  (let ((campaign (unwrap! (get-campaign campaign-id) ERR_NOT_FOUND)))
    (asserts! (is-eq (get status campaign) (get active CAMPAIGN_STATUS)) ERR_INVALID_STATE)
    (asserts! (> amount u0) ERR_INVALID_STATE)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set campaigns campaign-id (merge campaign {
      raised: (+ (get raised campaign) amount)
    }))
    (ok true)))

(define-public (manage-beneficiary 
                (campaign-id uint)
                (beneficiary-id (string-utf8 30))
                (name (string-utf8 50))
                (amount uint))
  (let ((campaign (unwrap! (get-campaign campaign-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get implementer campaign)) ERR_UNAUTHORIZED)
    (asserts! (validate-short-string beneficiary-id) ERR_INVALID_INPUT)
    (asserts! (validate-string name) ERR_INVALID_INPUT)
    (asserts! (> amount u0) ERR_INVALID_INPUT)
    (asserts! (<= amount (- (get raised campaign) (get distributed campaign))) ERR_INSUFFICIENT_FUNDS)
    (let ((validated-beneficiary-id beneficiary-id)
          (validated-name name))
      (map-set beneficiaries {campaign-id: campaign-id, beneficiary-id: validated-beneficiary-id} {
        name: validated-name,
        allocated: amount,
        received: u0
      })
      (ok true))))

(define-public (distribute-aid 
                (campaign-id uint)
                (beneficiary-id (string-utf8 30))
                (amount uint))
  (let ((campaign (unwrap! (get-campaign campaign-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get implementer campaign)) ERR_UNAUTHORIZED)
    (asserts! (validate-short-string beneficiary-id) ERR_INVALID_INPUT)
    (asserts! (> amount u0) ERR_INVALID_INPUT)
    (asserts! (is-eq (get status campaign) (get active CAMPAIGN_STATUS)) ERR_INVALID_STATE)
    (let ((validated-beneficiary-id beneficiary-id)
          (beneficiary (unwrap! (get-beneficiary campaign-id validated-beneficiary-id) ERR_NOT_FOUND)))
      (asserts! (<= amount (- (get allocated beneficiary) (get received beneficiary))) ERR_INSUFFICIENT_FUNDS)
      
      ;; Update records atomically
      (map-set beneficiaries {campaign-id: campaign-id, beneficiary-id: validated-beneficiary-id}
        (merge beneficiary {received: (+ (get received beneficiary) amount)}))
      (map-set campaigns campaign-id
        (merge campaign {distributed: (+ (get distributed campaign) amount)}))
      (ok true))))

(define-public (complete-campaign (campaign-id uint))
  (let ((campaign (unwrap! (get-campaign campaign-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get implementer campaign)) ERR_UNAUTHORIZED)
    (map-set campaigns campaign-id
      (merge campaign {status: (get completed CAMPAIGN_STATUS)}))
    (ok true)))

;; Admin functions
(define-public (verify-organization (org principal))
  (begin
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (asserts! (validate-principal org) ERR_INVALID_INPUT)
    (let ((validated-org org))
      (match (get-organization validated-org)
        org-data (begin
                   (map-set organizations validated-org (merge org-data {verified: true}))
                   (ok true))
        ERR_NOT_FOUND))))

(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (asserts! (validate-principal new-admin) ERR_INVALID_INPUT)
    (let ((validated-new-admin new-admin))
      (var-set admin validated-new-admin)
      (ok true))))