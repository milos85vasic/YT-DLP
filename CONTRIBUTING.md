# Contributing to YT-DLP Container Project

Thank you for your interest in contributing! This document provides guidelines and instructions for contributing to this project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Coding Standards](#coding-standards)
- [Commit Messages](#commit-messages)
- [Pull Request Process](#pull-request-process)
- [Testing](#testing)
- [Documentation](#documentation)

## Code of Conduct

This project adheres to a code of conduct that we expect all contributors to follow:

- Be respectful and inclusive
- Welcome newcomers and help them learn
- Focus on constructive feedback
- Respect different viewpoints and experiences

## Getting Started

### Prerequisites

- Git
- Podman or Docker
- Bash 4.0+
- Basic understanding of containerization

### Fork and Clone

```bash
# Fork the repository on GitHub
# Then clone your fork
git clone https://github.com/YOUR_USERNAME/YT-DLP.git
cd YT-DLP

# Add upstream remote
git remote add upstream https://github.com/milos85vasic/YT-DLP.git
```

### Create a Branch

```bash
# Create a feature branch
git checkout -b feature/my-new-feature

# Or a bugfix branch
git checkout -b fix/issue-description
```

## Development Setup

1. **Copy environment file:**
   ```bash
   cp .env.example .env
   # Edit with your development settings
   ```

2. **Initialize the environment:**
   ```bash
   ./init
   ```

3. **Start services:**
   ```bash
   ./start
   ```

4. **Verify everything works:**
   ```bash
   ./status
   ./download --help
   ```

## Coding Standards

### Bash Scripts

All shell scripts must follow these conventions:

#### File Structure

```bash
#!/bin/bash
#
# Brief description of what this script does
# Supports both Podman and Docker
#

set -e

# Colors (always define these)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Container runtime detection (include in all scripts)
detect_container_runtime() {
    if command -v podman &> /dev/null; then
        echo "podman"
    elif command -v docker &> /dev/null; then
        echo "docker"
    else
        echo "none"
    fi
}

# Main script logic...
```

#### Style Guidelines

- **Indentation:** 4 spaces (no tabs)
- **Line length:** Maximum 120 characters
- **Shebang:** Always use `#!/bin/bash`
- **Strict mode:** Always use `set -e` at the start
- **Comments:** Use `#` with a space after, describe "why" not "what"
- **Functions:** Use `lowercase_with_underscores`
- **Variables:** 
  - Local variables: `lowercase`
  - Environment variables: `UPPERCASE`
  - Constants: `UPPERCASE`

#### Error Handling

```bash
# Check if command succeeded
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Operation failed${NC}"
    exit 1
fi

# Validate variables
if [ -z "$VARIABLE" ]; then
    echo -e "${RED}ERROR: VARIABLE is not set${NC}"
    exit 1
fi

# Check if file exists
if [ ! -f "$FILE" ]; then
    echo -e "${RED}ERROR: File not found: $FILE${NC}"
    exit 1
fi
```

#### Output Formatting

```bash
# Success messages
echo -e "${GREEN}✓ Operation completed successfully${NC}"

# Error messages
echo -e "${RED}✗ ERROR: Something went wrong${NC}"

# Warning messages
echo -e "${YELLOW}⚠ WARNING: This might cause issues${NC}"

# Info/section headers
echo -e "${BLUE}=== Section Name ===${NC}"

# Runtime information
echo -e "${CYAN}Container Runtime:${NC} $RUNTIME"
```

### Docker Compose

- **Profiles:** Use `vpn`, `no-vpn`, and `vpn-cli` profiles
- **Container names:** Always specify explicit `container_name`
- **Restart policy:** Use `unless-stopped`
- **Health checks:** Include for VPN containers
- **Network mode:** Use `service:openvpn-yt-dlp` for VPN routing

Example service definition:
```yaml
services:
  my-service:
    image: myimage:latest
    container_name: my-service
    profiles:
      - vpn
    restart: unless-stopped
    depends_on:
      openvpn-yt-dlp:
        condition: service_healthy
```

### Documentation

- Keep README.md up-to-date with new features
- Add examples for new commands
- Update this CONTRIBUTING.md if processes change
- Comment complex code sections

## Commit Messages

Follow conventional commit format:

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

### Examples

```
feat(vpn): add support for WireGuard protocol

fix(download): handle URLs with special characters

docs(readme): update VPN setup instructions

refactor(scripts): extract common functions to lib/
```

## Pull Request Process

1. **Update documentation** if needed
2. **Test your changes** thoroughly
3. **Ensure scripts are executable:**
   ```bash
   chmod +x your-script
   ```
4. **Update CHANGELOG.md** if applicable
5. **Submit PR** with clear description

### PR Checklist

- [ ] Code follows style guidelines
- [ ] Scripts have been tested with both Podman and Docker
- [ ] Documentation is updated
- [ ] Commit messages follow convention
- [ ] No secrets or credentials committed
- [ ] `.env.example` updated if new variables added

### Review Process

1. Maintainers will review within 48 hours
2. Address review comments
3. Once approved, maintainers will merge

## Testing

### Manual Testing

Test all changes manually:

```bash
# 1. Test with Podman
./init
./start
./status
./download 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'
./stop

# 2. Test with Docker (if available)
CONTAINER_RUNTIME=docker ./start
./status
./stop

# 3. Test VPN mode (if you have VPN config)
# Set USE_VPN=true in .env
./start
./check-vpn
./stop
```

### Script Validation

```bash
# Check bash syntax
bash -n ./scriptname

# Check for common issues
shellcheck ./scriptname
```

## Documentation

### README Updates

When adding features:
- Update relevant sections
- Add examples
- Update the quick start if needed
- Keep TOC updated

### Script Help

Add `--help` support to scripts:

```bash
case "$1" in
    --help|-h)
        echo "Usage: ./script [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --help    Show this help message"
        exit 0
        ;;
esac
```

## Questions?

- Open an issue for bugs
- Start a discussion for questions
- Contact maintainers if needed

## Recognition

Contributors will be acknowledged in:
- Release notes
- README.md contributors section
- Git history

Thank you for contributing!
