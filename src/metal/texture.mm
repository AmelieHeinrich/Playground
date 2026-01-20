#include "Texture.h"
#include "Device.h"

Texture::Texture(MTLTextureDescriptor* descriptor)
{
    Initialize(descriptor);
}

Texture::Texture(id<MTLTexture> texture)
{
    Initialize(texture);
}

void Texture::Initialize(MTLTextureDescriptor* descriptor)
{
    m_Descriptor = [descriptor copy];
    m_IsView = false;
    m_ParentTexture = nil;
    
    Resize((uint32_t)descriptor.width, (uint32_t)descriptor.height);
}

void Texture::Initialize(id<MTLTexture> texture)
{
    m_Texture = texture;
    m_IsView = false;
    m_ParentTexture = nil;

    if (m_Texture) {
        // Create descriptor from existing texture properties
        m_Descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:texture.pixelFormat
                                                                          width:texture.width
                                                                         height:texture.height
                                                                      mipmapped:texture.mipmapLevelCount > 1];
        m_Descriptor.textureType = texture.textureType;
        m_Descriptor.arrayLength = texture.arrayLength;
        m_Descriptor.usage = texture.usage;

        Device::GetResidencySet().AddResource(m_Texture);
    }
}

Texture::~Texture()
{
    // Remove from residency set for both parent textures and views
    if (m_Texture) {
        Device::GetResidencySet().RemoveResource(m_Texture);
    }
    m_Descriptor = nil;
    m_ParentTexture = nil;
}

Texture& Texture::View(MTLPixelFormat format, MTLTextureType textureType, NSRange levels, NSRange slices)
{
    // Create cache key
    TextureViewKey key;
    key.format = format;
    key.textureType = textureType;
    key.levelsLocation = levels.location;
    key.levelsLength = levels.length;
    key.slicesLocation = slices.location;
    key.slicesLength = slices.length;

    // Check if this view already exists in the cache
    auto it = m_ViewCache.find(key);
    if (it != m_ViewCache.end()) {
        // Return reference to cached view
        return it->second;
    }

    // Create the texture view
    id<MTLTexture> viewTexture = [m_Texture newTextureViewWithPixelFormat:format
                                                              textureType:textureType
                                                                   levels:levels
                                                                   slices:slices];

    // Add the view to the residency set
    Device::GetResidencySet().AddResource(viewTexture);

    // Create a new Texture object and store it in the cache
    auto result = m_ViewCache.emplace(key, Texture(viewTexture));
    Texture& viewObject = result.first->second;

    // Mark it as a view and keep a reference to the parent
    viewObject.m_IsView = true;
    viewObject.m_ParentTexture = m_Texture;

    // Update descriptor to reflect the view's properties
    viewObject.m_Descriptor.pixelFormat = format;
    viewObject.m_Descriptor.textureType = textureType;
    viewObject.m_Descriptor.mipmapLevelCount = levels.length;
    viewObject.m_Descriptor.arrayLength = slices.length;

    // Calculate dimensions for the base mip level of the view
    NSUInteger baseMipLevel = levels.location;
    NSUInteger viewWidth = m_Descriptor.width >> baseMipLevel;
    NSUInteger viewHeight = m_Descriptor.height >> baseMipLevel;

    // Ensure dimensions are at least 1
    viewWidth = viewWidth > 0 ? viewWidth : 1;
    viewHeight = viewHeight > 0 ? viewHeight : 1;

    viewObject.m_Descriptor.width = viewWidth;
    viewObject.m_Descriptor.height = viewHeight;

    // Create detailed label with view information
    NSString* baseLabel = m_Label ? m_Label : @"Texture";
    NSString* viewLabel = [NSString stringWithFormat:@"%@_view_fmt%lu_mip%lu-%lu_slice%lu-%lu",
                          baseLabel,
                          (unsigned long)format,
                          (unsigned long)levels.location,
                          (unsigned long)(levels.location + levels.length - 1),
                          (unsigned long)slices.location,
                          (unsigned long)(slices.location + slices.length - 1)];
    viewObject.SetLabel(viewLabel);

    return viewObject;
}

