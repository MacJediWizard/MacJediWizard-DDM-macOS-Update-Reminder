# Contributing to DDM macOS Update Reminder

Thank you for your interest in contributing! This document provides guidelines for contributing to the project.

## Getting Started

1. Fork the repository
2. Clone your fork locally
3. Create a branch for your feature or fix
4. Make your changes
5. Test thoroughly
6. Submit a pull request

## Branch Naming

- `feature/description` - New features
- `bugfix/description` - Bug fixes
- `docs/description` - Documentation updates
- `refactor/description` - Code refactoring

## Commit Messages

Use clear, descriptive commit messages:

```
type: Brief description

Longer explanation if needed.

Fixes #123
```

Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`

## Pull Request Process

1. Update documentation if needed
2. Add tests for new functionality
3. Ensure all tests pass
4. Update CHANGELOG.md
5. Reference related issues in PR description

## Code Style

### Swift

- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use meaningful variable and function names
- Add comments for complex logic
- Keep functions focused and small

### Shell Scripts

- Use `shellcheck` for linting
- Quote variables properly
- Add error handling
- Include usage comments

## Testing

- Test on both Apple Silicon and Intel Macs
- Test with various macOS versions (13+)
- Test configuration edge cases
- Verify logging output

## Reporting Issues

When reporting issues, include:

- macOS version
- Binary version
- Configuration profile settings (sanitized)
- Relevant log output
- Steps to reproduce

## Questions?

Open a discussion or reach out on Mac Admins Slack #ddm-os-reminders.
