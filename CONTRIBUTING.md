# Contributing

Thank you for your interest in improving this research repository.

## What We Welcome

- **Detection content:** Suricata rules, Sigma rules, Yara rules, Snort rules.
- **Additional JDK version coverage:** Verified trigger data for JDK versions not yet tested.
- **Script improvements:** Better error handling, portability fixes, macOS support.
- **Documentation:** Corrections, additional analysis, and research writeups.
- **Docker improvements:** Better base images, multi-arch support.
- **Negative test cases:** Additional mitigation paths that should produce `NOT VULNERABLE`.

## What We Do NOT Accept

- Weaponized exploit chains, heap-grooming primitives, or RCE payloads.
- Mass scanners, crawlers, or network-active payloads.
- Payloads targeting specific products (Jira, Keycloak, Jenkins, etc.).
- Changes that remove or weaken the DISCLAIMER, SECURITY.md, or canary-only scope.

## How to Contribute

1. **Fork** this repository.
2. Create a **feature branch**: `git checkout -b feature/my-improvement`
3. Make your changes with clear commit messages.
4. If you are adding or modifying detection rules, include a brief description
   of the logic and any tested true/false positive notes.
5. Open a **Pull Request** against `main`.
6. Fill in the PR template.

## Code Style

- **Java:** Follow standard Java conventions. Keep the PoC scope strictly bounded —
  no networking, no file I/O beyond what already exists, no JNI.
- **Shell scripts:** `set -euo pipefail` at the top. POSIX-compatible where possible.
- **Markdown:** Wrap lines at 100 characters. Use ATX-style headings.

## Commit Convention

```
type(scope): short description

body (optional)

Refs: #issue-number
```

Types: `feat`, `fix`, `docs`, `chore`, `detection`, `test`

## Reporting Bugs

Use the GitHub issue template at `.github/ISSUE_TEMPLATE/bug_report.md`.

## Code of Conduct

This project follows a standard professional code of conduct: be respectful, constructive,
and focused on improving security research and defender capabilities.
