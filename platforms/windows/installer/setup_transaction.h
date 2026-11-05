#pragma once
#include <stdexcept>
#include <string>

namespace neptype::setup {
struct State {
    std::wstring active, transaction, previous_active, previous_registration, target;
};
class Host {
public:
    virtual ~Host() = default;
    virtual State read() = 0;
    virtual void write(const State&) = 0;
    virtual std::wstring registration() = 0;
    virtual bool owned(const std::wstring&) = 0;
    virtual std::wstring stage(const std::wstring& source, const std::wstring& version, const State&) = 0;
    virtual void register_at(const std::wstring&) = 0;
    virtual void unregister_at(const std::wstring&) = 0;
    virtual bool profile_present() = 0;
    virtual bool cleanup() = 0; // true means a restart is required
};
class Transaction {
    Host& host_;
public:
    explicit Transaction(Host& host):host_(host) {}
    void rollback(const std::wstring& token) {
        auto state=host_.read();
        if(state.transaction.empty()) return;
        if(token!=state.transaction) throw std::runtime_error("Another keyboard setup transaction is pending");
        const auto current=host_.registration();
        if(!host_.owned(current) || !host_.owned(state.previous_registration) || !host_.owned(state.target))
            throw std::runtime_error("Keyboard registration changed outside this installer; files were kept");
        if(current==state.target && current!=state.previous_registration) {
            if(state.previous_registration.empty()) host_.unregister_at(state.target);
            else host_.register_at(state.previous_registration);
        } else if(current!=state.previous_registration) {
            throw std::runtime_error("Keyboard registration changed during setup; files were kept");
        }
        if(host_.registration()!=state.previous_registration)
            throw std::runtime_error("Previous keyboard registration could not be restored; files were kept");
        State previous; previous.active=state.previous_active; host_.write(previous);
    }
    void recover() {
        const auto state=host_.read();
        if(!state.transaction.empty()) rollback(state.transaction);
    }
    void begin(const std::wstring& source,const std::wstring& version,const std::wstring& token) {
        if(token.empty()) throw std::runtime_error("A setup transaction ID is required");
        recover();
        auto state=host_.read();
        const auto current=host_.registration();
        if(!host_.owned(current)) throw std::runtime_error("A different keyboard registration is present; it was not changed");
        const auto target=host_.stage(source,version,state);
        State pending=state;
        pending.transaction=token; pending.previous_active=state.active;
        pending.previous_registration=current; pending.target=target;
        // The recovery journal is durable before COM registration changes.
        host_.write(pending);
        try { host_.register_at(target); }
        catch (...) { rollback(token); throw; }
        if(host_.registration()!=target) { rollback(token); throw std::runtime_error("Keyboard registration did not select the staged files"); }
    }
    void commit(const std::wstring& token) {
        auto state=host_.read();
        if(state.transaction!=token || token.empty()) throw std::runtime_error("Keyboard setup transaction does not match");
        if(host_.registration()!=state.target) throw std::runtime_error("Keyboard registration changed before setup finished");
        State complete; complete.active=state.target; host_.write(complete);
    }
    bool uninstall() {
        recover(); auto state=host_.read(); const auto current=host_.registration();
        if(!host_.owned(current)) throw std::runtime_error("A different keyboard registration is present; no files were removed");
        host_.unregister_at(current.empty()?state.active:current);
        if(!host_.registration().empty() || host_.profile_present())
            throw std::runtime_error("Keyboard unregistration is incomplete; files were kept");
        host_.write({});
        return host_.cleanup();
    }
};
}
