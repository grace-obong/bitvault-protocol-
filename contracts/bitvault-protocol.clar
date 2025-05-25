;; Title: BitVault Protocol - Decentralized Bitcoin-Collateralized Stablecoin
;;
;; Summary:
;; A trustless, over-collateralized stablecoin protocol built on Stacks that enables
;; users to mint USD-pegged stablecoins against Bitcoin collateral while maintaining
;; decentralized governance and automated liquidation mechanisms.
;;
;; Description:
;; BitVault Protocol represents the next evolution of Bitcoin-native DeFi, leveraging
;; Stacks Layer 2 to create a robust stablecoin ecosystem. Users can deposit STX as
;; collateral to mint BitUSD, a stablecoin pegged to the US Dollar. The protocol
;; enforces over-collateralization requirements, implements dynamic liquidation
;; mechanisms, and features decentralized price oracles to maintain system stability.
;;
;; Key Features:
;; - Over-collateralized lending with configurable ratios
;; - Automated liquidation system with authorized liquidators
;; - Decentralized oracle network for price feeds
;; - Emergency shutdown mechanisms for system protection
;; - Governance controls for parameter adjustment
;; - Bitcoin-native architecture leveraging Stacks security
;;
;; Built for the Bitcoin ecosystem, secured by Stacks, powered by community governance.

;; CONSTANTS

(define-constant contract-owner tx-sender)

;; Error Constants
(define-constant err-owner-only (err u100))
(define-constant err-insufficient-collateral (err u101))
(define-constant err-below-mcr (err u102))
(define-constant err-already-initialized (err u103))
(define-constant err-not-initialized (err u104))
(define-constant err-low-balance (err u105))
(define-constant err-invalid-price (err u106))
(define-constant err-emergency-shutdown (err u107))
(define-constant err-invalid-parameter (err u108))

;; System Limits
(define-constant maximum-price u1000000000) ;; Maximum allowed price (sanity check)
(define-constant minimum-price u1) ;; Minimum allowed price
(define-constant maximum-ratio u1000) ;; Maximum collateral ratio (1000%)
(define-constant minimum-ratio u101) ;; Minimum collateral ratio (101%)
(define-constant maximum-fee u100) ;; Maximum stability fee (100%)

;; DATA VARIABLES

(define-data-var minimum-collateral-ratio uint u150) ;; 150% collateralization ratio
(define-data-var liquidation-ratio uint u120) ;; 120% liquidation threshold
(define-data-var stability-fee uint u2) ;; 2% annual stability fee
(define-data-var initialized bool false) ;; Protocol initialization status
(define-data-var emergency-shutdown bool false) ;; Emergency shutdown flag
(define-data-var last-price uint u0) ;; Latest BTC/USD price
(define-data-var price-valid bool false) ;; Price validity flag
(define-data-var governance-token principal 'SP000000000000000000002Q6VF78.governance-token)

;; DATA STORAGE

;; Vault Storage - User collateral and debt positions
(define-map vaults
  principal
  {
    collateral: uint, ;; Amount of STX collateral deposited
    debt: uint, ;; Amount of stablecoin debt
    last-fee-timestamp: uint, ;; Last stability fee calculation timestamp
  }
)

;; Authorization Maps
(define-map liquidators
  principal
  bool
)

;; Authorized liquidators
(define-map price-oracles
  principal
  bool
)

;; Authorized price oracles

;; VALIDATION FUNCTIONS

(define-private (is-valid-price (price uint))
  ;; Validates that a price is within acceptable bounds
  (and
    (>= price minimum-price)
    (<= price maximum-price)
  )
)

(define-private (is-valid-ratio (ratio uint))
  ;; Validates that a collateral ratio is within acceptable bounds
  (and
    (>= ratio minimum-ratio)
    (<= ratio maximum-ratio)
  )
)

(define-private (is-valid-fee (fee uint))
  ;; Validates that a stability fee is within acceptable bounds
  (<= fee maximum-fee)
)

;; CORE PROTOCOL FUNCTIONS

(define-public (initialize (btc-price uint))
  ;; Initialize the protocol with an initial BTC price
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (not (var-get initialized)) err-already-initialized)
    (asserts! (is-valid-price btc-price) err-invalid-parameter)
    (var-set last-price btc-price)
    (var-set price-valid true)
    (var-set initialized true)
    (ok true)
  )
)

