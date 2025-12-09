#pragma once

#import <Metal/Metal.h>
#include <string>

class KTX2Loader
{
public:
    static id<MTLTexture> LoadKTX2(const std::string& path);
};