uint64_t Texture::GetResourceID() const
{
    return static_cast<uint64_t>(m_Texture.gpuResourceID._impl);
}

Texture& Texture::ViewMip(NSUInteger mipLevel)
{
    // View a single mip level, keeping the same format and type
    return View(m_Descriptor.pixelFormat,
                m_Descriptor.textureType,
                NSMakeRange(mipLevel, 1),
                NSMakeRange(0, m_Descriptor.arrayLength));
}

Texture& Texture::ViewMipRange(NSUInteger baseMip, NSUInteger mipCount)
{
    // View a range of mip levels, keeping the same format and type
    return View(m_Descriptor.pixelFormat,
                m_Descriptor.textureType,
                NSMakeRange(baseMip, mipCount),
                NSMakeRange(0, m_Descriptor.arrayLength));
}

Texture& Texture::ViewSlice(NSUInteger sliceIndex)
{
    // View a single slice (for array textures or cube faces)
    return View(m_Descriptor.pixelFormat,
                m_Descriptor.textureType,
                NSMakeRange(0, m_Descriptor.mipmapLevelCount),
                NSMakeRange(sliceIndex, 1));
}

Texture& Texture::ViewSliceRange(NSUInteger baseSlice, NSUInteger sliceCount)
{
    // View a range of slices
    return View(m_Descriptor.pixelFormat,
                m_Descriptor.textureType,
                NSMakeRange(0, m_Descriptor.mipmapLevelCount),
                NSMakeRange(baseSlice, sliceCount));
}

Texture& Texture::ViewWithFormat(MTLPixelFormat format)
{
    // View with a different pixel format (useful for aliasing)
    return View(format,
                m_Descriptor.textureType,
                NSMakeRange(0, m_Descriptor.mipmapLevelCount),
                NSMakeRange(0, m_Descriptor.arrayLength));
}

void Texture::ClearViewCache()
{
    m_ViewCache.clear();
}

void Texture::SetDescriptor(MTLTextureDescriptor* descriptor)
{
    m_Descriptor = [descriptor copy];
}

void Texture::Resize(uint32_t width, uint32_t height, bool recomputeMips)
{
    // Skip resize if dimensions haven't changed and mip recomputation not requested
    if (m_Texture && m_Descriptor.width == width && m_Descriptor.height == height && !recomputeMips) {
        return;
    }

    // Remove old texture from residency set and release it
    if (m_Texture) {
        Device::GetResidencySet().RemoveResource(m_Texture);
    }

    // Clear view cache since the texture is being recreated
    ClearViewCache();

    // Update descriptor dimensions
    m_Descriptor.width = width;
    m_Descriptor.height = height;

    // Recompute mipmap levels if requested
    if (recomputeMips) {
        // Calculate the maximum number of mip levels for the given dimensions
        // mipLevels = 1 + floor(log2(max(width, height)))
        uint32_t maxDim = width > height ? width : height;
        uint32_t mipLevels = 1;
        while (maxDim > 1) {
            maxDim >>= 1;
            mipLevels++;
        }
        m_Descriptor.mipmapLevelCount = mipLevels;
    }

    // Create new texture with updated dimensions
    m_Texture = [Device::GetDevice() newTextureWithDescriptor:m_Descriptor];

    // Reapply label if one was set
    if (m_Label) {
        m_Texture.label = m_Label;
    }

    Device::GetResidencySet().AddResource(m_Texture);
}

void Texture::UploadData(const void* data, uint64_t size, uint64_t bpp)
{
    [m_Texture replaceRegion:MTLRegionMake2D(0, 0, Width(), Height()) mipmapLevel:0 withBytes:data bytesPerRow:Width() * bpp];
}
