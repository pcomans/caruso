# Security Policy

## Supported Versions

We release patches for security vulnerabilities in the following versions:

| Version | Supported          |
| ------- | ------------------ |
| 0.5.x   | :white_check_mark: |
| < 0.5   | :x:                |

## Reporting a Vulnerability

We take the security of Caruso seriously. If you discover a security vulnerability, please follow these steps:

### 1. **Do Not** Open a Public Issue

Please do not report security vulnerabilities through public GitHub issues, discussions, or pull requests.

### 2. Report Privately

Please report security vulnerabilities using GitHub's private vulnerability reporting:

- Go to the [Security tab](https://github.com/pcomans/caruso/security)
- Click "Report a vulnerability"
- Fill out the form with details about the vulnerability

### 3. Include Details

Please include as much of the following information as possible:

- Type of vulnerability (e.g., command injection, path traversal, etc.)
- Step-by-step instructions to reproduce the issue
- Proof of concept or exploit code (if possible)
- Impact of the vulnerability
- Suggested fix (if you have one)

### 4. What to Expect

- **Acknowledgment**: We'll acknowledge your report within 48 hours
- **Updates**: We'll keep you informed about our progress
- **Fix Timeline**: We aim to release a fix within 7-14 days for critical vulnerabilities
- **Credit**: With your permission, we'll credit you in the security advisory

## Security Considerations

When using Caruso, keep these security practices in mind:

### Marketplace Sources

- Only add marketplaces from trusted sources
- Review plugin code before installation when possible
- Be cautious with marketplaces requiring authentication

### Git Credentials

- Caruso uses Git to clone marketplace repositories
- Ensure your Git credentials are properly secured
- Use SSH keys or personal access tokens instead of passwords

### File Permissions

- Caruso writes files to `.cursor/rules/caruso/`
- Ensure proper file permissions in your project directory
- Review generated files before committing to version control

### Dependencies

- Keep Caruso updated to the latest version
- Regularly update Ruby and gem dependencies
- Run `gem update caruso` to get security patches

## Scope

This security policy applies to:

- The Caruso gem and CLI tool
- Official marketplace repositories maintained by this project
- Documentation and examples in this repository

It does not cover:

- Third-party marketplaces or plugins
- User-created custom plugins
- Vulnerabilities in Ruby itself or system dependencies

## Security Updates

Security updates will be announced through:

- GitHub Security Advisories
- Release notes in CHANGELOG.md
- RubyGems.org security alerts

## Additional Resources

- [RubyGems Security Guide](https://guides.rubygems.org/security/)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
