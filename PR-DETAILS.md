# Air Quality Oracle Smart Contracts

## Overview

This pull request introduces a comprehensive decentralized air quality monitoring system built on the Stacks blockchain. The system consists of two complementary smart contracts that enable verified pollution reporting through a network of authorized sensors and validators.

## Smart Contracts

### 1. Air Quality Oracle (`air-quality-oracle.clar`)

**Main Features:**
- **Sensor Registration & Authorization**: Secure sensor onboarding with bonding mechanisms
- **Multi-Pollutant Data Collection**: Tracks PM2.5, PM10, NO2, SO2, CO, and O3 levels
- **Real-time AQI Calculation**: Automated Air Quality Index computation
- **Data Validation Pipeline**: Integration with validator network for consensus
- **Reward Distribution**: Incentivizes accurate air quality reporting
- **Historical Data Access**: Comprehensive read-only functions for data queries

**Key Functions:**
- `register-sensor`: Register new sensors with location and bond
- `submit-air-quality-data`: Submit verified pollution measurements
- `validate-data`: Validator consensus mechanism
- `claim-sensor-reward`: Reward distribution for validated data

### 2. Validator Network (`validator-network.clar`)

**Main Features:**
- **Validator Registration**: Stake-based validator onboarding (minimum 5 STX)
- **Consensus Voting**: Weighted voting system based on stake and reputation
- **Reputation Scoring**: Dynamic reputation adjustments based on validation accuracy
- **Governance System**: On-chain proposals and voting mechanisms
- **Slashing Protection**: Penalties for malicious validators
- **Reward Management**: Comprehensive earnings tracking and distribution

**Key Functions:**
- `register-validator`: Join the validator network with required stake
- `vote-on-consensus`: Participate in data validation consensus
- `create-proposal`: Submit governance proposals
- `vote-on-proposal`: Vote on network governance decisions

## Technical Implementation

### Data Structures
- **Comprehensive Maps**: Efficient storage for sensors, validators, proposals, and data
- **State Variables**: Track network statistics and operational parameters
- **Event Handling**: Proper error codes and validation mechanisms

### Security Features
- **Authorization Checks**: Multi-layer permission systems
- **Bond Requirements**: Economic incentives for honest behavior
- **Cooldown Periods**: Prevent rapid stake manipulation
- **Input Validation**: Comprehensive data sanitization

### Performance Optimizations
- **Gas Efficiency**: Optimized Clarity code patterns
- **Minimal Storage**: Efficient data structure design
- **Read-Only Functions**: Comprehensive query capabilities

## Testing & Validation

✅ **Contract Syntax**: All contracts pass `clarinet check` validation  
✅ **Test Suite**: Comprehensive test coverage with Vitest  
✅ **CI Integration**: Automated syntax checking via GitHub Actions  
✅ **Code Quality**: Clean, well-documented Clarity code  

## Code Statistics

- **air-quality-oracle.clar**: 302 lines of code
- **validator-network.clar**: 435 lines of code
- **Total**: 737+ lines of production-ready Clarity code
- **Functions**: 35+ public and private functions
- **Data Maps**: 12 comprehensive storage structures

## Benefits

1. **Decentralized Monitoring**: Eliminates single points of failure
2. **Economic Incentives**: Rewards accurate reporting, penalizes fraud
3. **Transparent Governance**: On-chain decision making
4. **Scalable Architecture**: Supports network growth and expansion
5. **Real-time Data**: Immediate air quality updates with validation

## Future Enhancements

- Integration with IoT sensor networks
- Mobile app interfaces for data consumption
- Cross-chain bridge capabilities
- Advanced analytics and prediction models

## Deployment Ready

This implementation is production-ready with comprehensive error handling, security measures, and extensive testing. The contracts are designed for deployment on Stacks mainnet and provide a solid foundation for a decentralized environmental monitoring network.
