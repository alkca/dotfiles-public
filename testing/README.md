# Chezmoi Dotfiles Testing

This directory contains a comprehensive testing framework for validating chezmoi dotfiles across different Linux distributions using Docker containers.

## 🎯 Overview

The testing framework validates that your chezmoi dotfiles work correctly on:

- **Ubuntu 24.04** (x86_64) with `apt` package manager
- **Arch Linux** (x86_64) with `pacman` package manager

Each test runs in an isolated Docker container to ensure clean, reproducible testing environments.

## 📁 Directory Structure

```text
testing/
├── .dockerignore             # Allowlist for the Docker build context
├── .gitignore                # Defense-in-depth for local credential files
├── README.md                 # This documentation
├── run-tests.sh             # Main test orchestration script
├── test-chezmoi.sh          # Core test script (runs inside containers)
├── ubuntu/
│   └── Dockerfile           # Ubuntu container definition
└── arch/
    └── Dockerfile           # Arch Linux container definition
```

## 🚀 Quick Start

### Prerequisites

- Docker installed and running
- Your dotfiles repository in the parent directory

### Basic Usage

```bash
# Run tests with default settings (lite install)
./testing/run-tests.sh

# Test full installation
./testing/run-tests.sh --install-type full

# Run tests in parallel
./testing/run-tests.sh --parallel

# Test GUI install and keep containers for debugging
./testing/run-tests.sh --install-type gui --no-cleanup

# Test a public remote repository
./testing/run-tests.sh --repo https://github.com/user/dotfiles.git
```

## 🔧 Test Configuration

### Install Types

The testing framework supports all three install types defined in your dotfiles:

- **`lite`** (default): Essential development tools
- **`full`**: Everything in lite plus additional development tools
- **`gui`**: Everything in full plus GUI applications

### Environment Variables

| Variable        | Default           | Description                                      |
| --------------- | ----------------- | ------------------------------------------------ |
| `INSTALL_TYPE`  | `lite`            | Install type to test                             |
| `DOTFILES_REPO` | Repository root   | Local directory or unauthenticated public URL    |
| `TEST_TIMEOUT`  | `300`             | Per-container chezmoi timeout in seconds         |
| `CLEANUP`       | `true`            | Whether to clean up containers after testing     |
| `PARALLEL`      | `false`           | Whether to run tests in parallel                 |

### Command Line Options

```bash
Usage: ./run-tests.sh [OPTIONS]

OPTIONS:
    -t, --install-type TYPE    Install type to test (lite, full, gui)
    -r, --repo SOURCE         Local directory or public HTTPS URL
        --timeout SECONDS     Per-container chezmoi timeout
    -p, --parallel            Run tests in parallel
    -n, --no-cleanup          Don't remove containers after testing
    -h, --help                Show help message
```

### Credential Safety

The test harness intentionally does not accept Git usernames, passwords, access
tokens, GPG private keys, or authenticated repository URLs.

For a private repository, authenticate and clone it on the host using your
normal credential manager, then pass the local checkout:

```bash
git clone git@github.com:user/private-dotfiles.git /safe/local/path
./testing/run-tests.sh --repo /safe/local/path
```

The checkout is mounted read-only. Docker builds use an allowlisted context
containing only the test runner and Dockerfiles, so dotfiles, `.git`, and local
credential files cannot become image layers.

## 🧪 What Gets Tested

### 1. Chezmoi Installation
- Verifies chezmoi is properly installed and accessible
- Checks version information

### 2. OS Detection
- Validates that the container OS is correctly detected
- Ensures OS-specific logic works properly

### 3. Chezmoi Initialization
- Tests `chezmoi init --apply --exclude scripts` with your dotfiles without
  running package installers
- Verifies source directory creation
- Handles interactive prompts automatically

### 4. Configuration Files
- Checks that expected config files are created:
  - `~/.config/chezmoi/chezmoi.toml`
  - `~/.bashrc`
- Reports on file creation success/failure

### 5. Chezmoi Commands
- Tests basic chezmoi operations:
  - `chezmoi status`
  - `chezmoi diff`
  - `chezmoi managed`

### 6. Package Installation
- Verifies OS package manager detection
- Checks for Homebrew installation (if time permits)
- Tests availability of expected packages

## 📊 Test Output

### Success Example

```text
==================================
TESTING ON ubuntu
==================================
[INFO] Starting chezmoi dotfiles test...
[INFO] Test environment: ubuntu on x86_64
[SUCCESS] chezmoi is installed: chezmoi version v2.40.0
[SUCCESS] OS detection successful: ubuntu
[INFO] Initializing chezmoi with dotfiles from /dotfiles
[SUCCESS] chezmoi source directory created
[SUCCESS] Configuration file exists: ~/.bashrc
[INFO] Configuration files: 1/2 created
[SUCCESS] chezmoi status command works
[SUCCESS] chezmoi is managing 15 files
[SUCCESS] All tests completed successfully!
```

