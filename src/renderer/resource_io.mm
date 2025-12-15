#include "resource_io.h"

std::unordered_map<std::string, Resource> ResourceIO::s_Resources;

void ResourceIO::Initialize()
{
    // Default textures
    MTLTextureDescriptor* descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm_sRGB width:1 height:1 mipmapped:NO];
    descriptor.usage = MTLTextureUsageShaderRead;
    
    uint32_t whiteColor = 0xFFFFFFFF;
    uint32_t blackColor = 0xFF000000;
    
    Resource& white = CreateTexture(DEFAULT_WHITE, descriptor);
    white.Texture.UploadData(&whiteColor, sizeof(whiteColor), sizeof(uint8_t) * 4);
    
    Resource& black = CreateTexture(DEFAULT_BLACK, descriptor);
    black.Texture.UploadData(&blackColor, sizeof(blackColor), sizeof(uint8_t) * 4);
}

void ResourceIO::Shutdown()
{
    s_Resources.clear();
}

Resource& ResourceIO::CreateTexture(const std::string& name, MTLTextureDescriptor* descriptor)
{
    s_Resources[name] = {};
    s_Resources[name].Type = ResourceType::TEXTURE;
    s_Resources[name].Texture.SetDescriptor(descriptor);
    s_Resources[name].Texture.SetLabel([NSString stringWithUTF8String:name.c_str()]);
    return s_Resources[name];
}

Resource& ResourceIO::CreateBuffer(const std::string& name, uint64_t size)
{
    s_Resources[name] = {};
    s_Resources[name].Type = ResourceType::BUFFER;
    s_Resources[name].Buffer.Initialize(size);
    s_Resources[name].Buffer.SetLabel([NSString stringWithUTF8String:name.c_str()]);
    return s_Resources[name];
}

Resource& ResourceIO::CreateArgumentBuffer(const std::string& name, id<MTLFunction> function, int index)
{
    s_Resources[name] = {};
    s_Resources[name].Type = ResourceType::ARGUMENT_BUFFER;
    s_Resources[name].ArgBuffer.Initialize(function, index);
    return s_Resources[name];
}

Resource& ResourceIO::Get(const std::string& name)
{
    return s_Resources[name];
}
