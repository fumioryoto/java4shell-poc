# Reproduction Results

> Fill in this template with your actual results before publishing.

---

## Environment

| Field | Value |
|---|---|
| **Host CPU** | `<e.g., Intel Xeon Gold 6338 (Ice Lake)>` |
| **CPU flags** | `<avx512f avx512bw avx512vbmi bmi2 — output of preflight.sh>` |
| **Kernel** | `<uname -a output>` |
| **JDK** | `<java -version output>` |
| **Date tested** | `<YYYY-MM-DD>` |
| **PoC version** | `v1.0.0` |

---

## Preflight Output

```
$ ./scripts/preflight.sh
<paste output here>
```

---

## Vulnerable Run

```
$ ./scripts/run-poc.sh
=============================================================
 CVE-2026-114938 (Java4Shell) — Bounded Local PoC
 Target: OpenJDK AVX-512 VBMI Base64 heap overflow
-------------------------------------------------------------
 FOR RESEARCH / EDUCATION USE ONLY. See DISCLAIMER.md.
 Use only on systems you own or have written permission to test.
=============================================================

[*] JDK feature version : 21
[*] Payload length       : 65 bytes
[*] Decoder threw        : true
    type    : IllegalArgumentException
    message : <vendor message>

[!] RESULT: VULNERABLE (heap overflow detected)
    Bytes changed beyond expected output : 62
    First changed offset                 : <n>
    Last changed offset                  : <n>

$ echo "Exit code: $?"
Exit code: 1
```

---

## Mitigated Run (Negative Control — Intrinsic Disabled)

```
$ JAVA_TOOL_OPTIONS=-XX:-UseBASE64Intrinsics ./scripts/run-poc.sh
=============================================================
 CVE-2026-114938 (Java4Shell) — Bounded Local PoC
 ...
=============================================================

[*] JDK feature version : 21
[*] Payload length       : 65 bytes
[*] Decoder threw        : true
    type    : IllegalArgumentException

[*] RESULT: NOT VULNERABLE (no overflow detected)
    Bytes changed beyond expected output : 0

$ echo "Exit code: $?"
Exit code: 0
```

---

## Mitigated Run (AVX Level Cap)

```
$ JAVA_TOOL_OPTIONS="-XX:UseAVX=2" ./scripts/run-poc.sh
<paste output here>
```

---

## Notes

- The exact `changedBytes` count may vary slightly between runs due to heap layout
  non-determinism; any non-zero value is the signal.
- If the JVM crashes, `hs_err_pid*.log` will be written to the working directory. These
  files are intentionally excluded by `.gitignore`. Attach them as evidence in your
  research writeup but do not commit them.
- The decoder always throws `IllegalArgumentException` — this is expected. The overflow
  occurs *before* Java-level input validation.

---

## JDK 17 Run (if tested)

```
$ JAVA_HOME=<path-to-jdk17-vulnerable> ./scripts/run-poc.sh
<paste output here>
```

---

## Docker Run

```
$ docker compose -f docker/docker-compose.yml up --build --abort-on-container-exit
<paste output here>
```
