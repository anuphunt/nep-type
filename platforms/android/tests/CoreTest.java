import app.neptype.keyboard.core.*;
import java.nio.channels.FileChannel;
import java.nio.file.*;
import java.nio.charset.StandardCharsets;
import java.util.*;

public final class CoreTest {
    static void check(boolean value, String message) { if (!value) throw new AssertionError(message); }
    static String devNumber(int n) {
        StringBuilder out = new StringBuilder();
        for (char c : Integer.toString(n).toCharArray()) out.append((char)('०' + c - '0'));
        return out.toString();
    }
    public static void main(String[] args) throws Exception {
        check(PhoneticCandidates.lastResort("football", Collections.emptyList()).length() > 0, "explicit approximate mode offers a fallback");
        check(PhoneticCandidates.lastResort("football", Collections.singletonList("फुटबल")).isEmpty(), "indexed spellings have priority");
        check(PhoneticCandidates.lastResort("ab", Collections.emptyList()).isEmpty(), "short ambiguous word has no fallback");
        check(PhoneticCandidates.lastResort("abc.com", Collections.emptyList()).isEmpty(), "domain is never a phonetic fallback");
        check(PhoneticCandidates.lastResort("FOOTBALL", Collections.emptyList()).isEmpty(), "uppercase tokens are not guessed");
        RenderActionGuard actions = new RenderActionGuard();
        actions.invalidate();
        long priorKeyboard = actions.current();
        check(actions.accepts(priorKeyboard), "current rendered button accepted");
        actions.invalidate();
        long rerenderedKeyboard = actions.current();
        check(!actions.accepts(priorKeyboard), "queued tap from prior render rejected");
        check(actions.accepts(rerenderedKeyboard), "new render button accepted");
        actions.invalidate(); // onFinishInput invalidates even without a rerender
        check(!actions.accepts(rerenderedKeyboard), "queued tap after focus loss rejected");
        check(DisplaySettings.candidateLimit(2) == 2 && DisplaySettings.candidateLimit(3) == 3 && DisplaySettings.candidateLimit(4) == 4,
                "supported display limits retained");
        check(DisplaySettings.candidateLimit(-1) == 4 && DisplaySettings.candidateLimit(999) == 4,
                "invalid display settings use safe default");
        EditorSessionGuard guard = new EditorSessionGuard();
        check(guard.mayEdit(), "fresh editor accepts input");
        guard.ownershipUncertain();
        check(!guard.mayEdit(), "uncertain ownership blocks future edits");
        guard.start(true, false);
        check(!guard.mayEdit(), "restart cannot clear an uncertain host span");
        guard.start(false, false);
        check(guard.mayEdit(), "new input session permits edits");
        guard.start(true, true);
        check(!guard.mayEdit(), "restart with active composition must fail closed");
        guard.start(false, false);
        check(guard.mayEdit(), "new input after blocked restart is available");
        RecoveryBuffer recovery = new RecoveryBuffer();
        recovery.remember("secret", true);
        check(!recovery.available(), "literal/protected fields never populate recovery");
        recovery.remember("", false);
        recovery.remember("a b", false);
        recovery.remember("नमस्ते", false);
        check(!recovery.available(), "invalid or non-Roman recovery text is rejected");
        recovery.remember("pani", false);
        recovery.remember("newer", false);
        check(recovery.available() && "pani".equals(recovery.valueForExplicitCopy()), "first uncertain token retained without silent replacement");
        recovery.clear();
        check(!recovery.available() && recovery.valueForExplicitCopy() == null, "session end and successful copy clear recovery");
        recovery.remember(new String(new char[129]).replace('\0', 'a'), false);
        check(!recovery.available(), "recovery size is bounded");
        LanguagePreferences languages = new LanguagePreferences();
        check(languages.languageFor("com.a"), "new apps start Nepali");
        languages.remember("com.a", false, false);
        check(!languages.languageFor("com.a") && languages.languageFor("com.b"), "manual per-app isolation");
        check(Boolean.FALSE.equals(languages.explicitChoice("com.a")) && languages.explicitChoice("com.b") == null, "in-memory explicit choice is distinguishable from default");
        languages.remember("com.a", true, true);
        check(!languages.languageFor("com.a"), "literal-only field cannot change preference");
        languages.remember(null, false, false);
        for (int i = 0; i < 100; i++) languages.remember("package." + i, false, false);
        check(languages.size() == 64 && languages.languageFor("com.a"), "bounded in-memory LRU");
        VerifiedUndo undo = new VerifiedUndo();
        final String[] hostText = {"मेरो"};
        final int[] hostCaret = {4};
        final long[] hostSession = {11};
        final int[] calls = {0};
        VerifiedUndo.AtomicEditor editor = (expected, source, caret, token) -> {
            calls[0]++;
            if (hostSession[0] != token || hostCaret[0] != caret || !hostText[0].equals(expected)) return VerifiedUndo.Result.STALE;
            hostText[0] = source; hostCaret[0] = source.length();
            return VerifiedUndo.Result.APPLIED;
        };
        check(!undo.arm("mero", "मेरो", 4, 11, false), "unconfirmed commit cannot arm undo");
        check(undo.arm("mero", "मेरो", 4, 11, true), "confirmed commit arms guard");
        check(undo.undo(editor, 11) == VerifiedUndo.Result.APPLIED && hostText[0].equals("mero"), "atomic verified restore");
        check(undo.undo(editor, 11) == VerifiedUndo.Result.STALE && calls[0] == 1, "no duplicate retry");
        hostText[0] = "मेरो!"; hostCaret[0] = 5;
        check(undo.arm("mero", "मेरो", 4, 11, true), "arm stale scenario");
        check(undo.undo(editor, 11) == VerifiedUndo.Result.STALE && hostText[0].equals("मेरो!"), "changed text and caret preserved");
        check(undo.arm("mero", "मेरो", 4, 11, true), "arm focus scenario");
        check(undo.undo(editor, 12) == VerifiedUndo.Result.STALE && calls[0] == 2, "session change does not call host");
        check(undo.arm("mero", "मेरो", 4, 11, true), "arm unavailable scenario");
        check(undo.undo(null, 11) == VerifiedUndo.Result.UNAVAILABLE, "missing atomic editor refuses");
        check(undo.undo(editor, 11) == VerifiedUndo.Result.STALE, "unavailable is not retried");
        check(undo.arm("mero", "मेरो", 4, 11, true), "arm ambiguous scenario");
        check(undo.undo((a, b, c, d) -> VerifiedUndo.Result.UNKNOWN, 11) == VerifiedUndo.Result.UNKNOWN, "ambiguous result");
        check(undo.undo(editor, 11) == VerifiedUndo.Result.STALE, "ambiguous operation not retried");
        check(InputSafety.acceptsLookup(7, 7, "pani", "pani", true), "current result");
        check(!InputSafety.acceptsLookup(7, 8, "pani", "pani", true), "old generation");
        check(!InputSafety.acceptsLookup(7, 7, "pani", "pani", false), "inactive token");
        check(!InputSafety.acceptsLookup(7, 7, "pani", "pan", true), "changed token");
        check(InputSafety.acceptsCandidate(7, 7, "pani", "pani", true, true), "candidate current");
        check(!InputSafety.acceptsCandidate(7, 8, "pani", "pani", true, true), "same candidate stale generation");
        check(!InputSafety.acceptsCandidate(7, 7, "pani", "pana", true, true), "candidate old source");
        check(!InputSafety.acceptsCandidate(7, 7, "pani", "pani", true, false), "candidate absent from list");
        CandidatePreview preview = new CandidatePreview();
        List<String> alternatives = Arrays.asList("पनि", "पानी");
        check(preview.select("पनि", 7, 7, "pani", "pani", true, alternatives), "preview candidate");
        check("पनि".equals(preview.current(7, "pani", true, alternatives)), "preview without replacing original");
        check(preview.select("पानी", 7, 7, "pani", "pani", true, alternatives), "change candidate before commit");
        check("पानी".equals(preview.current(7, "pani", true, alternatives)), "alternative preview");
        check(preview.matchesDisplay(7, "pani", "पानी", 7, "pani", true, alternatives), "display matches current preview");
        check(!preview.matchesDisplay(7, "pani", "पनि", 7, "pani", true, alternatives), "queued old use/cancel cannot affect changed preview");
        check(!preview.matchesDisplay(6, "pani", "पानी", 7, "pani", true, alternatives), "queued use/cancel from older generation rejected");
        check(!preview.matchesDisplay(7, "pana", "पानी", 7, "pani", true, alternatives), "queued use/cancel from another token rejected");
        check(preview.current(8, "pani", true, alternatives) == null, "stale preview generation");
        check(preview.current(7, "pan", true, alternatives) == null, "changed original invalidates preview");
        check(preview.current(7, "pani", false, alternatives) == null, "focus loss invalidates preview");
        check(preview.current(7, "pani", true, Collections.singletonList("पनि")) == null, "updated list invalidates preview");
        preview.clear();
        check(preview.current(7, "pani", true, alternatives) == null, "discard preview to keep original");
        check(CandidatePages.pageCount(0, 2) == 0 && CandidatePages.pageCount(4, 2) == 2, "candidate pages");
        check(CandidatePages.pageCount(3, 2) == 2 && CandidatePages.offset(3, 2, 1) == 2, "partial last page");
        check(CandidatePages.offset(4, 2, -1) == -1 && CandidatePages.offset(4, 2, 2) == -1, "invalid candidate page");
        check(CandidatePages.acceptsChange(4, 4, "pani", "pani", true, 0, 0, 1, 4, 2), "current page navigation");
        check(!CandidatePages.acceptsChange(3, 4, "pani", "pani", true, 0, 0, 1, 4, 2), "stale generation cannot change page");
        check(!CandidatePages.acceptsChange(4, 4, "pana", "pani", true, 0, 0, 1, 4, 2), "old token cannot change page");
        check(!CandidatePages.acceptsChange(4, 4, "pani", "pani", true, 0, 1, 0, 4, 2), "old page button cannot change page");
        check(CandidatePages.displayed(Arrays.asList("a", "b", "c"), 2, 1, 1, "c"), "current candidate visible on last page");
        check(!CandidatePages.displayed(Arrays.asList("a", "b", "c"), 2, 0, 1, "a"), "queued candidate from previous page rejected");
        check(!CandidatePages.displayed(Arrays.asList("a", "b", "c"), 2, 1, 1, "a"), "hidden candidate rejected");
        for (int field : new int[]{0, 0x02, 0x12, 0x11, 0x21, 0x81, 0x91, 0xd1, 0xe1, 0xf1, 0x80001})
            check(InputSafety.literalOnly(field), "literal-only field " + field);
        for (int field : new int[]{0x01, 0x41, 0xa1, 0x20001})
            check(!InputSafety.literalOnly(field), "ordinary text field " + field);
        check(!InputSafety.selectionLosesOwnership(0, 0, 4, 4, 0, 4, 4), "at marked end");
        check(InputSafety.selectionLosesOwnership(4, 4, 2, 2, 0, 4, 4), "cursor moved");
        check(InputSafety.selectionLosesOwnership(4, 4, 0, 4, 0, 4, 4), "range selected");
        check(InputSafety.selectionLosesOwnership(4, 4, 2, 2, -1, -1, 4), "unknown range and move");
        check(InputSafety.selectionLosesOwnership(4, 4, 4, 4, -1, -1, 4), "stationary unknown range cannot prove ownership");
        check(InputSafety.selectionLosesOwnership(4, 4, 4, 4, 1, 4, 4), "wrong marked length");
        check(InputSafety.selectionLosesOwnership(4, 4, 1, 1, 6, 2, 4), "malformed range and move");
        check(InputSafety.editorAction(0x40000006, 0x40000000, 0xff, 1, 0) == 0, "host requests newline");
        check(InputSafety.editorAction(1, 0x40000000, 0xff, 1, 0) == 0, "no action");
        check(InputSafety.editorAction(6, 0x40000000, 0xff, 1, 0) == 6, "host action");
        FeedbackState feedback = new FeedbackState();
        check(feedback.notice() == FeedbackState.Notice.NONE && feedback.message().isEmpty(), "initial feedback");
        feedback.dictionariesUnavailable();
        check(feedback.notice() == FeedbackState.Notice.DICTIONARIES_UNAVAILABLE, "dictionary failure visible");
        feedback.editUncertain(); feedback.dictionariesUnavailable();
        check(feedback.notice() == FeedbackState.Notice.EDIT_UNCERTAIN, "host failure outranks dictionary warning");
        feedback.confirmedEdit();
        check(feedback.notice() == FeedbackState.Notice.EDIT_UNCERTAIN, "host warning remains after later edit");
        check(!feedback.message().contains("example.com"), "feedback does not include user text");
        feedback.clear();
        check(feedback.notice() == FeedbackState.Notice.NONE, "confirmed edit clears feedback");
        List<String> merged = new ArrayList<>();
        CandidateMerger.add(merged, Arrays.asList("फुटबल", "फुटवल"), 4);
        CandidateMerger.add(merged, Arrays.asList("फुटबल", "फूटबल"), 4);
        CandidateMerger.add(merged, Arrays.asList("फुटवल", "फुटबल्", "अन्य"), 4);
        check(merged.equals(Arrays.asList("फुटबल", "फुटवल", "फूटबल", "फुटबल्")), "source order, de-duplication and cap");
        List<String> safe = new ArrayList<>();
        CandidateMerger.add(safe, Arrays.asList("bad\ntext", "bad\u202etext", "\ud800", "ने\u200dपाली", "😀"), 4);
        check(safe.equals(Arrays.asList("ने\u200dपाली", "😀")), "reject control, bidi and malformed index candidates");
        check(!CandidateMerger.safe(new String(new char[257]).replace('\0', 'a')), "oversized candidate rejected");
        Composition c = new Composition();
        check(c.accepts("m") && c.text().isEmpty(), "propose without mutation");
        check(c.append("m") && c.append("a"), "append");
        try { c.setNepali(false); throw new AssertionError("discard guard"); } catch (IllegalStateException expected) { }
        check(c.backspace() && c.text().equals("m"), "delete");
        check(c.takeOriginal().equals("m"), "original");
        c.setNepali(false); check(!c.append("a"), "English pass-through");
        c.setNepali(true);
        for (int i = 0; i < 128; i++) check(c.append("a"), "bounded token " + i);
        check(!c.accepts("a") && c.text().length() == 128, "bounded token does not discard source");
        check(c.takeOriginal().length() == 128, "bounded original preserved");
        Path file = Files.createTempFile("neptype-index", ".tsv");
        try {
            String data = "PADDING" + "aa\tआ\tआँ\naa\tआए\nma\tम\npani\tपानी\nz\tज" + "TRAIL";
            Files.write(file, data.getBytes(StandardCharsets.UTF_8));
            long length = data.getBytes(StandardCharsets.UTF_8).length - 12;
            try (FileChannel channel = FileChannel.open(file)) {
                SortedCandidateIndex index = new SortedCandidateIndex(channel, 7, length);
                check(index.lookup("aa", 5).equals(Arrays.asList("आ", "आँ", "आए")), "duplicates and first line");
                check(index.lookup("MA", 5).equals(Collections.singletonList("म")), "case and middle");
                check(index.lookup("z", 5).equals(Collections.singletonList("ज")), "last no newline");
                check(index.lookup("ab", 5).isEmpty() && index.lookup("zz", 5).isEmpty(), "missing keys");
                check(index.lookup("site.com", 5).isEmpty(), "literal safety");
                check(index.lookup("aa", 1).size() == 1, "limit");
            }
        } finally { Files.deleteIfExists(file); }
        Path randomized = Files.createTempFile("neptype-random-index", ".tsv");
        try {
            Random random = new Random(71);
            SortedMap<String,String> oracle = new TreeMap<>();
            while (oracle.size() < 600) {
                int size = 1 + random.nextInt(10);
                StringBuilder key = new StringBuilder();
                for (int i = 0; i < size; i++) key.append((char)('a' + random.nextInt(26)));
                oracle.put(key.toString(), "नेपाल" + devNumber(oracle.size()));
            }
            StringBuilder rows = new StringBuilder();
            for (Map.Entry<String,String> e : oracle.entrySet()) rows.append(e.getKey()).append('\t').append(e.getValue()).append('\n');
            Files.write(randomized, rows.toString().getBytes(StandardCharsets.UTF_8));
            try (FileChannel channel = FileChannel.open(randomized)) {
                SortedCandidateIndex index = new SortedCandidateIndex(channel, 0, channel.size());
                for (Map.Entry<String,String> e : oracle.entrySet())
                    check(index.lookup(e.getKey(), 4).equals(Collections.singletonList(e.getValue())), "random lookup " + e.getKey());
                for (int i = 0; i < 100; i++) check(index.lookup("nonexistent" + i, 4).isEmpty(), "unsafe input");
            }
        } finally { Files.deleteIfExists(randomized); }
        // Force a UTF-8 row, line break and key search across multiple 4 KiB
        // windows, while segment padding cannot be read as index contents.
        Path windows = Files.createTempFile("neptype-window-index", ".tsv");
        try {
            StringBuilder content = new StringBuilder("PAD");
            for (int i = 0; i < 700; i++) {
                int n = i;
                StringBuilder key = new StringBuilder();
                for (int p = 0; p < 4; p++) { key.insert(0, (char)('a' + n % 26)); n /= 26; }
                content.append(key).append('\t').append("नेपाली").append(devNumber(i)).append('\n');
            }
            byte[] data = (content.toString() + "TAIL").getBytes(StandardCharsets.UTF_8);
            Files.write(windows, data);
            try (FileChannel channel = FileChannel.open(windows)) {
                SortedCandidateIndex index = new SortedCandidateIndex(channel, 3, data.length - 7);
                check(index.lookup("aaaa", 4).equals(Collections.singletonList("नेपाली०")), "first window");
                check(index.lookup("aazx", 4).equals(Collections.singletonList("नेपाली६७३")), "multiblock window");
                check(index.lookup("z", 4).isEmpty(), "segment suffix ignored");
                java.util.concurrent.ExecutorService executor = java.util.concurrent.Executors.newFixedThreadPool(4);
                try {
                    List<java.util.concurrent.Future<Boolean>> futures = new ArrayList<>();
                    for (int worker = 0; worker < 4; worker++) futures.add(executor.submit(() -> {
                        for (int i = 0; i < 100; i++) {
                            if (!index.lookup("aazx", 4).equals(Collections.singletonList("नेपाली६७३"))) return false;
                            if (!index.lookup("aaaa", 4).equals(Collections.singletonList("नेपाली०"))) return false;
                        }
                        return true;
                    }));
                    for (java.util.concurrent.Future<Boolean> future : futures) check(future.get(), "per-lookup buffer isolation");
                } finally { executor.shutdownNow(); }
                boolean truncated = false;
                try { new SortedCandidateIndex(channel, 0, data.length + 9000L).lookup("zzzz", 4); }
                catch (java.io.IOException expected) { truncated = true; }
                check(truncated, "truncated asset segment rejected");
                boolean overflow = false;
                try { new SortedCandidateIndex(channel, Long.MAX_VALUE, 1); }
                catch (IllegalArgumentException expected) { overflow = true; }
                check(overflow, "overflowing segment rejected");
            }
        } finally { Files.deleteIfExists(windows); }
        Path corrupt = Files.createTempFile("neptype-corrupt-index", ".tsv");
        try {
            List<String> badRows = Arrays.asList(
                "bad\tम\tASCII\n", "bad\tम\t\n", "bad\tम\t" + new String(new char[61]).replace('\0', 'क') + "\n",
                "bad\t" + String.join("\t", Collections.nCopies(65, "म")) + "\n",
                "bad\tम\t" + new String(new char[4097]).replace('\0', 'क') + "\n");
            for (String row : badRows) {
                Files.write(corrupt, row.getBytes(StandardCharsets.UTF_8));
                try (FileChannel channel = FileChannel.open(corrupt)) {
                    boolean rejected;
                    try { rejected = new SortedCandidateIndex(channel, 0, channel.size()).lookup("bad", 1).isEmpty(); }
                    catch (java.io.IOException expected) { rejected = true; }
                    check(rejected, "corrupt whole row rejected even beyond display limit");
                }
            }
            byte[] invalidUtf8 = new byte[]{'b','a','d','\t',(byte)0xff,'\n'};
            Files.write(corrupt, invalidUtf8);
            try (FileChannel channel = FileChannel.open(corrupt)) {
                check(new SortedCandidateIndex(channel, 0, channel.size()).lookup("bad", 4).isEmpty(), "invalid UTF-8 rejected");
            }
        } finally { Files.deleteIfExists(corrupt); }
        System.out.println("PASS: Android candidate index and composition tests");
    }
}
