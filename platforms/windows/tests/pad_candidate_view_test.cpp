#include "pad_candidate_view.hpp"
#include <cassert>

int main() {
    neptype::PadCandidateView row{42,L"ma pani",3,7,3,4,true};
    assert(row.matches(42,L"ma pani",3,7));
    assert(!row.matches(43,L"ma pani",3,7)); // a newer lookup is pending
    assert(!row.matches(42,L"ma mero",3,7)); // text changed before notification
    assert(!row.matches(42,L"ma pani",0,0)); // same text, a different token
    assert(!row.matches(42,L"ma pani",7,7)); // selection changed within same token
    row.ready=false;
    assert(!row.matches(42,L"ma pani",3,7));
    row.ready=true; row.selectionStart=0;
    assert(!row.matches(42,L"ma pani",0,7)); // multiple words selected
    row.selectionStart=3; row.tokenStart=-1;
    assert(!row.matches(42,L"ma pani",3,7)); // no active token
    row.tokenStart=3; row.tokenLength=0;
    assert(!row.matches(42,L"ma pani",3,7));
}
