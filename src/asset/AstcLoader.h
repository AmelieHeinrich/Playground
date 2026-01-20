#pragma once

#import <Metal/Metal.h>

#include <string>

class ASTCLoader
{
public:
    static id<MTLTexture> LoadASTC(const std::string& path);
};
