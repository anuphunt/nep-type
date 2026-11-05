#include "setup_transaction.h"
#include <cassert>
#include <algorithm>
#include <functional>
#include <iostream>
#include <vector>
using namespace neptype::setup;
struct Fake final:Host {
    State state; std::wstring pointer;
    bool profile=false, fail_stage=false, fail_write=false, fail_register=false, fail_unregister=false, restart=false, fail_after_register=false, fail_restore=false;
    std::vector<std::string> events;
    State read() override { return state; }
    void write(const State& next) override { events.push_back("journal"); if(fail_write) throw std::runtime_error("disk full"); state=next; }
    std::wstring registration() override { return pointer; }
    bool owned(const std::wstring& path) override { return path.empty() || path.rfind(L"protected/",0)==0; }
    std::wstring stage(const std::wstring&,const std::wstring&,const State&) override { events.push_back("stage"); if(fail_stage) throw std::runtime_error("bad hash"); return L"protected/new"; }
    void register_at(const std::wstring& path) override { events.push_back("register"); if((fail_register && path==L"protected/new") || (fail_restore && path==L"protected/old")) throw std::runtime_error("registration denied"); pointer=path; profile=true; if(fail_after_register && path==L"protected/new") throw std::runtime_error("post-registration failure"); }
    void unregister_at(const std::wstring&) override { events.push_back("unregister"); if(fail_unregister) throw std::runtime_error("denied"); pointer.clear(); profile=false; }
    bool profile_present() override { return profile; }
    bool cleanup() override { events.push_back("cleanup"); assert(pointer.empty() && !profile); return restart; }
};
static bool fails(const std::function<void()>& work) { try { work(); } catch(...) { return true; } return false; }
int main() {
    Fake clean; Transaction tx(clean); tx.begin(L"payload",L"v1",L"first");
    assert(clean.events==std::vector<std::string>({"stage","journal","register"}));
    assert(clean.pointer==L"protected/new" && clean.state.active.empty());
    tx.commit(L"first"); assert(clean.state.active==clean.pointer && clean.state.transaction.empty());
    Fake failed; failed.pointer=L"protected/old"; failed.profile=true; failed.state.active=failed.pointer; failed.fail_register=true;
    Transaction broken(failed); assert(fails([&]{broken.begin(L"payload",L"v2",L"failure");}));
    assert(failed.pointer==L"protected/old" && failed.state.active==failed.pointer && failed.state.transaction.empty());
    Fake partial; partial.pointer=L"protected/old"; partial.profile=true; partial.state.active=partial.pointer; partial.fail_after_register=true;
    Transaction partial_tx(partial); assert(fails([&]{partial_tx.begin(L"payload",L"v2",L"partial");}));
    assert(partial.pointer==L"protected/old" && partial.state.transaction.empty());
    Fake damaged; damaged.pointer=L"protected/old"; damaged.profile=true; damaged.state.active=damaged.pointer;
    Transaction damaged_tx(damaged); damaged_tx.begin(L"payload",L"v2",L"recoverable"); damaged.fail_restore=true;
    assert(fails([&]{damaged_tx.recover();}) && damaged.pointer==L"protected/new" && damaged.state.transaction==L"recoverable");
    assert(std::find(damaged.events.begin(),damaged.events.end(),"cleanup")==damaged.events.end());
    Fake crash; crash.pointer=L"protected/old"; crash.profile=true; crash.state.active=crash.pointer;
    Transaction recovery(crash); recovery.begin(L"payload",L"v2",L"interrupted"); recovery.recover();
    assert(crash.pointer==L"protected/old" && crash.state.active==crash.pointer);
    Fake fresh; Transaction first(fresh); first.begin(L"payload",L"v1",L"cancel"); first.rollback(L"cancel");
    assert(fresh.pointer.empty() && !fresh.profile && fresh.state.transaction.empty());
    Fake foreign; foreign.pointer=L"another-product/service.dll"; Transaction other(foreign);
    assert(fails([&]{other.begin(L"payload",L"v1",L"x");}) && foreign.events.empty());
    assert(fails([&]{other.uninstall();}) && foreign.events.empty());
    Fake race; Transaction racing(race); racing.begin(L"payload",L"v1",L"owned"); race.pointer=L"another-product/new.dll";
    assert(fails([&]{racing.rollback(L"owned");}) && !race.state.transaction.empty());
    assert(fails([&]{racing.commit(L"owned");}));
    Fake mismatch; Transaction mismatch_tx(mismatch); mismatch_tx.begin(L"payload",L"v1",L"a");
    assert(fails([&]{mismatch_tx.rollback(L"b");}) && mismatch.pointer==L"protected/new");
    Fake disk; disk.fail_write=true; Transaction full(disk);
    assert(fails([&]{full.begin(L"payload",L"v1",L"x");}) && disk.pointer.empty());
    Fake removal; removal.pointer=L"protected/old"; removal.state.active=removal.pointer; removal.profile=true; removal.fail_unregister=true;
    Transaction remove(removal); assert(fails([&]{remove.uninstall();}) && removal.events==std::vector<std::string>({"unregister"}));
    assert(removal.state.active==L"protected/old");
    removal.fail_unregister=false; removal.restart=true; assert(remove.uninstall());
    assert(removal.pointer.empty() && removal.state.active.empty() && removal.events.back()=="cleanup");
    std::cout<<"PASS: staged install, durable journal, rollback/recovery, foreign registration, write failure and unregister-before-delete\n";
}
