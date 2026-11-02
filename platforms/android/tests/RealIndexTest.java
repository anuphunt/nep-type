import app.lekha.keyboard.core.SortedCandidateIndex;
import app.lekha.keyboard.core.Composition;
import java.nio.channels.FileChannel;
import java.nio.file.*;
import java.util.*;
public final class RealIndexTest {
    public static void main(String[] args) throws Exception {
        try (FileChannel ak = FileChannel.open(Paths.get(args[0])); FileChannel google = FileChannel.open(Paths.get(args[1])); FileChannel curated = FileChannel.open(Paths.get(args[2]))) {
            SortedCandidateIndex c = new SortedCandidateIndex(curated, 0, curated.size());
            if (!c.lookup("football", 4).equals(Collections.singletonList("फुटबल"))) throw new AssertionError("authored football");
            if (!c.lookup("bhetau", 4).equals(Collections.singletonList("भेटौँ"))) throw new AssertionError("authored bhetau");
            SortedCandidateIndex a = new SortedCandidateIndex(ak, 0, ak.size());
            SortedCandidateIndex g = new SortedCandidateIndex(google, 0, google.size());
            if (!a.lookup("bhaisakeko", 4).contains("भइसकेको")) throw new AssertionError("Aksharantar lookup");
            if (!g.lookup("namaste", 4).contains("नमस्ते")) throw new AssertionError("Google namaste");
            if (!g.lookup("pani", 4).contains("पानी")) throw new AssertionError("Google alternative");
            if (!g.lookup("mero", 4).contains("मेरो")) throw new AssertionError("Google mero");
            if (!a.lookup("https://example.com", 4).isEmpty()) throw new AssertionError("literal");
            // Simulate explicit candidate choices; this is a Java core test,
            // not Android InputConnection or context-classification testing.
            String[] words = {"ma", "office", "janchu", "football"};
            String[] choices = {"म", null, "जान्छु", "फुटबल"};
            StringBuilder sentence = new StringBuilder();
            Composition session = new Composition();
            for (int i = 0; i < words.length; i++) {
                for (char letter : words[i].toCharArray()) if (!session.append(String.valueOf(letter))) throw new AssertionError("append");
                String raw = session.takeOriginal();
                if (choices[i] != null && !c.lookup(raw, 4).contains(choices[i])) throw new AssertionError("authored mixed candidate " + raw);
                if (i > 0) sentence.append(' ');
                sentence.append(choices[i] == null ? raw : choices[i]);
            }
            if (!sentence.toString().equals("म office जान्छु फुटबल")) throw new AssertionError("mixed original and explicit choices");
            System.out.println("PASS: actual offline indexes and literal input");
        }
    }
}
