import app.neptype.keyboard.core.CandidateMerger;
import app.neptype.keyboard.core.SortedCandidateIndex;
import java.io.IOException;
import java.lang.reflect.Method;
import java.nio.channels.FileChannel;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;
import java.util.Scanner;

/** Mirrors the service's bounded index reads; original is an independent UI control. */
public final class ServiceLookup {
    private static FileChannel open(String path) {
        try { return FileChannel.open(Paths.get(path)); }
        catch (IOException e) { return null; }
    }
    private static void add(List<String> out, FileChannel channel, String roman) {
        if (channel == null) return;
        try { CandidateMerger.add(out, new SortedCandidateIndex(channel, 0, channel.size()).lookup(roman, 4), 4); }
        catch (IOException ignored) { }
    }
    public static void main(String[] args) throws Exception {
        if (args.length != 4) throw new IllegalArgumentException("authored mined google baseline|candidate");
        final boolean candidate;
        if (args[3].equals("baseline")) candidate = false;
        else if (args[3].equals("candidate")) candidate = true;
        else throw new IllegalArgumentException("invalid mode");
        // Reflection lets one identical harness compile against a baseline with
        // no phonetic class. A missing candidate implementation must fail.
        Method fallback = candidate ? Class.forName("app.neptype.keyboard.core.PhoneticCandidates").getMethod("lastResort", String.class, List.class) : null;
        try (FileChannel authored = open(args[0]); FileChannel mined = open(args[1]);
             FileChannel google = open(args[2]); Scanner input = new Scanner(System.in, "UTF-8")) {
            while (input.hasNextLine()) {
                String source = input.nextLine();
                List<String> found = new ArrayList<>();
                add(found, authored, source); add(found, mined, source); add(found, google, source);
                if (candidate) {
                    String value = (String) fallback.invoke(null, source, found);
                    if (CandidateMerger.safe(value)) found.add(value);
                }
                System.out.println(String.join("\t", found));
            }
        }
    }
}
