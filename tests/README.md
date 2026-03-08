# YT-DLP Test Suite

Comprehensive automated testing framework for the YT-DLP project.

## Overview

This test suite provides full coverage of all scenarios and combinations:

- **Unit Tests**: Individual function and component testing
- **Integration Tests**: Script workflow and interaction testing
- **Scenario Tests**: Combination testing (Podman/Docker × VPN/No-VPN)
- **Error Tests**: Edge cases and error condition testing

## Quick Start

```bash
# Run all tests (recommended - includes container lifecycle)
./tests/run-full-suite.sh

# Run with verbose output
./tests/run-full-suite.sh -v

# Run specific test categories
./tests/run-full-suite.sh -p unit      # Unit tests only
./tests/run-full-suite.sh -p scenario  # Scenario tests only

# Run basic test suite (without container lifecycle)
./tests/run-tests.sh

# Run specific test categories without container management
./tests/run-tests.sh -p unit          # Unit tests only
./tests/run-tests.sh -p integration   # Integration tests only
./tests/run-tests.sh -p scenario      # Scenario tests only
./tests/run-tests.sh -p error         # Error tests only

# Run with specific runtime
./tests/run-tests.sh -r podman        # Test with Podman only
./tests/run-tests.sh -r docker        # Test with Docker only

# Dry run (show what would be tested)
./tests/run-tests.sh -d

# List all available tests
./tests/run-tests.sh -l

# Run specific test
./tests/run-tests.sh test_init_no_vpn

# Cleanup test environment
./tests/run-tests.sh -c
```

## Test Categories

### Unit Tests (`test-unit.sh`)

Tests individual functions and components:

- Container runtime detection
- Compose command selection
- Color output formatting
- Environment variable handling
- Path validation
- File permissions
- VPN configuration parsing
- Docker Compose syntax
- Port configuration

### Integration Tests (`test-integration.sh`)

Tests script workflows and interactions:

- `init` script with various configurations
- `start` and `stop` scripts
- `download` helper functionality
- `update-images` script
- `cleanup` script
- `status` and `check-vpn` scripts
- `setup-auto-update` script

### Scenario Tests (`test-scenarios.sh`)

Tests combinations of configurations:

| Scenario | Description |
|----------|-------------|
| Podman + No VPN | Test with Podman runtime, VPN disabled |
| Podman + VPN | Test with Podman runtime, VPN enabled |
| Docker + No VPN | Test with Docker runtime, VPN disabled |
| Docker + VPN | Test with Docker runtime, VPN enabled |
| Batch Download | Test batch download workflow |
| Channel Download | Test channel subscription workflow |
| Complete Workflow | Full Init → Update → Start → Stop cycle |
| Profile Tests | VPN, no-VPN, and VPN-CLI profiles |
| Network Config | Container networking and dependencies |
| Volume Mounts | Directory and file mounting |

### Error Tests (`test-errors.sh`)

Tests error conditions and edge cases:

- Missing container runtime
- Missing or invalid .env file
- Missing required variables
- Invalid VPN configuration
- File permission issues
- Network connectivity problems
- Script syntax errors
- Port conflicts

## Test Structure

```
tests/
├── run-tests.sh          # Main test runner
├── test-unit.sh          # Unit tests
├── test-integration.sh   # Integration tests
├── test-scenarios.sh     # Scenario tests
├── test-errors.sh        # Error tests
├── config/               # Test configuration files
│   ├── .env.no-vpn       # No VPN test config
│   └── .env.with-vpn     # VPN test config
├── logs/                 # Test execution logs
└── results/              # Test results and reports
```

## Writing Tests

### Basic Test Structure

```bash
test_example() {
    # Test code here
    
    # Use assertions
    assert_true "[ condition ]" "Description"
    assert_false "[ condition ]" "Description"
    assert_file_exists "./file" "File should exist"
    assert_dir_exists "./dir" "Directory should exist"
    
    return 0  # Success
}
```

### Registering Tests

Add tests to the appropriate suite:

```bash
run_unit_tests() {
    run_test "test_my_new_test" test_my_new_test
}
```

### Skipping Tests

```bash
test_conditional() {
    if [ "$TEST_RUNTIME" = "none" ]; then
        skip_test "test_conditional" "No runtime available"
        return 0
    fi
    
    # Test code...
}
```

## Assertions

Available assertion functions:

- `assert_true "condition" "message"` - Assert condition is true
- `assert_false "condition" "message"` - Assert condition is false
- `assert_file_exists "path" "message"` - Assert file exists
- `assert_dir_exists "path" "message"` - Assert directory exists
- `assert_command_exists "cmd" "message"` - Assert command exists

## Configuration

Test configuration files are stored in `tests/config/`:

- `.env.no-vpn`: Standard configuration without VPN
- `.env.with-vpn`: Configuration with VPN enabled

## Logs and Results

- **Logs**: `tests/logs/*.log` - Individual test execution logs
- **Results**: `tests/results/` - Test reports and summaries

## CI/CD Integration

The test suite returns appropriate exit codes:

- `0` - All tests passed
- `1` - One or more tests failed

Example GitHub Actions workflow:

```yaml
name: Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Install Podman
        run: |
          sudo apt-get update
          sudo apt-get install -y podman podman-compose
      
      - name: Run Tests
        run: ./tests/run-tests.sh
```

## Best Practices

1. **Isolated Tests**: Each test should be independent
2. **Cleanup**: Always clean up test artifacts
3. **Descriptive Names**: Use clear test names
4. **Assertions**: Use assertions instead of raw conditionals
5. **Documentation**: Document complex test scenarios
6. **Error Messages**: Provide helpful error messages

## Troubleshooting

### Tests Fail with "No container runtime"

Install Podman or Docker:
```bash
# Podman (recommended)
sudo apt-get install podman podman-compose

# Docker
sudo apt-get install docker docker-compose
```

### Permission Denied Errors

Ensure scripts are executable:
```bash
chmod +x tests/run-tests.sh
```

### Test Logs Missing

Check that log directory exists:
```bash
mkdir -p tests/logs
```

## Contributing

When adding new features:

1. Add corresponding unit tests
2. Add integration tests if scripts are affected
3. Add scenario tests for new combinations
4. Add error tests for edge cases
5. Update this documentation

## See Also

- [Main README](../README.md)
- [Contributing Guide](../CONTRIBUTING.md)
- [Agent Guide](../AGENTS.md)
