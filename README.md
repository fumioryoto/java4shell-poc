# CVE-2026-114938 (Java4Shell) — Local Bounded PoC

**A read-only-first reproduction harness for the OpenJDK AVX-512 Base64 heap overflow. This proves the memory corruption; it does NOT contain a weaponized RCE chain.**

> ⚠️ **DISCLAIMER:** For security research and education only. Use ONLY on systems you own or have explicit written permission to test. The authors are not responsible for misuse.

## What This Is / Is Not

| ✅ Proves the OOB trigger | ❌ Does not ship a universal pre-auth RCE |
| ✅ Reproduces the heap corruption deterministically | ❌ Does not include product-specific exploit chains |
| ✅ Includes a safe, bounded local oracle | ❌ Is not a mass scanner |

## Quick Start (Hardware Preflight Required)

```bash
# 1. Verify your CPU supports AVX-512 VBMI
grep -m1 '^flags' /proc/cpuinfo | tr ' ' '\n' | grep -E '^(avx512f|avx512bw|avx512vbmi|bmi2)$'

# 2. Clone and build
git clone https://github.com/YOURNAME/your-java4shell-poc.git
cd your-java4shell-poc
./scripts/setup-runtime.sh   # Downloads pinned Temurin JDK
./scripts/preflight.sh       # Confirms environment

# 3. Run the vulnerable proof
./run-poc.sh

# 4. Run the negative control (intrinsic disabled)
JAVA_TOOL_OPTIONS=-XX:-UseBASE64Intrinsics ./run-poc.sh
