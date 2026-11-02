import app.neptype.keyboard.core.SortedCandidateIndex;
import app.neptype.keyboard.core.CandidateMerger;
import java.nio.channels.FileChannel;
import java.io.IOException;
import java.nio.file.Paths;
import java.util.*;

/** Mirrors the Android service's three index reads and four-choice limit. */
public final class ServiceLookup {
    private static FileChannel open(String path) {
        try { return FileChannel.open(Paths.get(path)); }
        catch (IOException failure) { return null; }
    }
    private static void add(List<String> values, FileChannel channel, String key) {
        if (channel == null) return;
        try {
            SortedCandidateIndex index = new SortedCandidateIndex(channel, 0, channel.size());
            CandidateMerger.add(values, index.lookup(key, 4), 4);
        } catch (IOException failure) {
            // Match the service's unavailable-index fallback: retain prior sources.
        }
    }
    public static void main(String[] args) throws Exception {
        try (FileChannel authored = open(args[0]);
             FileChannel mined = open(args[1]);
             FileChannel google = open(args[2]);
             Scanner in = new Scanner(System.in, "UTF-8")) {
            while (in.hasNextLine()) {
                String key = in.nextLine();
                List<String> out = new ArrayList<>();
                add(out, authored, key); add(out, mined, key); add(out, google, key);
                System.out.println(String.join("\t",out));
            }
        }
    }
}
