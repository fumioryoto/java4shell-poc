# CVE-2026-114938 (Java4Shell) — Bounded Local PoC

> **A read-only-first, bounded reproduction harness for the OpenJDK AVX-512 Base64 heap overflow.**  
> This proves the out-of-bounds write. It does **not** contain a weaponized RCE chain.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Status: Research](https://img.shields.io/badge/Status-Research-blue)]()
[![CVE](https://img.shields.io/badge/CVE-2026--114938-red)]()

> ⚠️ **DISCLAIMER:** For security research and education only. Use ONLY on
> systems you own or have explicit written permission to test. The authors
> accept no liability for misuse. See [`DISCLAIMER.md`](DISCLAIMER.md).

---

## Table of Contents

- [What This Is / Is Not](#what-this-is--is-not)
- [Vulnerability Summary](#vulnerability-summary)
- [Hardware Preflight](#hardware-preflight-required)
- [Quick Start](#quick-start)
- [Docker Usage](#docker-usage)
- [Expected Output](#expected-output)
- [Affected Versions](#affected-versions)
- [Payload Selection](#payload-selection)
- [Mitigations](#mitigations)
- [Detection](#detection)
- [Repository Structure](#repository-structure)
- [Contributing](#contributing)
- [How to Cite](#how-to-cite)
- [License](#license)

---

## What This Is / Is Not

| ✅ Does | ❌ Does Not |
|---|---|
| Proves the OOB write trigger | Ship a universal pre-auth RCE chain |
| Reproduces heap corruption locally and safely | Include product-specific exploit chains |
| Includes a safe canary oracle to detect corruption | Act as a mass scanner or fuzzer |
| Provides a negative control (mitigated path) | Exfiltrate any data |
| Ships Suricata and Sigma detection content | Require a network connection to run |

---

## Vulnerability Summary

**CVE-2026-114938** ("Java4Shell") is a heap buffer overflow in the **AVX-512 VBMI–accelerated
Base64 decoder** shipped with OpenJDK since 17.0.6.

A malformed Base64 input with an anomalous padding unit causes an integer underflow in the
internal length calculation, producing an incorrect write mask and an out-of-bounds write of
approximately 62–63 bytes into adjacent heap memory.

> ⚠️ **Verify CVE details against authoritative sources** (NVD, Oracle CPU, vendor advisories)
> before citing them in public research. See [`docs/ANALYSIS.md`](docs/ANALYSIS.md) for a
> full technical breakdown.

---

## Hardware Preflight (required)

The vulnerable code path is the **AVX-512 VBMI**-accelerated Base64 decoder.
Your CPU must expose all four required flags:

```bash
grep -m1 '^flags' /proc/cpuinfo | tr ' ' '\n' | \
  grep -E '^(avx512f|avx512bw|avx512vbmi|bmi2)$'
```

Expected output (all four present):

```
avx512f
avx512bw
avx512vbmi
bmi2
```

> **ARM64 is not affected.**  
> Relevant x86-64 microarchitectures: Intel Ice Lake / Sapphire Rapids / Emerald Rapids /
> Granite Rapids and AMD Zen 4+.

Run the full preflight script:

```bash
./scripts/preflight.sh
```

---

## Quick Start

```bash
git clone https://github.com/YOURNAME/java4shell-poc.git
cd java4shell-poc

# 1. Environment checks
./scripts/preflight.sh

# 2. Fetch a pinned, vulnerable JDK (Temurin)
./scripts/setup-runtime.sh

# 3. Run the vulnerable proof
./scripts/run-poc.sh

# 4. Negative control (intrinsic disabled — should report NOT VULNERABLE)
JAVA_TOOL_OPTIONS=-XX:-UseBASE64Intrinsics ./scripts/run-poc.sh
```

Or use **Make**:

```bash
make preflight
make setup
make run
make run-mitigated
make docker-run
```

---

## Docker Usage

Preferred for isolation. No AVX-512 capable host? The Docker run will simply report
`NOT VULNERABLE` by design — that is the correct behavior on non-AVX-512 hardware.

```bash
# Build and run both vulnerable and mitigated containers
docker compose -f docker/docker-compose.yml up --build --abort-on-container-exit

# Vulnerable only
docker compose -f docker/docker-compose.yml run vulnerable

# Mitigated only
docker compose -f docker/docker-compose.yml run mitigated
```

---

## Expected Output

### Vulnerable run (exit code 1)

```
=== CVE-2026-114938 (Java4Shell) — Bounded Local PoC ===
Target: OpenJDK AVX-512 VBMI Base64 heap overflow

[*] JDK feature version: 21
[*] Payload length: 65 bytes
[*] Decoder threw exception: true
    message: Illegal base64 character 3d

[!] RESULT: VULNERABLE (heap overflow detected)
    Bytes changed beyond expected output: 62
    First changed offset: <n>
    Last changed offset:  <n>
```

### Mitigated run (exit code 0)

```
=== CVE-2026-114938 (Java4Shell) — Bounded Local PoC ===
Target: OpenJDK AVX-512 VBMI Base64 heap overflow

[*] JDK feature version: 21
[*] Payload length: 65 bytes
[*] Decoder threw exception: true

[*] RESULT: NOT VULNERABLE (no overflow detected)
    Bytes changed beyond expected output: 0
```

---

## Affected Versions

> ⚠️ Verify these ranges against vendor advisories before citing publicly.

| JDK line | Vulnerable range | Fixed |
|---|---|---|
| 17 | 17.0.6 – 17.0.21 | 17.0.21.1+ |
| 21 | < 21.0.13.1 | 21.0.13.1+ |
| 25 | < 25.0.5.1 | 25.0.5.1+ |
| 27 | < 27.0.1.1 | 27.0.1.1+ |

---

## Payload Selection

| JDK line | Trigger payload | Length |
|---|---|---|
| 17 | `"A" * 128 + "="` | 129 bytes |
| 21 / 25 / 27 | `"A" * 64 + "="` | 65 bytes |

The harness selects the correct payload automatically based on `Runtime.version().feature()`.

---

## Mitigations

| Mitigation | Method |
|---|---|
| Disable vectorised decoder | `-XX:-UseBASE64Intrinsics` |
| Cap AVX level | `-XX:UseAVX=2` |
| Patch | Upgrade to vendor-published fixed build |

---

## Detection

See [`detection/`](detection/) for:

- **[`suricata.rules`](detection/suricata.rules)** — HTTP-level rules matching the malformed
  Base64 pattern in Authorization and SAMLResponse fields.
- **[`sigma.yml`](detection/sigma.yml)** — Sigma rule matching JVM crash log artifacts
  (`hs_err_pid*.log`) consistent with this vulnerability.

---

## Repository Structure

```
java4shell-poc/
├── README.md
├── LICENSE
├── SECURITY.md
├── DISCLAIMER.md
├── CONTRIBUTING.md
├── CHANGELOG.md
├── Makefile
├── .gitignore
├── build.gradle
├── settings.gradle
├── gradle.properties
├── gradle/wrapper/
│   └── gradle-wrapper.properties
├── src/main/java/com/example/java4shell/
│   ├── Base64Trigger.java
│   └── Main.java
├── scripts/
│   ├── preflight.sh
│   ├── setup-runtime.sh
│   └── run-poc.sh
├── docker/
│   ├── Dockerfile.vulnerable
│   ├── Dockerfile.mitigated
│   └── docker-compose.yml
├── docs/
│   ├── ANALYSIS.md
│   └── RESULTS.md
├── detection/
│   ├── suricata.rules
│   └── sigma.yml
└── .github/
    ├── workflows/
    │   └── ci.yml
    └── ISSUE_TEMPLATE/
        ├── bug_report.md
        └── research_question.md
```

---

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md). In short:

- Security improvements and detection content are welcome.
- Do **not** open PRs that add weaponized exploit chains, scanners, or payloads
  targeting specific products.

---

## How to Cite

```
java4shell-poc: Bounded local reproduction of CVE-2026-114938.
GitHub: YOURNAME/java4shell-poc, v1.0.0.
```

---

## License

MIT. See [`LICENSE`](LICENSE).
