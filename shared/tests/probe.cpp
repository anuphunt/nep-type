#include "../cpp/engine.hpp"
#include "../cpp/pad_worker.hpp"
#include <cassert>
#include <iostream>
#include <chrono>
static std::string hex(const std::string& s) {
    const char* digits="0123456789abcdef"; std::string out;
    for(unsigned char c:s) { out+=digits[c>>4]; out+=digits[c&15]; } return out;
}
int main(int argc,char** argv) {
    if(argc<4) return 2;
    neptype::Engine engine(argv[1],argv[2]);
    if (std::string(argv[3])=="--dictionary-id") { std::cout<<engine.dictionary_id()<<"\n"; return 0; }
    for(int i=4;i<argc;++i) {
        auto values=engine.candidates(argv[i],std::stoi(argv[3]));
        for(size_t n=0;n<values.size();++n) std::cout<<(n ? "\t" : "")<<hex(values[n]);
        std::cout<<"\n";
    }
    auto doc=engine.document("namaste! ma office janchu.",0,3);
    assert(doc.output=="नमस्ते! ma office janchu.");
    assert(doc.token=="namaste" && doc.start==0 && doc.length==7);
    assert(engine.document("ma pani",0,6,"पानी").output=="ma पानी");
    auto literal=engine.document("hello 🙂 https://example.com foo_bar",1,0);
    assert(literal.output=="hello 🙂 https://example.com foo_bar");
    bool rejected = false;
    try { engine.candidates(std::string("ma\0pani",7)); } catch (const std::runtime_error&) { rejected = true; }
    assert(rejected);
    // Exercise the same background transport used by the Win32 frontend.
    std::mutex mutex; std::condition_variable ready; uint64_t delivered = 0;
    bool successful = false; std::string output;
    {
        neptype::PadWorker worker(argv[1],argv[2],[&](uint64_t id, neptype::Document value, bool success) {
            { std::lock_guard<std::mutex> lock(mutex); delivered=id; successful=success; output=value.output; }
            ready.notify_one();
        });
        for(uint64_t i=1;i<=100;++i) worker.submit(i,"ma pani",0,6);
        std::unique_lock<std::mutex> lock(mutex);
        assert(ready.wait_for(lock,std::chrono::seconds(10),[&] { return delivered==100; }));
        assert(successful && output=="ma पनि");
    }
}