### Test Report

Each test generates a detailed report including:

- System information (OS, architecture, kernel)
- Chezmoi version and configuration
- File system status
- Managed files count

## 🐛 Debugging

### Keep Containers for Inspection

```bash
# Don't cleanup containers after testing
./testing/run-tests.sh --no-cleanup

# Then inspect the container
docker ps -a
docker exec -it <container-name> /bin/bash
```

### Manual Container Testing

```bash
# From the repository root, build and run the Ubuntu container manually
docker build -f testing/ubuntu/Dockerfile -t chezmoi-test-ubuntu testing
docker run -it --rm \
  --mount "type=bind,src=$(pwd),dst=/dotfiles,readonly" \
  -e DOTFILES_REPO=/dotfiles \
  chezmoi-test-ubuntu /bin/bash

# Inside container, run tests manually
export DOTFILES_REPO=/dotfiles
export INSTALL_TYPE=lite
./test-chezmoi.sh
```

### Common Issues

**Docker not running:**
```bash
# Start Docker daemon
sudo systemctl start docker
```

**Permission denied:**
```bash
# Add user to docker group
sudo usermod -aG docker $USER
# Log out and back in
```

**Test timeouts:**
```bash
# Increase timeout for slow systems
export TEST_TIMEOUT=600  # 10 minutes
./testing/run-tests.sh
```

## 🔄 Continuous Integration

### GitHub Actions Example

```yaml
name: Test Dotfiles

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        install-type: [lite, full]

    steps:
    - uses: actions/checkout@v3

    - name: Test dotfiles
      run: |
        chmod +x testing/run-tests.sh
        ./testing/run-tests.sh --install-type ${{ matrix.install-type }}
```

### GitLab CI Example

```yaml
test-dotfiles:
  image: docker:latest
  services:
    - docker:dind
  script:
    - chmod +x testing/run-tests.sh
    - ./testing/run-tests.sh --parallel
  parallel:
    matrix:
      - INSTALL_TYPE: [lite, full, gui]
```

## 🎛️ Customization

### Adding New OS Support

1. Create new directory: `testing/newos/`
2. Add `Dockerfile` with OS-specific setup
3. Update [`run-tests.sh`](run-tests.sh) to include new OS
4. Test OS detection logic in [`test-chezmoi.sh`](test-chezmoi.sh)

### Custom Test Scripts

You can extend the testing by:

1. Modifying [`test-chezmoi.sh`](test-chezmoi.sh) to add new test functions
2. Creating OS-specific test scripts
3. Adding performance benchmarks
4. Testing specific package installations

### Docker Image Optimization

For faster testing, consider:

1. Creating base images with common dependencies
2. Using multi-stage builds
3. Caching package installations
4. Using smaller base images (alpine, etc.)

## 📈 Performance

### Timing Expectations

| Test Type | Ubuntu    | Arch      | Parallel |
| --------- | --------- | --------- | -------- |
| Lite      | ~2-3 min  | ~2-3 min  | ~3 min   |
| Full      | ~5-8 min  | ~5-8 min  | ~8 min   |
| GUI       | ~8-12 min | ~8-12 min | ~12 min  |

*Times include Docker image building and package installation*

### Optimization Tips

- Use `--parallel` for faster execution
- Pre-build images for repeated testing
- Use local package mirrors for faster downloads
- Test only changed components during development

## 🔗 Integration with Development Workflow

### Pre-commit Testing

```bash
#!/bin/bash
# .git/hooks/pre-commit
echo "Testing dotfiles before commit..."
./testing/run-tests.sh --install-type lite
```

### Development Testing

```bash
# Quick test during development
./testing/run-tests.sh --install-type lite --parallel

# Full validation before release
for type in lite full gui; do
    ./testing/run-tests.sh --install-type $type
done
```

## 📝 Contributing

When adding new features to your dotfiles:

1. Test locally with the testing framework
2. Ensure all install types work correctly
3. Verify both Ubuntu and Arch compatibility
4. Update tests if adding new OS support
5. Document any new testing requirements

## 🔍 Troubleshooting

### Test Failures

1. **Check the test output** for specific error messages
2. **Run with `--no-cleanup`** to inspect container state
3. **Test manually** inside the container
4. **Check Docker logs** for build issues
5. **Verify dotfiles syntax** with chezmoi locally

### Performance Issues

1. **Use parallel execution** with `-p` flag
2. **Check Docker resources** (CPU, memory limits)
3. **Monitor network speed** for package downloads
4. **Consider local package mirrors**

## 📄 License

This testing framework is part of the dotfiles repository and follows the same license terms.
