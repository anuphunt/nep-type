import app.neptype.keyboard.core.SharedEngine;
import java.nio.charset.StandardCharsets;
public final class SharedEngineProbe {
    static String hex(String value) {
        StringBuilder out = new StringBuilder();
        for (byte b : value.getBytes(StandardCharsets.UTF_8)) out.append(String.format(java.util.Locale.ROOT,"%02x",b & 255));
        return out.toString();
    }
    public static void main(String[] args) {
        try (SharedEngine engine = new SharedEngine(args[0])) {
            if (args[1].equals("--dictionary-id")) { System.out.println(SharedEngine.dictionaryId()); return; }
            for (int i=2;i<args.length;i++) {
                StringBuilder line = new StringBuilder();
                for (String value : engine.candidates(args[i],Integer.parseInt(args[1]))) {
                    if (line.length()>0) line.append('\t');
                    line.append(hex(value));
                }
                System.out.println(line);
            }
        }
    }
}