(define-public (create-vault (collateral-amount uint))
  ;; Create or add to a collateral vault by depositing STX
  (let ((existing-vault (default-to {
      collateral: u0,
      debt: u0,
      last-fee-timestamp: stacks-block-height,
    }
      (map-get? vaults tx-sender)
    )))
    (begin
      (asserts! (var-get initialized) err-not-initialized)
      (asserts! (not (var-get emergency-shutdown)) err-emergency-shutdown)
      (try! (stx-transfer? collateral-amount tx-sender (as-contract tx-sender)))
      (map-set vaults tx-sender
        (merge existing-vault { collateral: (+ collateral-amount (get collateral existing-vault)) })
      )
      (ok true)
    )
  )
)

(define-public (mint-stablecoin (amount uint))
  ;; Mint stablecoins against deposited collateral
  (let (
      (vault (unwrap! (map-get? vaults tx-sender) err-low-balance))
      (current-collateral (get collateral vault))
      (current-debt (get debt vault))
      (new-debt (+ current-debt amount))
      (collateral-value (* current-collateral (var-get last-price)))
    )
    (begin
      (asserts! (var-get initialized) err-not-initialized)
      (asserts! (not (var-get emergency-shutdown)) err-emergency-shutdown)
      (asserts! (var-get price-valid) err-invalid-price)
      ;; Check if new debt maintains minimum collateral ratio
      (asserts!
        (>= (* collateral-value u100)
          (* new-debt (var-get minimum-collateral-ratio))
        )
        err-below-mcr
      )
      (map-set vaults tx-sender (merge vault { debt: new-debt }))
      (ok true)
    )
  )
)

(define-public (repay-debt (amount uint))
  ;; Repay stablecoin debt to reduce vault debt
  (let (
      (vault (unwrap! (map-get? vaults tx-sender) err-low-balance))
      (current-debt (get debt vault))
    )
    (begin
      (asserts! (var-get initialized) err-not-initialized)
      (asserts! (>= current-debt amount) err-low-balance)
      (map-set vaults tx-sender (merge vault { debt: (- current-debt amount) }))
      (ok true)
    )
  )
)

(define-public (withdraw-collateral (amount uint))
  ;; Withdraw collateral from vault while maintaining collateralization ratio
  (let (
      (vault (unwrap! (map-get? vaults tx-sender) err-low-balance))
      (current-collateral (get collateral vault))
      (current-debt (get debt vault))
      (new-collateral (- current-collateral amount))
      (collateral-value (* new-collateral (var-get last-price)))
    )
    (begin
      (asserts! (var-get initialized) err-not-initialized)
      (asserts! (not (var-get emergency-shutdown)) err-emergency-shutdown)
      (asserts! (var-get price-valid) err-invalid-price)
      (asserts! (>= current-collateral amount) err-low-balance)
      ;; Check if withdrawal maintains minimum collateral ratio
      (asserts!
        (or
          (is-eq current-debt u0)
          (>= (* collateral-value u100)
            (* current-debt (var-get minimum-collateral-ratio))
          )
        )
        err-below-mcr
      )
      (try! (as-contract (stx-transfer? amount (as-contract tx-sender) tx-sender)))
      (map-set vaults tx-sender (merge vault { collateral: new-collateral }))
      (ok true)
    )
  )
)

;; LIQUIDATION SYSTEM

(define-public (liquidate (vault-owner principal))
  ;; Liquidate an under-collateralized vault
  (let (
      (vault (unwrap! (map-get? vaults vault-owner) err-low-balance))
      (collateral (get collateral vault))
      (debt (get debt vault))
      (collateral-value (* collateral (var-get last-price)))
    )
    (begin
      ;; Basic checks
      (asserts! (var-get initialized) err-not-initialized)
      (asserts! (var-get price-valid) err-invalid-price)
      (asserts! (is-authorized-liquidator tx-sender) err-owner-only)
      ;; Ensure vault exists and has debt
      (asserts! (> debt u0) err-invalid-parameter)
      ;; Check if vault is below liquidation ratio
      (asserts!
        (< (* collateral-value u100) (* debt (var-get liquidation-ratio)))
        err-insufficient-collateral
      )
      ;; Save collateral locally to ensure consistency
      (let ((collateral-to-transfer collateral))
        ;; Clear vault first to prevent reentrancy
        (map-delete vaults vault-owner)
        ;; Transfer collateral to liquidator
        (try! (as-contract (stx-transfer? collateral-to-transfer (as-contract tx-sender) tx-sender)))
        (ok true)
      )
    )
  )
)

