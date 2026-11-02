import app.lekha.keyboard.core.SortedCandidateIndex;
import java.nio.channels.FileChannel;
import java.nio.file.Path;
import java.util.*;

/** Offline comparison probe; no Android APIs or IME involved. */
public final class CandidateProbe {
    public static void main(String[] args) throws Exception {
        try (FileChannel a = FileChannel.open(Path.of(args[0])); FileChannel g = FileChannel.open(Path.of(args[1])); FileChannel c = FileChannel.open(Path.of(args[2])); Scanner stdin = new Scanner(System.in, "UTF-8")) {
            var first = new SortedCandidateIndex(a, 0, a.size());
            var second = new SortedCandidateIndex(g, 0, g.size());
            var curated = new SortedCandidateIndex(c, 0, c.size());
            while (stdin.hasNextLine()) {
                String word = stdin.nextLine();
                var values = new LinkedHashSet<String>();
                values.addAll(curated.lookup(word, 4));
                values.addAll(first.lookup(word, 4));
                values.addAll(second.lookup(word, 4));
                System.out.println(String.join("\t", values.stream().limit(4).toList()));
            }
        }
    }
}
