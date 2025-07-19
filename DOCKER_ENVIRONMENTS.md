# Dockerfiles and Environments - Finance Tracker

## Overview

The project uses **separate Dockerfiles** for each environment, ensuring specific optimizations and maintenance simplicity.

## Structure

```
├── Dockerfile                 # Production (multi-stage, optimized)
├── Dockerfile.preprod         # Pre-production/development
├── docker-compose.yml         # Production
└── docker-compose.preprod.yml # Pre-production
```

## Files and Purposes

### Dockerfile (Production)
- **Base**: Ruby 3.4.2
- **Type**: Multi-stage build
- **Optimizations**: 
  - Pre-compiled assets
  - Production gems only
  - Non-root user
  - Slim image in final stage
- **Usage**: `docker build -f Dockerfile .`

### Dockerfile.preprod (Pre-production/Development)
- **Base**: Ruby 3.4.2
- **Type**: Single-stage build
- **Features**:
  - All gems (dev, test, production)
  - Runtime asset compilation
  - Root user for development ease
  - Complete debugging tools
- **Usage**: `docker build -f Dockerfile.preprod .`

## Useful Commands

### Production
```bash
# Build
docker build -t finance-tracker:prod .

# Run with docker-compose
docker-compose up -d

# Automated deploy
./deploy.sh
```

### Pre-production
```bash
# Build
docker-compose -f docker-compose.preprod.yml build

# Run complete environment
./run-pre-prod.sh

# Utility commands
./preprod-utils.sh help
```

## Main Differences

| Aspect | Production | Pre-production |
|---------|----------|--------------|
| **Ruby Version** | 3.4.2 | 3.4.2 |
| **Build Type** | Multi-stage | Single-stage |
| **Bundle Config** | `--deployment --without dev test` | All gems |
| **Assets** | Pre-compiled | Runtime |
| **User** | rails (non-root) | root |
| **Image Size** | ~300MB | ~800MB |
| **Security** | High | Development |
| **Debug Tools** | Minimal | Complete |

## Approach Advantages

### ✅ Separate Dockerfiles
1. **Simplicity**: Each file has a clear purpose
2. **Maintainability**: Easy to understand and modify
3. **Optimization**: Each environment optimized for its use
4. **Debugging**: Problems isolated by environment
5. **Flexibility**: Independent changes

### ❌ Single Dockerfile (discarded)
- Complexity with conditional ARGs
- Debugging difficulty
- Maintenance overhead
- Purpose confusion

## Troubleshooting

### Ruby Version Mismatch
```bash
# Error: "Your Ruby version is X.X.X, but your Gemfile specified Y.Y.Y"
# Solution: Check if FROM ruby:X.Y.Z is consistent in Dockerfile
```

### Build Context Too Large
```bash
# Use .dockerignore to exclude unnecessary files
# Check if logs, node_modules, etc. are being ignored
```

### Bundle Install Fails
```bash
# Check if system versions (Node.js, build tools) are compatible
# For development: don't use --deployment flag
```

## Single Environment Migration

Before this change, there was only one `Dockerfile` that tried to serve all environments. This caused:

1. **Incompatibilities** between prod and preprod
2. **Slow builds** for development
3. **Large images** for production
4. **Complexity** with conditionals

The separation resolves all these issues while keeping each environment optimized for its specific purpose.
