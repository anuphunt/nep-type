import app.lekha.keyboard.core.LatestLookupScheduler;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

public final class LatestLookupSchedulerTest {
    private static void check(boolean ok, String message) {
        if (!ok) throw new AssertionError(message);
    }
    private static void await(CountDownLatch latch, String message) throws Exception {
        check(latch.await(3, TimeUnit.SECONDS), message);
    }
    public static void main(String[] args) throws Exception {
        LatestLookupScheduler scheduler = new LatestLookupScheduler();
        CountDownLatch started = new CountDownLatch(1), release = new CountDownLatch(1), finished = new CountDownLatch(1);
        List<Integer> seen = Collections.synchronizedList(new ArrayList<Integer>());
        scheduler.submit(() -> {
            started.countDown();
            try { release.await(); } catch (InterruptedException e) { Thread.currentThread().interrupt(); }
            seen.add(0);
        });
        await(started, "first lookup did not start");
        for (int i = 1; i < 1000; i++) { final int value = i; scheduler.submit(() -> seen.add(value)); }
        scheduler.submit(() -> { seen.add(1000); finished.countDown(); });
        release.countDown();
        await(finished, "latest lookup did not finish");
        check(seen.size() == 2 && seen.get(0) == 0 && seen.get(1) == 1000,
                "obsolete requests accumulated or executed: " + seen.size());

        CountDownLatch started2 = new CountDownLatch(1), release2 = new CountDownLatch(1), after = new CountDownLatch(1);
        scheduler.submit(() -> {
            started2.countDown();
            try { release2.await(); } catch (InterruptedException e) { Thread.currentThread().interrupt(); }
        });
        await(started2, "second lookup did not start");
        scheduler.submit(() -> seen.add(-1));
        scheduler.clearPending();
        scheduler.submit(after::countDown);
        release2.countDown();
        await(after, "post-clear request did not run");
        check(!seen.contains(-1), "cleared request ran");

        CountDownLatch failingStarted = new CountDownLatch(1), fail = new CountDownLatch(1), recovered = new CountDownLatch(1);
        scheduler.submit(() -> {
            failingStarted.countDown();
            try { fail.await(); } catch (InterruptedException e) { Thread.currentThread().interrupt(); }
            throw new IllegalStateException("synthetic lookup failure");
        });
        await(failingStarted, "failing lookup did not start");
        scheduler.submit(recovered::countDown);
        fail.countDown();
        await(recovered, "scheduler did not recover after an exception");

        scheduler.close();
        check(!scheduler.submit(() -> seen.add(-2)), "closed scheduler accepted work");
        System.out.println("PASS: latest-only lookup, pending clear, failure recovery and shutdown");
    }
}
