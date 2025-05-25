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