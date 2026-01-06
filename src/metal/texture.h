#pragma once

#include <stdint.h>

#import <Metal/Metal.h>

#include <map>

// Key structure for caching texture views
struct TextureViewKey {
    MTLPixelFormat format;
    MTLTextureType textureType;
    NSUInteger levelsLocation;
    NSUInteger levelsLength;
    NSUInteger slicesLocation;
    NSUInteger slicesLength;

    bool operator<(const TextureViewKey& other) const {
        if (format != other.format) return format < other.format;
        if (textureType != other.textureType) return textureType < other.textureType;
        if (levelsLocation != other.levelsLocation) return levelsLocation < other.levelsLocation;
        if (levelsLength != other.levelsLength) return levelsLength < other.levelsLength;
        if (slicesLocation != other.slicesLocation) return slicesLocation < other.slicesLocation;
        return slicesLength < other.slicesLength;
    }
};

class Texture
{
public:
    Texture() = default;
    Texture(MTLTextureDescriptor* descriptor);
    Texture(id<MTLTexture> texture);
    ~Texture();

    // Initialize
    void Initialize(MTLTextureDescriptor* descriptor);
    void Initialize(id<MTLTexture> texture);

    // Create a texture view - full control
    Texture& View(MTLPixelFormat format, MTLTextureType textureType, NSRange levels, NSRange slices);

    // Convenience overloads for common use cases
    Texture& ViewMip(NSUInteger mipLevel);
    Texture& ViewMipRange(NSUInteger baseMip, NSUInteger mipCount);
    Texture& ViewSlice(NSUInteger sliceIndex);
    Texture& ViewSliceRange(NSUInteger baseSlice, NSUInteger sliceCount);
    Texture& ViewWithFormat(MTLPixelFormat format);

    void SetDescriptor(MTLTextureDescriptor* descriptor);
    void Resize(uint32_t width, uint32_t height, bool recomputeMips = false);
    void UploadData(const void* data, uint64_t size, uint64_t bpp);

    id<MTLTexture> GetTexture() const { return m_Texture; }
    uint64_t GetResourceID() const;
    bool Valid() { return m_Texture != nil; }
    void SetLabel(NSString* label) { m_Label = label; m_Texture.label = label; }
    uint32_t Width() const { return (uint32_t)m_Descriptor.width; }
    uint32_t Height() const { return (uint32_t)m_Descriptor.height; }
    uint32_t MipLevels() const { return (uint32_t)m_Descriptor.mipmapLevelCount; }
    bool IsView() const { return m_IsView; }
    void ClearViewCache();
private:
    id<MTLTexture> m_Texture = nil;
    MTLTextureDescriptor* m_Descriptor;
    NSString* m_Label = nil;
    bool m_IsView = false;
    id<MTLTexture> m_ParentTexture = nil;

    // Cache for texture views - only used by parent textures, not by views themselves
    std::map<TextureViewKey, Texture> m_ViewCache;
};
