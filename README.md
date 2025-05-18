# SupplyTrack

A decentralized supply chain tracking and verification platform that enables transparent product tracking from manufacturer to consumer.

## Overview

SupplyTrack is a Clarity smart contract that enables transparent supply chain management on the Stacks blockchain. It allows manufacturers to create product batches and participants to verify transfers, creating an immutable record of a product's journey through the supply chain.

## Features

- **Certification-Based Verification**: Participants verify transfers based on their certifications
- **Reputation System**: Participants earn reputation for verifying transfers
- **No Intermediaries**: Manufacturers connect directly with supply chain participants
- **Transparent Fee Structure**: Small network fee to sustain the ecosystem
- **Batch Management**: Manufacturers can create, recall, and manage product batches

## Contract Functions

### Participant Functions

- `register-participant`: Register as a new supply chain participant with certifications
- `update-certifications`: Update your product type certifications
- `deactivate-participant`: Temporarily deactivate your participation
- `reactivate-participant`: Re-enable participation after deactivation
- `verify-transfer`: Verify a product batch transfer and earn reputation
- `claim-reputation`: Withdraw your earned STX tokens

### Manufacturer Functions

- `create-product-batch`: Create a new product batch
- `recall-batch`: Temporarily recall an active batch
- `reactivate-batch`: Reactivate a recalled batch
- `add-batch-quantity`: Add more quantity to an existing batch

### Admin Functions

- `set-contract-owner`: Update the contract administrator
- `set-network-fee`: Adjust the network fee percentage
- `add-product-type`: Add a new product type
- `withdraw-network-fees`: Withdraw accumulated network fees

### Read-Only Functions

- `get-participant-profile`: View a participant's profile and certifications
- `get-batch`: Get details about a product batch
- `get-product-type`: Get information about a product type
- `get-network-fee`: Check the current network fee percentage
- `get-network-balance`: View the accumulated network fees
- `get-transfer-record`: Check if a participant has verified a specific batch

## How It Works

1. **For Manufacturers**:
   - Create product batches with quantity and quality scores
   - Manage batches with recall/reactivate functionality
   - Track transfers throughout the supply chain

2. **For Supply Chain Participants**:
   - Register with your product type certifications
   - Verify transfers of batches that match your certifications
   - Earn reputation for each verification
   - Claim your reputation as STX tokens anytime

## Transparency Features

- Participants only verify transfers for product types they're certified in
- All transfers are recorded on-chain for complete traceability
- Participants can opt-out at any time
- All interactions are pseudonymous via blockchain addresses

## Development

This contract is developed using Clarity and can be tested with Clarinet.