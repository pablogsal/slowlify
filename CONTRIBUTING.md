# Contributing to Slowlify

Thanks for your interest in contributing to Slowlify! This document provides guidelines for contributing.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/slowlify.git`
3. Create a branch: `git checkout -b feature/your-feature-name`

## Development Setup

Slowlify is a single Bash script with minimal dependencies. To develop:

```bash
# Check your system has the required tools
sudo ./slowlify --check-deps

# Run the unit tests (no root required)
./tests/test_unit.sh

# Run the full test suite (requires root + bats)
sudo bats tests/test_slowrun.bats
```

### Installing BATS

BATS (Bash Automated Testing System) is used for integration tests:

```bash
# Ubuntu/Debian
sudo apt install bats

# macOS
brew install bats-core

# npm
npm install -g bats
```

## Code Style

- Use 4-space indentation
- Follow existing patterns in the codebase
- Use `shellcheck` to lint your changes
- Add comments for non-obvious logic
- Keep functions focused and reasonably sized

### Shellcheck

```bash
shellcheck slowlify
```

## Making Changes

### Adding a New Profile

Profiles are defined in the `apply_profile()` function. To add a new one:

1. Add the case in `apply_profile()`:
```bash
my-profile)
    CPU_PERCENT=XX
    MEMORY_LIMIT="XXM"
    # ... other settings
    ;;
```

2. Add it to `list_profiles()` output
3. Document it in README.md
4. Add a test in `tests/test_slowrun.bats`

### Adding a New Option

1. Add the default value in the configuration section
2. Add argument parsing in the `while` loop
3. Use the value in the appropriate function
4. Update `usage()` to document it
5. Update README.md
6. Add tests

## Testing

### Running Tests

```bash
# Unit tests (no root, fast)
./tests/test_unit.sh

# Integration tests (requires root + cgroups v2)
sudo bats tests/test_slowrun.bats

# Run specific test
sudo bats tests/test_slowrun.bats --filter "profile"
```

### Writing Tests

- Unit tests go in `tests/test_unit.sh`
- Integration tests go in `tests/test_slowrun.bats`
- Use `skip_if_not_root` for tests requiring privileges
- Use `skip_if_no_cgroups_v2` for tests requiring cgroups

Example BATS test:
```bash
@test "my feature works" {
    skip_if_not_root
    skip_if_no_cgroups_v2

    run "$SLOWRUN" --my-option -- echo "test"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"expected"* ]]
}
```

## Submitting Changes

1. Ensure all tests pass
2. Run `shellcheck slowlify`
3. Update documentation if needed
4. Commit with a clear message:
   ```
   Add --my-option for doing X

   - Adds new option to configure Y
   - Updates documentation
   - Adds tests
   ```
5. Push to your fork
6. Open a Pull Request

### PR Guidelines

- One feature/fix per PR
- Include tests for new functionality
- Update README if user-facing behavior changes
- Keep commits atomic and well-described

## Reporting Issues

When reporting bugs, please include:

- Your Linux distribution and version
- Kernel version (`uname -r`)
- Output of `./slowlify --check-deps`
- The exact command that failed
- Full error output

## Feature Requests

Feature requests are welcome! Please:

- Check if the feature already exists
- Describe the use case
- Explain why the default profiles don't cover it

## Questions?

Open an issue for questions about the codebase or how to contribute.