;; ORACLE SYSTEM

(define-public (update-price (new-price uint))
  ;; Update the BTC/USD price feed (authorized oracles only)
  (begin
    (asserts! (is-authorized-oracle tx-sender) err-owner-only)
    (asserts! (is-valid-price new-price) err-invalid-parameter)
    (var-set last-price new-price)
    (var-set price-valid true)
    (ok true)
  )
)

;; GOVERNANCE FUNCTIONS

(define-public (set-minimum-collateral-ratio (new-ratio uint))
  ;; Set the minimum collateral ratio (owner only)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-valid-ratio new-ratio) err-invalid-parameter)
    (asserts! (> new-ratio (var-get liquidation-ratio)) err-invalid-parameter)
    (var-set minimum-collateral-ratio new-ratio)
    (ok true)
  )
)

(define-public (set-liquidation-ratio (new-ratio uint))
  ;; Set the liquidation threshold ratio (owner only)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-valid-ratio new-ratio) err-invalid-parameter)
    (asserts! (< new-ratio (var-get minimum-collateral-ratio))
      err-invalid-parameter
    )
    (var-set liquidation-ratio new-ratio)
    (ok true)
  )
)

(define-public (set-stability-fee (new-fee uint))
  ;; Set the annual stability fee rate (owner only)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-valid-fee new-fee) err-invalid-parameter)
    (var-set stability-fee new-fee)
    (ok true)
  )
)

;; AUTHORIZATION MANAGEMENT

(define-public (add-liquidator (liquidator principal))
  ;; Add an authorized liquidator (owner only)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (not (is-authorized-liquidator liquidator)) err-invalid-parameter)
    (map-set liquidators liquidator true)
    (ok true)
  )
)

(define-public (remove-liquidator (liquidator principal))
  ;; Remove an authorized liquidator (owner only)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-authorized-liquidator liquidator) err-invalid-parameter)
    (map-delete liquidators liquidator)
    (ok true)
  )
)

(define-public (add-oracle (oracle principal))
  ;; Add an authorized price oracle (owner only)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (not (is-authorized-oracle oracle)) err-invalid-parameter)
    (map-set price-oracles oracle true)
    (ok true)
  )
)

(define-public (remove-oracle (oracle principal))
  ;; Remove an authorized price oracle (owner only)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-authorized-oracle oracle) err-invalid-parameter)
    (map-delete price-oracles oracle)
    (ok true)
  )
)

;; EMERGENCY CONTROLS

(define-public (trigger-emergency-shutdown)
  ;; Trigger emergency shutdown to halt all protocol operations (owner only)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set emergency-shutdown true)
    (ok true)
  )
)

;; READ-ONLY FUNCTIONS

(define-read-only (get-vault (owner principal))
  ;; Get vault information for a specific owner
  (map-get? vaults owner)
)

(define-read-only (get-collateral-ratio (owner principal))
  ;; Calculate and return the collateral ratio for a vault
  (let (
      (vault (unwrap! (map-get? vaults owner) err-low-balance))
      (collateral (get collateral vault))
      (debt (get debt vault))
    )
    (if (is-eq debt u0)
      (ok u0)
      (ok (/ (* collateral (var-get last-price)) debt))
    )
  )
)

(define-read-only (is-authorized-liquidator (address principal))
  ;; Check if an address is an authorized liquidator
  (default-to false (map-get? liquidators address))
)

(define-read-only (is-authorized-oracle (address principal))
  ;; Check if an address is an authorized price oracle
  (default-to false (map-get? price-oracles address))
)

(define-read-only (get-stability-parameters)
  ;; Get all current protocol stability parameters
  {
    minimum-collateral-ratio: (var-get minimum-collateral-ratio),
    liquidation-ratio: (var-get liquidation-ratio),
    stability-fee: (var-get stability-fee),
    price: (var-get last-price),
    price-valid: (var-get price-valid),
    emergency-shutdown: (var-get emergency-shutdown),
  }
)
