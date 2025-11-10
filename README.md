# 🔒 Tokenized Hardware Warranty Ledger

A Clarity smart contract for managing hardware warranties as transferable NFTs on the Stacks blockchain.

## 🚀 Features

- **🎫 NFT Warranties**: Each warranty is represented as a unique NFT token
- **📦 Warranty Issuance**: Manufacturers can issue warranties at purchase
- **🔄 Transferable**: Warranty ownership can be transferred between users
- **⏰ Auto-Expiry**: Warranties automatically expire based on block height
- **📋 Batch Operations**: Issue multiple warranties in a single transaction
- **📊 History Tracking**: Complete transfer history for each warranty
- **🛡️ Claim System**: Warranty holders can claim warranties when needed

## 💼 Usage

### Issue a Warranty
```clarity
(contract-call? .warranty-ledger issue-warranty "SN123456" "iPhone 15 Pro" u52560 'SP1HTBVD3STAJ6WCXN4...)
```

### Transfer a Warranty
```clarity
(contract-call? .warranty-ledger transfer-warranty u1 'SP2HTBVD3STAJ6WCXN4...)
```

### Check Warranty Status
```clarity
(contract-call? .warranty-ledger get-warranty u1)
(contract-call? .warranty-ledger is-warranty-expired u1)
```

### Claim a Warranty
```clarity
(contract-call? .warranty-ledger claim-warranty u1 "Screen damage")
```

## 🏗️ Contract Structure

### Data Storage
- **warranties**: Maps warranty IDs to warranty details
- **warranty-history**: Tracks all transfers for each warranty
- **warranty-token**: NFT representing warranty ownership

### Key Functions
- `issue-warranty`: Create new warranty NFT
- `transfer-warranty`: Transfer warranty ownership
- `claim-warranty`: Use warranty for repair/replacement
- `extend-warranty`: Manufacturer extends warranty duration
- `deactivate-warranty`: Manufacturer deactivates warranty

## 🔧 Development

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet)
- Node.js and npm

### Setup
```bash
clarinet console
```

### Testing
```bash
clarinet test
```

### Deploy
```bash
clarinet integrate
```

## 📋 Data Structure

Each warranty contains:
- **manufacturer**: Principal who issued the warranty
- **product-serial**: Unique product serial number
- **product-model**: Product model identifier
- **purchase-date**: Block height when warranty was issued
- **warranty-duration**: Duration in blocks
- **owner**: Current warranty holder
- **is-active**: Whether warranty can be used
- **transfer-count**: Number of times warranty was transferred

## 🔐 Security Features

- Only manufacturers can issue warranties
- Only warranty owners can transfer or claim
- Automatic expiry based on block height
- Transfer history is immutable
- Owner-only access controls

## 📈 Block Height Calculations

Warranty duration is measured in Stacks blocks:
- 1 year ≈ 52,560 blocks (assuming 10-minute blocks)
- 2 years ≈ 105,120 blocks
- 3 years ≈ 157,680 blocks

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request
