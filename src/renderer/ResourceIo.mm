#include "ResourceIo.h"
#include <Foundation/Foundation.h>

std::unordered_map<std::string, Resource> ResourceIO::s_Resources;

void ResourceIO::Initialize()
{
    // Default textures
    MTLTextureDescriptor* descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm_sRGB width:1 height:1 mipmapped:NO];
    descriptor.usage = MTLTextureUsageShaderRead;

    uint32_t whiteColor = 0xFFFFFFFF;
    uint32_t blackColor = 0xFF000000;

    Resource& white = CreateTexture(DEFAULT_WHITE, descriptor);
    white.Texture->UploadData(&whiteColor, sizeof(whiteColor), sizeof(uint8_t) * 4);

    Resource& black = CreateTexture(DEFAULT_BLACK, descriptor);
    black.Texture->UploadData(&blackColor, sizeof(blackColor), sizeof(uint8_t) * 4);
}

void ResourceIO::Shutdown()
{
    for (auto& pair : s_Resources) {
        if (pair.second.Type == ResourceType::TEXTURE && pair.second.Texture) {
            delete pair.second.Texture;
        } else if (pair.second.Type == ResourceType::BUFFER && pair.second.Buffer) {
            delete pair.second.Buffer;
        }
    }
    s_Resources.clear();
}

Resource& ResourceIO::CreateTexture(const std::string& name, MTLTextureDescriptor* descriptor)
{
    s_Resources[name] = {};
    s_Resources[name].Type = ResourceType::TEXTURE;
    s_Resources[name].Texture = new Texture(descriptor);
    s_Resources[name].Texture->SetLabel([NSString stringWithCString:name.c_str() encoding:NSUTF8StringEncoding]);
    s_Resources[name].Buffer = nullptr;
    return s_Resources[name];
}

Resource& ResourceIO::CreateBuffer(const std::string& name, uint64_t size)
{
    s_Resources[name] = {};
    s_Resources[name].Type = ResourceType::BUFFER;
    s_Resources[name].Buffer = new Buffer();
    s_Resources[name].Buffer->Initialize(size);
    s_Resources[name].Buffer->SetLabel([NSString stringWithCString:name.c_str() encoding:NSUTF8StringEncoding]);
    s_Resources[name].Texture = nullptr;
    return s_Resources[name];
}

Resource& ResourceIO::CreateIndirectCommandBuffer(const std::string& name, bool inherit, MTLIndirectCommandType type, uint maxCommandCount)
{
    s_Resources[name] = {};
    s_Resources[name].Type = ResourceType::INDIRECT_COMMAND_BUFFER;
    s_Resources[name].IndirectCommandBuffer = new IndirectCommandBuffer();
    s_Resources[name].IndirectCommandBuffer->Initialize(inherit, type, maxCommandCount);
    s_Resources[name].IndirectCommandBuffer->SetLabel([NSString stringWithCString:name.c_str() encoding:NSUTF8StringEncoding]);
    s_Resources[name].Texture = nullptr;
    s_Resources[name].Buffer = nullptr;
    return s_Resources[name];
}

Resource& ResourceIO::Get(const std::string& name)
{
    return s_Resources[name];
}

Texture& ResourceIO::GetTexture(const std::string& name)
{
    return *s_Resources[name].Texture;
}

Buffer& ResourceIO::GetBuffer(const std::string& name)
{
    return *s_Resources[name].Buffer;
}

IndirectCommandBuffer& ResourceIO::GetIndirectCommandBuffer(const std::string& name)
{
    return *s_Resources[name].IndirectCommandBuffer;
}
