#pragma once

#import <Metal/Metal.h>
#include <vector>

class Mipmapper
{
public:
    // Request mipmap generation for a texture
    static void RequestMipmaps(id<MTLTexture> texture);
    
    // Flush all pending mipmap generation requests
    static void Flush(id<MTLCommandQueue> queue);
    
    // Clear all pending requests (useful for cleanup)
    static void Clear();
    
private:
    static std::vector<id<MTLTexture>> s_PendingTextures;
};