package com.example.java4shell;

/**
 * Entry point for the CVE-2026-114938 (Java4Shell) bounded local PoC.
 *
 * <h2>Exit Codes</h2>
 * <ul>
 *   <li>{@code 0} — no corruption observed; JVM is patched, mitigated, or
 *       the vulnerable code path was not active (e.g., non-AVX-512 CPU).</li>
 *   <li>{@code 1} — canary corruption observed; the vulnerable code path is
 *       active on this JVM and hardware.</li>
 * </ul>
 *
 * <p>Use exit codes in scripts:
 * <pre>
 *   ./scripts/run-poc.sh; echo "Exit: $?"
 * </pre>
 */
public final class Main {

    private Main() {}

    public static void main(String[] args) {
        printBanner();

        Base64Trigger.TriggerResult result = Base64Trigger.run();
        result.print();

        System.out.println();
        System.out.println("[*] For the negative control, run with:");
        System.out.println("    JAVA_TOOL_OPTIONS=-XX:-UseBASE64Intrinsics ./scripts/run-poc.sh");

        System.exit(result.isVulnerable() ? 1 : 0);
    }

    private static void printBanner() {
        System.out.println("=============================================================");
        System.out.println(" CVE-2026-114938 (Java4Shell) — Bounded Local PoC");
        System.out.println(" Target: OpenJDK AVX-512 VBMI Base64 heap overflow");
        System.out.println("-------------------------------------------------------------");
        System.out.println(" FOR RESEARCH / EDUCATION USE ONLY. See DISCLAIMER.md.");
        System.out.println(" Use only on systems you own or have written permission to test.");
        System.out.println("=============================================================");
        System.out.println();
    }
}
