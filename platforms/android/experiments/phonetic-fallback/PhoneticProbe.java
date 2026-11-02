import app.neptype.keyboard.core.PhoneticCandidates;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;

public final class PhoneticProbe {
    public static void main(String[] args) throws Exception {
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(System.in, StandardCharsets.UTF_8))) {
            for (String line; (line = reader.readLine()) != null;) {
                System.out.println(PhoneticCandidates.suggest(line));
            }
        }
    }
}
