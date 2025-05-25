# BitVault Protocol

**A Decentralized Bitcoin-Collateralized Stablecoin Protocol Built on Stacks**

---

## 🛠 Summary

**BitVault Protocol** is a trustless, over-collateralized stablecoin system built on the Stacks blockchain. It allows users to mint **BitUSD**, a USD-pegged stablecoin, by locking **STX** tokens as collateral. The protocol is designed with security, decentralization, and economic soundness at its core, utilizing a system of decentralized price oracles, automated liquidations, and community-driven governance.

---

## 🌐 Architecture Overview

```text
+----------------------------+
|    Bitcoin Layer (BTC)    |
+----------------------------+
             ||
             || Anchored via Stacks L1
             \/
+----------------------------+
|     Stacks Blockchain      |
+----------------------------+
        ||         ||
        ||         || Smart Contract Layer (Clarity)
        ||         || 
        \/         \/
+----------------------------+     +--------------------------+
|  Vault & Debt Management  |<--->|     Governance Module     |
+----------------------------+     +--------------------------+
        ||
        || Depends on price feeds
        \/
+----------------------------+
|    Oracle Aggregation      |
+----------------------------+
        ||
        \/     
+----------------------------+
| Liquidation Engine         |
+----------------------------+
        ||
        \/     
+----------------------------+
| Emergency Controls Module  |
+----------------------------+

```

---

## 📦 Features

* **💰 Over-Collateralized Vaults**
  Lock STX tokens to mint BitUSD with configurable minimum collateral ratios.

* **🌀 Stability Mechanism**
  Apply an annualized stability fee to maintain the peg and incentivize system integrity.

* **📉 Automated Liquidations**
  Under-collateralized positions are liquidated by authorized actors based on real-time price feeds.

* **📡 Decentralized Oracle Network**
  Authorized oracles update BTC/USD price to ensure accurate and reliable valuation.

* **🛡 Emergency Shutdown**
  System-wide halt function to mitigate critical threats or bugs.

* **🗳 Community Governance**
  Adjust core parameters such as collateral ratio, stability fee, and oracle management.

---

## ⚙️ Core Contracts

All contracts are written in **Clarity**, the smart contract language for the Stacks blockchain.

| Module        | Purpose                                                       |
| ------------- | ------------------------------------------------------------- |
| `vaults`      | User vaults that hold collateral and track debt.              |
| `oracle`      | Maintains BTC/USD price feed from authorized sources.         |
| `governance`  | Manages protocol parameters and access control.               |
| `liquidation` | Handles forced vault liquidations below collateral threshold. |

---

## 🚀 Getting Started

### Prerequisites

* Node.js and Clarinet for local development
* STX tokens for collateral and transaction fees
* Clarity-compatible wallet (e.g., Hiro Wallet)

### 1. Clone the Repository

```bash
git clone https://github.com/grace-obong/bitvault-protocol-.git
cd bitvault-protocol
```

### 2. Run Locally with Clarinet

```bash
clarinet check
clarinet test
```

### 3. Deploy to Stacks Testnet

Update `Clarinet.toml` with deployment keys, then:

```bash
clarinet deploy
```

---

## 🔐 Key Functions

### Vault Lifecycle

* `create-vault(uint collateral)` — Deposit STX to initialize vault
* `mint-stablecoin(uint amount)` — Mint BitUSD against collateral
* `repay-debt(uint amount)` — Burn BitUSD to reduce debt
* `withdraw-collateral(uint amount)` — Withdraw STX if above MCR

### Oracle Management

* `add-oracle(principal)` / `remove-oracle(principal)`
* `update-price(uint newPrice)`

### Governance

* `set-minimum-collateral-ratio(uint ratio)`
* `set-liquidation-ratio(uint ratio)`
* `set-stability-fee(uint fee)`

### Emergency

* `trigger-emergency-shutdown()`

---

## 📈 Economic Parameters (Defaults)

| Parameter                | Value             | Description                |
| ------------------------ | ----------------- | -------------------------- |
| Minimum Collateral Ratio | 150%              | Safe threshold for minting |
| Liquidation Ratio        | 120%              | Liquidation trigger point  |
| Stability Fee            | 2% annually       | Debt maintenance cost      |
| Oracle Price Bounds      | 1 - 1,000,000,000 | Sanity-checked price feed  |

---

## 📜 Security & Audit

This protocol is under active development. Formal verification and third-party audits are **strongly recommended** before mainnet deployment.

---

## 🤝 Contributing

1. Fork the repo
2. Create your feature branch
3. Push changes and open a PR
4. Ensure all tests pass
