#include <iostream>
#include <sstream>

#include <hoytech/error.h>
#include <hoytech/hex.h>

#include "Negentropy.h"



std::vector<std::string> split(const std::string &s, char delim) {
    std::vector<std::string> result;
    std::stringstream ss (s);
    std::string item;

    while (getline (ss, item, delim)) {
        result.push_back (item);
    }

    return result;
}



int main() {
    const uint64_t idSize = 16;

    uint64_t frameSizeLimit = 0;
    if (::getenv("FRAMESIZELIMIT")) frameSizeLimit = std::stoull(::getenv("FRAMESIZELIMIT"));

    Negentropy ne(idSize, frameSizeLimit);

    std::string line;
    while (std::cin) {
        std::getline(std::cin, line);
        if (!line.size()) continue;

        auto items = split(line, ',');

        if (items[0] == "item") {
            if (items.size() != 3) throw hoytech::error("wrong num of fields");
            uint64_t created = std::stoull(items[1]);
            auto id = hoytech::from_hex(items[2]);
            ne.addItem(created, id);
        } else if (items[0] == "seal") {
            ne.seal();
        } else if (items[0] == "initiate") {
            auto q = ne.initiate();
            if (frameSizeLimit && q.size() > frameSizeLimit) throw hoytech::error("frameSizeLimit exceeded");
            std::cout << "msg," << hoytech::to_hex(q) << std::endl;
        } else if (items[0] == "msg") {
            std::string q;
            if (items.size() >= 2) q = hoytech::from_hex(items[1]);

            if (ne.isInitiator) {
                std::vector<std::string> have, need;
                auto resp = ne.reconcile(q, have, need);

                for (auto &id : have) std::cout << "have," << hoytech::to_hex(id) << "\n";
                for (auto &id : need) std::cout << "need," << hoytech::to_hex(id) << "\n";

                if (!resp) {
                    std::cout << "done" << std::endl;
                    continue;
                }

                q = *resp;
            } else {
                q = ne.reconcile(q);
            }

            if (frameSizeLimit && q.size() > frameSizeLimit) throw hoytech::error("frameSizeLimit exceeded");
            std::cout << "msg," << hoytech::to_hex(q) << std::endl;
        } else {
            throw hoytech::error("unknown cmd: ", items[0]);
        }
    }

    return 0;
}
