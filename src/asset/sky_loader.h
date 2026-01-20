#pragma once

#import <Metal/Metal.h>

#include <string>
#include <metal/texture.h>

class SkyLoader
{
public:
    static Texture* LoadSky(const std::string& path);
};
