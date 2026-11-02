import app.lekha.keyboard.core.PersistentLanguagePreferences;
import java.util.concurrent.CountDownLatch;

public final class PersistenceTest {
    private static void check(boolean b, String message) { if (!b) throw new AssertionError(message); }
    static final class MemoryStore implements PersistentLanguagePreferences.Store {
        boolean enabled, fail; String snapshot;
        public boolean enabled() { return enabled; }
        public String snapshot() { return snapshot; }
        public boolean commit(boolean on, String value) { if (fail) return false; enabled = on; snapshot = value; return true; }
    }
    public static void main(String[] args) throws Exception {
        MemoryStore s = new MemoryStore();
        check(PersistentLanguagePreferences.remember(s,"com.alpha",false,false), "off is no-op");
        check(s.snapshot == null && PersistentLanguagePreferences.lookup(s,"com.alpha") == null, "off stores nothing");
        check(PersistentLanguagePreferences.setEnabled(s,true), "explicit opt in");
        check(PersistentLanguagePreferences.remember(s,"com.alpha",false,false), "manual save");
        check(Boolean.FALSE.equals(PersistentLanguagePreferences.lookup(s,"com.alpha")), "saved mode");
        String snapshot=s.snapshot;
        PersistentLanguagePreferences.remember(s,"com.secret",true,true);
        PersistentLanguagePreferences.remember(s,"sensitive text",true,false);
        check(snapshot.equals(s.snapshot), "literal and invalid identities never stored");
        s.snapshot="v1\ncom.alpha\tE\ninvalid token\tN\n";
        check(PersistentLanguagePreferences.lookup(s,"com.alpha") == null, "reject entire corrupt snapshot");
        s.snapshot="v1\ncom.alpha\tE\ncom.alpha\tN\n";
        check(PersistentLanguagePreferences.lookup(s,"com.alpha") == null, "reject duplicate identities");
        s.snapshot="v2\ncom.alpha\tE\n";
        check(PersistentLanguagePreferences.lookup(s,"com.alpha") == null, "reject unknown version");
        s.snapshot="v1\ncom.alpha\tE";
        check(PersistentLanguagePreferences.lookup(s,"com.alpha") == null, "reject truncated snapshot");
        s.snapshot=new String(new char[17001]).replace('\0','x');
        check(PersistentLanguagePreferences.lookup(s,"com.alpha") == null, "reject oversized snapshot");
        PersistentLanguagePreferences.Store broken = new PersistentLanguagePreferences.Store() {
            public boolean enabled() { throw new ClassCastException("bad stored type"); }
            public String snapshot() { return null; }
            public boolean commit(boolean enabled, String snapshot) { throw new IllegalStateException("unavailable"); }
        };
        check(!PersistentLanguagePreferences.isEnabled(broken), "corrupt enable type fails closed");
        check(PersistentLanguagePreferences.lookup(broken,"com.alpha") == null, "unavailable storage lookup");
        check(!PersistentLanguagePreferences.setEnabled(broken,true), "unavailable storage save reported");
        s.snapshot=null;
        final CountDownLatch start = new CountDownLatch(1); Thread[] threads=new Thread[32];
        for(int i=0;i<threads.length;i++){final int n=i; threads[i]=new Thread(() -> {try{start.await();}catch(InterruptedException ex){throw new RuntimeException(ex);} check(PersistentLanguagePreferences.remember(s,"com.app"+n,false,false),"concurrent write");}); threads[i].start();}
        start.countDown(); for(Thread t:threads)t.join();
        for(int i=0;i<threads.length;i++)check(Boolean.FALSE.equals(PersistentLanguagePreferences.lookup(s,"com.app"+i)),"no lost concurrent write");
        for(int i=32;i<100;i++)PersistentLanguagePreferences.remember(s,"com.app"+i,false,false);
        check(PersistentLanguagePreferences.lookup(s,"com.app0")==null && Boolean.FALSE.equals(PersistentLanguagePreferences.lookup(s,"com.app99")),"bounded eviction");
        s.fail=true; check(!PersistentLanguagePreferences.setEnabled(s,false),"failed write reported");
        s.fail=false; check(PersistentLanguagePreferences.setEnabled(s,false) && s.snapshot==null && !s.enabled,"opt out clears choices");
        System.out.println("PASS: opt-in persistence, corruption, field exclusion, concurrency, bounds and opt-out");
    }
}
