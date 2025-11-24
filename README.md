# Orbit Guard Wallet

A Clarity smart contract implementing a **multi-signature rotating custody wallet** on Stacks blockchain.

## Overview

Orbit Guard Wallet provides secure STX fund management through rotating custodian roles. Only the active custodian can authorize transfers, with automatic rotation based on configurable time periods.

## Features

- **Rotating Custodian Model**: Active custodian changes periodically for enhanced security
- **Admin Controls**: Add/remove custodians and configure rotation periods
- **Authorization Checks**: Only active custodian can execute transfers
- **Event Logging**: Full audit trail via print statements
- **Error Handling**: Comprehensive validation and error codes

## Core Functions

| Function | Role | Description |
|----------|------|-------------|
| `add-custodian` | Admin | Register new custodian |
| `remove-custodian` | Admin | Deactivate custodian by ID |
| `set-rotation-period` | Admin | Configure rotation interval (blocks) |
| `transfer-stx` | Custodian | Execute STX transfer (active only) |
| `get-rotation-info` | Public | Query current custody state |
| `get-custodians` | Public | Get active custodian count |

## Configuration

- **Default Rotation Period**: 1440 blocks (~10 hours at 25s block time)
- **Admin**: Contract deployer (tx-sender)

## Error Codes

- `u100`: Not authorized
- `u101`: No custodians available
- `u102`: Invalid amount
- `u103`: Invalid recipient
- `u104`: Admin only

## Usage Example

```clarity
;; Add custodian
(contract-call? .orbit-guard-wallet add-custodian 'SP1234...)

;; Transfer funds (as active custodian)
(contract-call? .orbit-guard-wallet transfer-stx 'SPRECIPIENT... u1000000)

;; Check rotation info
(contract-call? .orbit-guard-wallet get-rotation-info)
