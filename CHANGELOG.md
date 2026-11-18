# Changelog

All notable changes to this project are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
This project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

---

## [1.0.0] — 2026-11-18

### Added
- Initial public release of the bounded CVE-2026-114938 PoC.
- `Base64Trigger.java` — heap overflow reproducer with canary-based detection.
- `Main.java` — entry point with exit codes 0 (clean) / 1 (vulnerable) / 2 (prerequisites missing).
- `scripts/preflight.sh` — CPU flag validation for AVX-512 VBMI requirement.
- `scripts/setup-runtime.sh` — downloads a pinned vulnerable Temurin JDK build.
- `scripts/run-poc.sh` — compile-and-run wrapper.
- `Makefile` — convenience targets for all major workflows.
- `docker/Dockerfile.vulnerable` — isolated vulnerable container.
- `docker/Dockerfile.mitigated` — isolated mitigated container (negative control).
- `docker/docker-compose.yml` — orchestrates both containers.
- `docs/ANALYSIS.md` — full root-cause analysis of the integer underflow.
- `docs/RESULTS.md` — reproduction results template.
- `detection/suricata.rules` — HTTP-layer detection for the malformed Base64 pattern.
- `detection/sigma.yml` — JVM crash log detection rule.
- `gradle/wrapper/gradle-wrapper.properties` — pinned Gradle wrapper.
- `.github/workflows/ci.yml` — GitHub Actions: compile check on every push.
- `.github/ISSUE_TEMPLATE/bug_report.md` — structured bug report template.
- `.github/ISSUE_TEMPLATE/research_question.md` — research discussion template.
- `DISCLAIMER.md`, `SECURITY.md`, `CONTRIBUTING.md` — governance files.

---

[Unreleased]: https://github.com/YOURNAME/java4shell-poc/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/YOURNAME/java4shell-poc/releases/tag/v1.0.0
