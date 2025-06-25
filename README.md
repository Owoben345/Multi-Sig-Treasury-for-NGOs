# 🏛️ Multi-Sig Treasury for NGOs (Donoflow)

A decentralized multi-signature treasury system built on Stacks blockchain that enables NGOs to manage donations with transparent donor approval mechanisms.

## 🌟 Features

- 💰 **Donor Management**: Add and manage authorized donors
- 🎯 **Proposal System**: Create spending proposals with detailed descriptions
- 🗳️ **Weighted Voting**: Voting power based on donation amounts
- ⏰ **Time-bound Proposals**: Automatic expiration after 1440 blocks (~10 days)
- 🔒 **Multi-sig Security**: Configurable approval thresholds
- 📊 **Transparent Treasury**: Real-time balance and transaction tracking

## 🚀 Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet for testing

### Installation

```bash
git clone <repository-url>
cd Multi-Sig-Treasury-for-NGOs
clarinet console
```

## 📖 Usage Guide

### 1. 👥 Adding Donors

Only the contract owner can add authorized donors:

```clarity
(contract-call? .multi-sig add-donor 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

### 2. 💸 Making Donations

⚠️ **Important**: The donate function transfers the donor's **entire STX balance** to the treasury:

```clarity
(contract-call? .multi-sig donate)
```

### 3. 📝 Creating Proposals

Donors can create spending proposals:

```clarity
(contract-call? .multi-sig create-proposal 
  "Medical Supplies" 
  "Purchase emergency medical supplies for rural clinic" 
  u1000000 
  'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG)
```

### 4. 🗳️ Voting on Proposals

Donors vote with power proportional to their donations:

```clarity
(contract-call? .multi-sig vote-on-proposal u1 true)
```

### 5. ✅ Executing Approved Proposals

Anyone can execute proposals that meet approval threshold:

```clarity
(contract-call? .multi-sig execute-proposal u1)
```

## 🔍 Read-Only Functions

### Get Proposal Details
```clarity
(contract-call? .multi-sig get-proposal u1)
```

### Check Treasury Balance
```clarity
(contract-call? .multi-sig get-treasury-balance)
```

### Get Total Treasury Amount
```clarity
(contract-call? .multi-sig get-total-treasury)
```

### Get Donor Information
```clarity
(contract-call? .multi-sig get-donor-info 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

### Get Vote Details
```clarity
(contract-call? .multi-sig get-vote u1 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

### Check Proposal Status
```clarity
(contract-call? .multi-sig get-proposal-status u1)
```

### Check if Proposal is Approved
```clarity
(contract-call? .multi-sig is-proposal-approved u1)
```

### Get Contract Information
```clarity
(contract-call? .multi-sig get-contract-owner)
(contract-call? .multi-sig get-proposal-counter)
(contract-call? .multi-sig get-donor-count)
(contract-call? .multi-sig get-min-approval-percentage)
```

## ⚙️ Configuration

### Set Minimum Approval Percentage
```clarity
(contract-call? .multi-sig set-min-approval-percentage u70)
```

### Deactivate Donor
```clarity
(contract-call? .multi-sig deactivate-donor 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

## 🧪 Testing

Run the test suite:

```bash
clarinet test
```

## 🏗️ Architecture

- **Donors**: Authorized contributors with voting rights
- **Proposals**: Spending requests with metadata and voting tracking
- **Voting Power**: Weighted by donation amount
- **Approval Threshold**: Configurable percentage (default: 60%)
- **Time Limits**: 1440 blocks (~10 days) for voting
- **Donor Limit**: Maximum 10 donors (hardcoded in voting power calculation)

## 🔐 Security Features

- ✅ Owner-only donor management
- ✅ Donor-only proposal creation and voting
- ✅ Duplicate vote prevention
- ✅ Proposal expiration handling
- ✅ Balance validation before execution
- ✅ Approval threshold enforcement
- ✅ Active donor validation
- ✅ Principal format validation for recipients

## 📊 Error Codes

| Code | Description |
|------|-------------|
| u100 | Not authorized |
| u101 | Invalid proposal |
| u102 | Proposal not found |
| u103 | Already voted |
| u104 | Proposal expired |
| u105 | Proposal not approved |
| u106 | Insufficient funds |
| u107 | Invalid amount |
| u108 | Donor already exists |
| u109 | Donor not found |
| u110 | Invalid state |

## ⚠️ Important Notes

- **Donation Mechanism**: The `donate` function transfers the caller's entire STX balance
- **Voting Power**: Based on cumulative donation amounts
- **Proposal Expiration**: Automatically expires after 1440 blocks
- **Donor Limit**: System supports maximum 10 donors due to fold implementation
- **Block Height**: Uses `stacks-block-height` for timing mechanisms

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with [Clarinet](https://github.com/hirosystems/clarinet)
- Powered by [Stacks Blockchain](https://www.stacks.co/)
- Inspired by the need for transparent NGO treasury management

## 📞 Support

For questions and support, please open an issue on GitHub or contact the development team.

---

**Donoflow** - Empowering NGOs with transparent, decentralized treasury management 🌍

