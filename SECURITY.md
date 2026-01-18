# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| main    | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability in ComplianceHub, please report it responsibly:

1. **Do NOT** open a public GitHub issue for security vulnerabilities
2. **Email** security concerns to the repository maintainers
3. **Or** use GitHub's private security advisory feature

### What to Include

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

### Response Timeline

- **Initial response**: Within 48 hours
- **Status update**: Within 7 days
- **Resolution**: Dependent on severity and complexity

## Security Best Practices

This repository contains compliance and governance automation scripts. When contributing:

### PowerShell Scripts

- Never hardcode credentials or secrets
- Use `SecureString` for password handling
- Validate all user inputs
- Use `-WhatIf` for destructive operations

### Azure Policies

- Test policies in report-only mode first
- Always exclude emergency access accounts
- Document policy changes in COMPLIANCE-MAPPING.md

### CI/CD

- Use GitHub Secrets for sensitive values
- Enable branch protection on `main`
- Require PR reviews before merging

## Compliance Considerations

This repository handles security policies. All contributions should:

- Maintain audit trails
- Follow least-privilege principles
- Support SOX/GDPR/HIPAA compliance where applicable
