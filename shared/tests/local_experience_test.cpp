#include "../cpp/local_experience.hpp"
#include <cassert>
#include <iostream>
int main(){
    auto path=std::filesystem::temp_directory_path()/"neptype-product-state-test";
    std::filesystem::remove_all(path);
    neptype::LocalExperience first(path);
    first.source="private draft";first.guide_seen=true;
    first.save_word("pani","पानी",{"पनि","पानी"});
    first.save_word("private@example.com","private",{"private"});
    assert(first.spellings.size()==1&&first.save());
    neptype::LocalExperience restored(path);
    assert(restored.source==first.source&&restored.guide_seen&&restored.spellings==first.spellings);
    restored.source="";restored.spellings.clear();assert(restored.save());
    neptype::LocalExperience empty(path);assert(empty.source.empty()&&empty.spellings.empty());
    std::filesystem::remove_all(path);
    std::cout<<"PASS: native local draft, bounded preferences and explicit deletion\n";
}
