# Airbit - Air Quality Oracle Contract

A decentralized air quality monitoring system built on the Stacks blockchain using Clarity smart contracts. Airbit enables verified pollution reporting through a network of authorized sensors and validators.

## Overview

The Airbit system consists of two main smart contracts:

### 1. Air Quality Oracle (`air-quality-oracle.clar`)
- **Core Functions**: Manages air quality data collection, sensor registration, and data validation
- **Features**: 
  - Sensor authorization and management
  - Air quality data submission with multiple pollutant tracking
  - Data validation and consensus mechanisms
  - Historical data querying
  - Reward distribution for accurate reporting

### 2. Validator Network (`validator-network.clar`)
- **Core Functions**: Handles validator registration, consensus voting, and data verification
- **Features**:
  - Validator registration and staking
  - Consensus voting on air quality submissions
  - Reputation scoring system
  - Slashing mechanisms for malicious actors
  - Validator reward distribution

## Key Features

- **Decentralized Data Collection**: Multiple authorized sensors contribute air quality measurements
- **Consensus-Based Validation**: Validator network ensures data accuracy through voting mechanisms
- **Multi-Pollutant Tracking**: Monitors PM2.5, PM10, NO2, SO2, CO, and O3 levels
- **Incentive Alignment**: Rewards accurate reporting and penalizes false data
- **Historical Tracking**: Maintains comprehensive air quality records over time
- **Transparent Governance**: On-chain voting for system parameters and updates

## Contract Architecture

```
┌─────────────────────┐    ┌──────────────────────┐
│  Air Quality Oracle │    │  Validator Network   │
│                     │    │                      │
│  • Sensor Mgmt      │◄──►│  • Validator Mgmt    │
│  • Data Collection  │    │  • Consensus Voting  │
│  • Reward System    │    │  • Reputation System │
└─────────────────────┘    └──────────────────────┘
```

## Data Structure

Air quality measurements include:
- Location coordinates (latitude/longitude)
- Timestamp of measurement
- Pollutant concentrations (μg/m³)
- Air Quality Index (AQI) calculation
- Sensor metadata and calibration data

## Getting Started

### Prerequisites
- Clarinet CLI installed
- Stacks wallet for testing
- Node.js for running tests

### Installation
```bash
git clone [repository-url]
cd airbit
npm install
```

### Testing
```bash
clarinet test
```

### Deployment
```bash
clarinet deploy --testnet
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests to ensure everything passes
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contact

For questions or support, please open an issue on GitHub or contact the development team.
