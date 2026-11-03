#pragma once
#include <filesystem>
#include <fstream>
#include <map>
#include <string>
#include <cctype>
#include <vector>
#ifdef _WIN32
#include <windows.h>
#endif
namespace neptype {
class LocalExperience {
    std::filesystem::path root_;
    static std::string escaped(const std::string& s) {
        std::string out;
        for(unsigned char c:s) { if(c=='"'||c=='\\') out+='\\'; if(c>=32) out+=static_cast<char>(c); }
        return out;
    }
    std::string read(const char* name, size_t limit) const {
        if(root_.empty()) return {};
        std::error_code ec; auto p=root_/name; auto size=std::filesystem::file_size(p,ec);
        if(ec || size>limit) return {};
        std::ifstream file(p,std::ios::binary); return std::string(std::istreambuf_iterator<char>(file),{});
    }
    bool write(const char* name,const std::string& value) {
        if(root_.empty()) return false;
        std::error_code ec;std::filesystem::create_directories(root_,ec);if(ec)return false;
        auto path=root_/name,temporary=path;temporary += ".tmp";
        {std::ofstream f(temporary,std::ios::binary|std::ios::trunc);f.write(value.data(),value.size());if(!f)return false;}
#ifdef _WIN32
        return MoveFileExW(temporary.c_str(),path.c_str(),MOVEFILE_REPLACE_EXISTING|MOVEFILE_WRITE_THROUGH)!=FALSE;
#else
        std::filesystem::permissions(temporary,std::filesystem::perms::owner_read|std::filesystem::perms::owner_write,std::filesystem::perm_options::replace,ec);
        std::filesystem::rename(temporary,path,ec);return !ec;
#endif
    }
public:
    std::string source; int mode=0;bool guide_seen=false;
    std::map<std::string,std::string> spellings;
    explicit LocalExperience(std::filesystem::path root):root_(std::move(root)) {
        if(!root_.empty()&&!root_.is_absolute())root_.clear();
        source=read("draft.txt",1048576);mode=read("mode",8)=="2"?2:0;
        guide_seen=read("guide",8)=="1";
        auto words=read("spellings.tsv",524288);size_t start=0;
        while(start<words.size()&&spellings.size()<256){auto end=words.find('\n',start);if(end==std::string::npos)end=words.size();auto row=words.substr(start,end-start);auto tab=row.find('\t');if(tab!=std::string::npos)save_word(row.substr(0,tab),row.substr(tab+1),{"",row.substr(tab+1)});start=end+1;}
    }
    void save_word(std::string key,const std::string& value,const std::vector<std::string>& offered) {
        if(key.empty()||key.size()>64||value.size()>1024||value.find_first_of("\t\r\n")!=std::string::npos||value.find('\0')!=std::string::npos)return;
        for(auto& c:key){if(!((c>='a'&&c<='z')||(c>='A'&&c<='Z')))return;c=static_cast<char>(std::tolower(static_cast<unsigned char>(c)));}
        bool valid=false;for(const auto& item:offered)valid|=item==value;if(!valid)return;
        auto existing=spellings.find(key);
        if(offered.front()==value&&(existing==spellings.end()||existing->second!=value)){spellings.erase(key);return;}
        if(spellings.size()>=256&&!spellings.count(key))spellings.erase(spellings.begin());spellings[key]=value;
    }
    std::string preferences() const {
        std::string result="{";for(const auto& pair:spellings){if(result.size()>1)result+=',';result+='"'+escaped(pair.first)+"\":\""+escaped(pair.second)+'"';}return result+'}';
    }
    bool save() {
        if(source.size()>1048576)return false;
        std::string words;for(const auto& pair:spellings)words+=pair.first+'\t'+pair.second+'\n';
        return write("draft.txt",source)&&write("mode",std::to_string(mode))&&write("spellings.tsv",words)&&write("guide",guide_seen?"1":"0");
    }
};
}
