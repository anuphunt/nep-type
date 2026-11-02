package app.neptype.keyboard.core;

import java.util.Objects;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.RejectedExecutionException;

/** One running and at most one pending lookup. The pending lookup is replaced
 * by the newest request; no token or app identity is stored after execution.
 * Callers must still reject stale results on their UI thread. */
public final class LatestLookupScheduler implements AutoCloseable {
    private final ExecutorService executor;
    private Runnable pending;
    private boolean draining;
    private boolean closed;

    public LatestLookupScheduler() { this(Executors.newSingleThreadExecutor()); }
    public LatestLookupScheduler(ExecutorService executor) { this.executor = Objects.requireNonNull(executor); }

    public synchronized boolean submit(Runnable task) {
        Objects.requireNonNull(task);
        if (closed) return false;
        pending = task;
        if (!draining) {
            draining = true;
            try { executor.execute(this::drain); }
            catch (RejectedExecutionException ex) { draining = false; pending = null; return false; }
        }
        return true;
    }

    /** Drop queued work when composition ownership changes. Running work may
     * complete; its result must still pass the caller's generation guard. */
    public synchronized void clearPending() { pending = null; }

    private void drain() {
        while (true) {
            Runnable next;
            synchronized (this) {
                if (closed || pending == null) { draining = false; return; }
                next = pending;
                pending = null;
            }
            try { next.run(); }
            catch (RuntimeException ignored) {
                // A failed lookup must not permanently block later requests.
                // The UI retains the original until another lookup succeeds.
            }
        }
    }

    @Override public synchronized void close() {
        if (closed) return;
        closed = true;
        pending = null;
        executor.shutdownNow();
    }
}
