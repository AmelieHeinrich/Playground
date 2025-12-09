#include "mipmapper.h"
#include <Foundation/Foundation.h>

std::vector<id<MTLTexture>> Mipmapper::s_PendingTextures;

void Mipmapper::RequestMipmaps(id<MTLTexture> texture)
{
    if (!texture) {
        NSLog(@"Mipmapper: Cannot request mipmaps for nil texture");
        return;
    }
    
    // Check if texture supports mipmap generation
    if (texture.mipmapLevelCount <= 1) {
        NSLog(@"Mipmapper: Texture has only 1 mip level, skipping");
        return;
    }
    
    if (!(texture.usage & MTLTextureUsageShaderWrite)) {
        NSLog(@"Mipmapper: Texture doesn't have ShaderWrite usage, cannot generate mipmaps");
        return;
    }
    
    // Add to pending list
    s_PendingTextures.push_back(texture);
    NSLog(@"Mipmapper: Queued texture for mipmap generation (%lu total pending)", s_PendingTextures.size());
}

void Mipmapper::Flush(id<MTLCommandQueue> queue)
{
    if (s_PendingTextures.empty()) {
        NSLog(@"Mipmapper: No pending textures to process");
        return;
    }
    
    NSLog(@"Mipmapper: Flushing %lu texture(s) for mipmap generation", s_PendingTextures.size());
    
    // Create command buffer
    id<MTLCommandBuffer> commandBuffer = [queue commandBuffer];
    commandBuffer.label = @"Mipmap Generation";
    
    // Create blit encoder
    id<MTLBlitCommandEncoder> blitEncoder = [commandBuffer blitCommandEncoder];
    blitEncoder.label = @"Generate Mipmaps";
    
    // Generate mipmaps for all pending textures
    for (id<MTLTexture> texture : s_PendingTextures) {
        [blitEncoder generateMipmapsForTexture:texture];
    }
    
    [blitEncoder endEncoding];
    
    // Commit and wait
    [commandBuffer commit];
    [commandBuffer waitUntilCompleted];
    
    NSLog(@"Mipmapper: Successfully generated mipmaps for %lu texture(s)", s_PendingTextures.size());
    
    // Clear the pending list
    s_PendingTextures.clear();
}

void Mipmapper::Clear()
{
    s_PendingTextures.clear();
    NSLog(@"Mipmapper: Cleared all pending mipmap requests");
}