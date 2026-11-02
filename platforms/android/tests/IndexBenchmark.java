import app.neptype.keyboard.core.SortedCandidateIndex;
import java.nio.channels.FileChannel;
import java.nio.file.*;
import java.util.*;
public final class IndexBenchmark {
    public static void main(String[] args) throws Exception {
        Path path = Paths.get(args[0]);
        try (FileChannel channel = FileChannel.open(path)) {
            SortedCandidateIndex index = new SortedCandidateIndex(channel, 0, channel.size());
            String[] words = {"namaste", "pani", "football", "bhaisakeko", "sarkar", "kathmandu", "aaja", "mero", "swagat", "zaxxy"};
            for (String word : words) {
                long start = System.nanoTime();
                List<String> candidates = index.lookup(word, 4);
                double ms = (System.nanoTime() - start) / 1_000_000.0;
                System.out.printf(Locale.ROOT, "%s %.2f ms %s%n", word, ms, candidates);
            }
        }
    }
}
