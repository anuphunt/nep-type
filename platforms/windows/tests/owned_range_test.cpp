#include "owned_range.h"
#include <algorithm>
#include <cassert>
#include <iostream>

using namespace neptype;
struct Doc { std::u16string text; std::size_t start=0, end=0, caret=0; bool selected=false, ended=false, fail_set=false; };
struct Range final : ITfRange {
    Doc* d; std::size_t start,end; ULONG refs=1;
    Range(Doc* doc, std::size_t a, std::size_t b):d(doc),start(a),end(b) {}
    HRESULT QueryInterface(REFIID,void**) override { return E_NOINTERFACE; }
    ULONG AddRef() override { return ++refs; }
    ULONG Release() override { auto n=--refs; if (!n) delete this; return n; }
    HRESULT IsEmpty(TfEditCookie,BOOL* x) override { *x=start==end; return S_OK; }
    HRESULT CompareStart(TfEditCookie,ITfRange* other,TfAnchor,LONG* r) override {
        auto* b=dynamic_cast<Range*>(other); if (!b) return E_FAIL;
        *r=start==b->end?0:(start<b->end?-1:1); return S_OK;
    }
    HRESULT GetText(TfEditCookie,DWORD,WCHAR* out,ULONG cap,ULONG* n) override {
        *n=static_cast<ULONG>(std::min<std::size_t>(cap,end-start));
        std::copy_n(d->text.begin()+static_cast<std::ptrdiff_t>(start),*n,out); return S_OK;
    }
    HRESULT SetText(TfEditCookie,DWORD,const WCHAR* text,LONG n) override {
        if (d->fail_set) return E_FAIL;
        d->text.replace(start,end-start,text,static_cast<std::size_t>(n)); d->start=start; d->end=start+static_cast<std::size_t>(n); end=d->end; return S_OK;
    }
    HRESULT Clone(ITfRange** out) override { *out=new Range(d,start,end); return S_OK; }
    HRESULT Collapse(TfEditCookie,TfAnchor a) override { if(a==TF_ANCHOR_END) start=end; else end=start; return S_OK; }
};
struct CompositionMock final : ITfComposition {
    Doc* d; ULONG refs=1;
    explicit CompositionMock(Doc* doc):d(doc) {}
    HRESULT QueryInterface(REFIID,void**) override { return E_NOINTERFACE; }
    ULONG AddRef() override { return ++refs; }
    ULONG Release() override { auto n=--refs; if(!n) delete this; return n; }
    HRESULT GetRange(ITfRange** out) override { if(d->ended) return E_FAIL; *out=new Range(d,d->start,d->end); return S_OK; }
    HRESULT EndComposition(TfEditCookie) override { d->ended=true; return S_OK; }
};
struct Manager final : ITfContextComposition {
    Doc* d; ULONG refs=1; bool reject=false;
    explicit Manager(Doc* doc):d(doc) {}
    HRESULT QueryInterface(REFIID,void**) override { return E_NOINTERFACE; }
    ULONG AddRef() override { return ++refs; }
    ULONG Release() override { return --refs; }
    HRESULT StartComposition(TfEditCookie,ITfRange*,void*,ITfComposition** out) override {
        if(reject) { *out=nullptr; return S_OK; } d->start=d->end=d->caret; *out=new CompositionMock(d); return S_OK;
    }
};
struct Context final : ITfContext {
    Doc d; Manager manager{&d}; ULONG refs=1; bool fail_selection=false;
    HRESULT QueryInterface(REFIID iid,void** out) override { if(!IsEqualIID(iid,IID_ITfContextComposition)) return E_NOINTERFACE; *out=&manager; manager.AddRef(); return S_OK; }
    ULONG AddRef() override { return ++refs; }
    ULONG Release() override { return --refs; }
    HRESULT RequestEditSession(TfClientId,ITfEditSession*,DWORD,HRESULT*) override { return E_FAIL; }
    HRESULT GetSelection(TfEditCookie,ULONG,ULONG,TF_SELECTION* out,ULONG* n) override { *n=1; out->range=new Range(&d,d.caret,d.caret+(d.selected?1:0)); return S_OK; }
    HRESULT SetSelection(TfEditCookie,ULONG,const TF_SELECTION* s) override { if(fail_selection) return E_FAIL; d.caret=dynamic_cast<Range*>(s->range)->start; return S_OK; }
};
int main() {
    Context c; c.d.text=u"prefix suffix"; c.d.caret=7;
    { OwnedRange host(&c); Context different; assert(host.owns_context(&c)); assert(!host.owns_context(&different));
      assert(host.apply(1,{Kind::Mark,1,u"ma",false}));
      assert(c.d.text==u"prefix masuffix" && c.d.caret==9);
      assert(host.apply(1,{Kind::Mark,2,u"म",false}));
      assert(c.d.text==u"prefix मsuffix" && c.d.caret==8);
      assert(host.apply(1,{Kind::Commit,3,u"म",false}));
      assert(c.d.ended && c.d.text==u"prefix मsuffix"); }
    Context selected; selected.d.text=u"protected"; selected.d.selected=true;
    { OwnedRange host(&selected); assert(!host.apply(1,{Kind::Mark,1,u"x",false})); assert(selected.d.text==u"protected"); assert(!host.usable()); }
    Context moved; { OwnedRange host(&moved); assert(host.apply(1,{Kind::Mark,1,u"ma",false})); moved.d.caret=0;
      assert(!host.apply(1,{Kind::Commit,2,u"म",false})); assert(moved.d.text==u"ma"); }
    Context altered; { OwnedRange host(&altered); assert(host.apply(1,{Kind::Mark,1,u"ma",false})); altered.d.text=u"xx";
      assert(!host.apply(1,{Kind::Commit,2,u"म",false})); assert(altered.d.text==u"xx"); }
    Context terminated; { OwnedRange host(&terminated); assert(host.apply(1,{Kind::Mark,1,u"ma",false})); terminated.d.ended=true;
      assert(!host.apply(1,{Kind::Commit,2,u"म",false})); assert(terminated.d.text==u"ma"); }
    Context rejected; rejected.manager.reject=true; { OwnedRange host(&rejected); assert(!host.apply(1,{Kind::Mark,1,u"ma",false})); assert(rejected.d.text.empty()); }
    Context invalid; { OwnedRange host(&invalid); assert(!host.apply(1,{Kind::Mark,1,std::u16string(1,0xd800),false})); assert(invalid.d.text.empty()); }
    Context uncertain; uncertain.fail_selection=true; { OwnedRange host(&uncertain); assert(!host.apply(1,{Kind::Mark,1,u"ma",false}));
      assert(!host.usable()); assert(!host.apply(1,{Kind::Mark,2,u"x",false})); assert(uncertain.d.text==u"ma"); }
    std::cout << "PASS: owned range, caret, changed text, rejected composition and no retry\n";
}
