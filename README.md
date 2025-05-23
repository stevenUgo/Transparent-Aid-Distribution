# Transparent Aid Distribution

A Clarity smart contract for transparent humanitarian aid distribution that ensures resources reach intended recipients through auditable, blockchain-based tracking.

## Overview

This smart contract implements a transparent aid distribution system that allows:

- Donors to contribute funds to specific campaigns
- Implementing organizations to manage aid distribution
- Auditors to verify aid delivery
- Beneficiaries to be registered and tracked
- Complete transparency in the flow of resources

## Features

- Organization registration and verification
- Campaign creation and management
- Transparent donation tracking
- Beneficiary registration and allocation
- Distribution recording and verification
- Complete audit trail of all transactions

## Technical Details

The contract uses:
- Role-based access control for different organization types
- Campaign lifecycle management
- Beneficiary registration and tracking
- Distribution verification by independent auditors
- Comprehensive transaction history

## Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) for local development and testing
- [Stacks Wallet](https://www.hiro.so/wallet) for deploying to testnet/mainnet

### Deployment

1. Clone this repository
2. Use Clarinet to test and deploy the contract:

\`\`\`bash
clarinet console
\`\`\`

3. Interact with the contract using the provided functions

## Usage

1. Register as an organization using `register-organization`
2. Create aid campaigns using `create-campaign`
3. Donors contribute using `donate-to-campaign`
4. Register beneficiaries using `register-beneficiary`
5. Record distributions using `record-distribution`
6. Auditors verify distributions using `verify-distribution`

## License

This project is licensed under the MIT License - see the LICENSE file for details.
\`\`\`
