# Security Policy

## Scope

This repository is a **bounded crash/reproducer PoC** for CVE-2026-114938.
It does not attempt remote code execution and does not contain a weaponized exploit chain.

## What This Repository Covers

- A local, single-process reproduction harness that proves the AVX-512 VBMI heap overflow.
- Safe canary-based detection of out-of-bounds writes.
- A negative control path (`-XX:-UseBASE64Intrinsics`).
- Suricata and Sigma detection rules for defenders.

## Reporting Issues in This Repository

If you believe the PoC code itself introduces a safety or correctness problem
(e.g., unsafe memory handling in a helper script, an inadvertent weaponization vector),
please open a **private GitHub security advisory** rather than a public issue:

> **GitHub → Security → Report a vulnerability**

Do **not** open a public issue for security concerns about this repository itself.

## Reporting the Underlying Vulnerability

Report issues in OpenJDK and downstream distributions to:

| Vendor | Channel |
|---|---|
| Oracle | https://www.oracle.com/security-alerts/ |
| Adoptium / Eclipse Temurin | https://github.com/adoptium/temurin-build/security |
| Amazon Corretto | https://aws.amazon.com/security/vulnerability-reporting/ |
| Azul | https://www.azul.com/responsible-disclosure/ |
| Red Hat | https://access.redhat.com/security/team/contact/ |

Do **not** use this repository to report the underlying CVE-2026-114938 vulnerability.

## Safe Use Requirements

- Run only on hardware you own or have **explicit written authorization** to test.
- Prefer an isolated VM or container (see `docker/`).
- Never point this PoC at a third-party service without authorization.
- Do not modify this harness to add exploitation chains and redistribute it.

## Versioning and Supported Versions

Only the latest tagged release of this repository is maintained.

| Version | Supported |
|---|---|
| Latest tag | ✅ Yes |
| Older tags | ❌ No — please update |
