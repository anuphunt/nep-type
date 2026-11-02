import app.lekha.keyboard.core.PhoneticCandidates;
import java.util.Arrays;

/** Small hot-process measurement; not an Android-device or keystroke benchmark. */
public final class PhoneticBench {
    public static void main(String[] args) {
        String[] words = {"bahira", "lekhdai", "sikauchhu", "swastha", "prasanna", "ramailo", "bujhaidinu", "dhanyabaad", "karyakram", "samayama"};
        for (int i = 0; i < 5000; i++) PhoneticCandidates.suggest(words[i % words.length]);
        long[] durations = new long[10000]; int sink = 0;
        for (int i = 0; i < durations.length; i++) {
            long start = System.nanoTime();
            sink += PhoneticCandidates.suggest(words[i % words.length]).length();
            durations[i] = System.nanoTime() - start;
        }
        Arrays.sort(durations);
        System.out.printf("Hot Java phonetic 10,000 calls: p50 %.4f ms, p95 %.4f ms (sink=%d)%n", durations[5000] / 1e6, durations[9500] / 1e6, sink);
    }
}
