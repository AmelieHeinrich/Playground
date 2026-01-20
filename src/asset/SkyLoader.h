#pragma once

#import <Metal/Metal.h>

#include <string>
#include <Metal/Texture.h>

class SkyLoader
{
public:
    static Texture* LoadSky(const std::string& path);
};
