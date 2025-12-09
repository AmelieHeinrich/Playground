#pragma once

#include "astc_loader.h"
#include <unordered_map>

class TextureCache
{
public:
    static void Shutdown();

    static id<MTLTexture> GetTexture(const std::string& path);
private:
    static struct Data {
        std::unordered_map<std::string, id<MTLTexture>> Textures;
    } sData;
};
