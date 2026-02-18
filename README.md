# 🚗 Tokenized Parking Rights

A Clarity smart contract that enables drivers to mint short-term parking rights as NFTs, with the ability to trade them if they leave early.

## 🌟 Features

- 🎫 **Mint Parking NFTs**: Create tokenized parking rights for specific spots and durations
- 💱 **Trade Early Departures**: Sell your parking spot if you leave before your time expires  
- 🔄 **Transfer Rights**: Transfer parking rights to other users
- ⏰ **Time-Based Expiration**: Automatic expiration when parking time ends
- 💰 **Refund System**: Get partial refunds for unused parking time
- 📍 **Spot Management**: Register and track parking spot locations
- 💵 **Earnings Tracking**: Track and withdraw earnings from spot sales

## 🚀 Usage

### For Drivers

#### Mint a Parking Right
```clarity
(contract-call? .tokenized-parking-rights mint-parking-right u1 u24)
```
- `spot-id`: The parking spot ID (u1, u2, etc.)
- `duration`: Parking duration in blocks (u24 = ~4 hours)

#### Sell Your Spot Early
```clarity
(contract-call? .tokenized-parking-rights sell-parking-right u1 u500000)
```
- `token-id`: Your parking NFT ID
- `price`: Sale price in microSTX

#### Buy Someone's Spot
```clarity
(contract-call? .tokenized-parking-rights buy-parking-right u1 u600000)
```
- `token-id`: The parking NFT you want to buy
- `max-price`: Maximum price you're willing to pay

#### End Parking Early
```clarity
(contract-call? .tokenized-parking-rights end-parking-early u1)
```

#### Extend Your Parking
```clarity
(contract-call? .tokenized-parking-rights extend-parking u1 u12)
```
- `additional-duration`: Extra blocks to add

### For Administrators

#### Register New Parking Spots
```clarity
(contract-call? .tokenized-parking-rights register-spot "Downtown" "123 Main St" "40.7128,-74.0060")
```

#### Set Parking Rate
```clarity
(contract-call? .tokenized-parking-rights set-parking-rate u2000000)
```
Rate in microSTX per block

#### Emergency Release
```clarity
(contract-call? .tokenized-parking-rights emergency-release u1)
```

## 📖 Read-Only Functions

### Check Spot Availability
```clarity
(contract-call? .tokenized-parking-rights is-spot-available u1)
```

### Get Remaining Time
```clarity
(contract-call? .tokenized-parking-rights get-remaining-time u1)
```

### Calculate Parking Cost
```clarity
(contract-call? .tokenized-parking-rights calculate-parking-cost u24)
```

### Get Refund Amount
```clarity
(contract-call? .tokenized-parking-rights get-refund-amount u1)
```

### Check Your Earnings
```clarity
(contract-call? .tokenized-parking-rights get-user-earnings 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

## 💡 How It Works

1. **Spot Registration**: Administrators register parking spots with location data
2. **Minting Rights**: Drivers pay to mint parking NFTs for specific durations
3. **Active Parking**: NFT holders have exclusive rights to their spot until expiration
4. **Early Trading**: Drivers can sell their remaining time to other users
5. **Automatic Expiration**: Spots become available again when time expires

## ⚙️ Configuration

- **Parking Rate**: Default 1,000,000 microSTX per block (~$1 per 10 minutes)
- **Max Duration**: 144 blocks (approximately 24 hours)
- **Transferable**: All parking rights are transferable by default

## 🔧 Development

### Prerequisites
- Clarinet CLI installed
- Stacks wallet for testing

### Testing
```bash
clarinet check
clarinet test
```

### Deployment
```bash
clarinet deploy
```

## 📊 Contract Data

### Maps
- `parking-spots`: Maps spot IDs to parking session data
- `spot-locations`: Maps spot IDs to physical location information  
- `user-earnings`: Tracks user earnings from spot sales

### Constants
- Parking rate: 1,000,000 microSTX per block
- Maximum duration: 144 blocks
- Various error codes for different failure scenarios

## 🚨 Error Codes

| Code | Description |
|------|-------------|
| u100 | Not contract owner |
| u101 | Token/spot not found |
| u102 | Already exists |
| u103 | Unauthorized action |
| u104 | Parking right expired |
| u105 | Invalid duration |
| u106 | Spot already occupied |
| u107 | Insufficient payment |
| u108 | Transfer failed |

## 📝 License

This project is open source and available under the MIT License.
