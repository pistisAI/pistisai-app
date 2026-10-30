# Pistisai Docker Scripts

AUR Docker build scripts are not in the tree.

## 🔄 Current Docker Usage

This directory currently contains:

- **validate_dev_environment.sh** - Development environment validation script

## 📁 Directory Structure

```
scripts/docker/
├── README.md                    # This documentation
└── validate_dev_environment.sh # Development environment validation
```

## 🔧 Available Scripts

### Development Environment Validation

**`validate_dev_environment.sh`** - Validates development environment setup:

```bash
# Validate development environment
./scripts/docker/validate_dev_environment.sh

# Check Docker installation and configuration
./scripts/docker/validate_dev_environment.sh --docker-check

# Validate Flutter development setup
./scripts/docker/validate_dev_environment.sh --flutter-check
```

## 🔗 Related Documentation

- [Deployment Workflow](../deploy/README.md) - Current deployment processes
- [Package Building](../packaging/README.md) - Available package formats
- [Version Management](../version_manager.sh) - Version management tools
