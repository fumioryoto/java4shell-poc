# Technical Analysis — CVE-2026-114938 (Java4Shell)

> ⚠️ **Verify all version numbers, payload lengths, and affected ranges against
> authoritative sources (NVD, Oracle CPU, vendor advisories) before citing this
> document publicly.**

---

## 1. Summary

**CVE-2026-114938** is a heap buffer overflow in the **AVX-512 VBMI–accelerated Base64 decoder**
shipped with OpenJDK since version 17.0.6. A malformed Base64 input with an anomalous padding
unit causes an integer underflow in the internal length calculation, producing an incorrect write
mask and an out-of-bounds write of approximately 62–63 bytes into adjacent heap memory.

The decoder always throws `java.lang.IllegalArgumentException` after the overflow — the
corruption occurs *before* Java-level validation is applied.

---

## 2. Affected Components

| Component | Detail |
|---|---|
| **Library** | `java.util.Base64` (JDK standard library) |
| **Intrinsic** | `java.util.Base64$Decoder::decode` — AVX-512 VBMI code path |
| **JVM flag** | `-XX:+UseBASE64Intrinsics` (enabled by default) |
| **Architecture** | x86-64 with `avx512f`, `avx512bw`, `avx512vbmi`, `bmi2` |
| **ARM64** | Not affected |

---

## 3. Root Cause

### 3.1 Vectorised Base64 Decoder

Since JDK 17.0.6, the HotSpot JIT includes an intrinsic for `Base64.Decoder.decode()` that
uses AVX-512 VBMI shuffle instructions to decode 64 bytes of Base64 input per iteration, far
exceeding the throughput of the scalar path.

### 3.2 Integer Underflow in Length Accounting

The intrinsic computes the number of output bytes to commit based on the number of complete
4-character Base64 groups in the input. When the final group is malformed — specifically, a
group consisting of one or more valid Base64 characters followed by a premature padding
character `'='` — the padding accounting code performs an unsigned subtraction that wraps
around to a very large value (integer underflow).

### 3.3 Incorrect Write Mask

The underflowed length value is used as the input to a **BZHI** (Bit Zero High Index) or
equivalent masking instruction to select which bytes from the VBMI-decoded lane to commit to
the output array. Because the mask is computed from the underflowed value rather than the
true output length, the resulting write mask is incorrect, and the store instruction writes
bytes past the intended end of the output buffer.

### 3.4 Bounded OOB Write

The overflow is bounded by the width of the VBMI lane (64 bytes per iteration) and the size
of the padding underflow. Empirically, approximately **62–63 bytes** are written past the
intended output boundary on each trigger invocation.

---

## 4. Trigger Conditions

All of the following must be true simultaneously:

1. **CPU:** x86-64 with `avx512f`, `avx512bw`, `avx512vbmi`, and `bmi2` flags set.
2. **JVM:** The `UseBASE64Intrinsics` flag is enabled (default).
3. **Input:** A malformed Base64 string matching the form below.

### 4.1 Payload Selection by JDK Version

| JDK line | Trigger payload | Byte count |
|---|---|---|
| 17 | `"A" × 128 + "="` | 129 bytes |
| 21 / 25 / 27 | `"A" × 64 + "="` | 65 bytes |

The difference reflects changes in the intrinsic's loop unrolling and lane selection logic
between JDK releases.

---

## 5. Reproduction Methodology (This PoC)

### 5.1 Canary-Based Detection

This PoC uses a **canary oracle** to detect the overflow without attempting to exploit it:

1. A `byte[8192]` canary array is allocated and filled with the sentinel value `0xA5`.
2. The trigger payload is passed to `Base64.getDecoder().decode(input)`.
3. The canary array is scanned for any bytes that differ from `0xA5`.
4. If any canary bytes have changed, the vulnerable code path was active and the
   out-of-bounds write occurred.

### 5.2 Canary Placement

The canary is allocated *after* the input array in the same method frame. On typical HotSpot
heap layouts this places the canary close enough to the decode output buffer to catch the
spill. This is not a guaranteed arrangement — heap layout is JVM-dependent — so a negative
result on a vulnerable JVM is possible if the allocator places the canary out of range of
the spill.

### 5.3 Negative Control

Running with `-XX:-UseBASE64Intrinsics` forces the scalar code path, which does not contain
the underflow. The canary should always read all `0xA5` bytes in the mitigated run.

---

## 6. What This PoC Does NOT Do

- Does not build a heap-grooming or heap-shaping primitive.
- Does not chain the corruption to a JIT recompilation, JNI, or ROP payload.
- Does not target any specific product (Jira, Keycloak, Jenkins, Confluence, etc.).
- Does not scan network endpoints.
- Does not exfiltrate data.

---

## 7. Impact Assessment

| Aspect | Assessment |
|---|---|
| **Exploitability** | Requires attacker-controlled input to reach `Base64.Decoder.decode()` |
| **Hardware prerequisite** | AVX-512 VBMI capable CPU (server / data-center class) |
| **Write primitive** | Bounded (~62 bytes), adjacent heap region |
| **Potential impact** | Heap corruption → possible DoS or, with chaining, code execution |
| **Preconditions for RCE** | Significant additional research required; not demonstrated here |

---

## 8. Mitigations

| Mitigation | JVM Flag | Notes |
|---|---|---|
| Disable Base64 intrinsic | `-XX:-UseBASE64Intrinsics` | Drops AVX-512 acceleration for all `Base64` calls |
| Cap AVX level | `-XX:UseAVX=2` | Prevents use of AVX-512 paths globally |
| Upgrade JDK | n/a | Apply vendor-published fixed build for your JDK line |

### 8.1 Affected and Fixed Versions

> Verify against vendor advisories.

| JDK line | Vulnerable range | Fixed |
|---|---|---|
| 17 | 17.0.6 – 17.0.21 | 17.0.21.1+ |
| 21 | < 21.0.13.1 | 21.0.13.1+ |
| 25 | < 25.0.5.1 | 25.0.5.1+ |
| 27 | < 27.0.1.1 | 27.0.1.1+ |

---

## 9. Detection Guidance

See [`../detection/`](../detection/) for:

- **Suricata rules:** Match the malformed Base64 pattern in HTTP Authorization and
  SAMLResponse fields.
- **Sigma rule:** Match `hs_err_pid*.log` artifacts consistent with this crash.

Additional indicators:
- Unexpected `hs_err_pid*.log` files in Java process working directories.
- `IllegalArgumentException` from `java.util.Base64` in application logs.
- JVM crash reports referencing `java.util.Base64$Decoder` or `Base64` intrinsics
  in the problematic frame.

---

## 10. References

- NVD: https://nvd.nist.gov/vuln/detail/CVE-2026-114938 *(verify)*
- Oracle Security Alerts: https://www.oracle.com/security-alerts/
- Eclipse Adoptium / Temurin: https://github.com/adoptium/temurin-build/security

---

*Analysis by: nullkitsune (Md. Nahidul Islam)*  
*Date: 2026-11-18*  
*Affiliation: Independent Security Research*
