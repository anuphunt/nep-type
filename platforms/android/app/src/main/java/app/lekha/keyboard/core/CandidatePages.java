package app.lekha.keyboard.core;

import java.util.List;

/** Bounded candidate-page arithmetic, independent of Android UI classes. */
public final class CandidatePages {
    private CandidatePages() { }

    public static int pageCount(int itemCount, int pageSize) {
        if (itemCount <= 0 || pageSize <= 0) return 0;
        return 1 + (itemCount - 1) / pageSize;
    }

    /** Returns -1 for an invalid or obsolete page instead of silently wrapping. */
    public static int offset(int itemCount, int pageSize, int page) {
        int count = pageCount(itemCount, pageSize);
        if (page < 0 || page >= count) return -1;
        return page * pageSize;
    }

    public static boolean acceptsChange(long shownGeneration, long currentGeneration,
                                        String shownToken, String currentToken, boolean active,
                                        int shownPage, int currentPage, int requestedPage,
                                        int itemCount, int pageSize) {
        return InputSafety.acceptsCandidate(shownGeneration, currentGeneration,
                shownToken, currentToken, active, true)
                && shownPage == currentPage && requestedPage != currentPage
                && offset(itemCount, pageSize, requestedPage) >= 0;
    }

    public static boolean displayed(List<String> items, int pageSize, int shownPage,
                                    int currentPage, String candidate) {
        if (items == null || candidate == null || shownPage != currentPage) return false;
        int start = offset(items.size(), pageSize, currentPage);
        if (start < 0) return false;
        for (int i = start; i < Math.min(start + pageSize, items.size()); i++) {
            if (candidate.equals(items.get(i))) return true;
        }
        return false;
    }
}
