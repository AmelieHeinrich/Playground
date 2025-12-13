#include "resource_io.h"

std::unordered_map<std::string, Resource> ResourceIO::s_Resources;

Resource& ResourceIO::CreateTexture(const std::string& name, MTLTextureDescriptor* descriptor)
{
    s_Resources[name] = {};
    s_Resources[name].Type = ResourceType::TEXTURE;
    s_Resources[name].Texture.SetDescriptor(descriptor);
    return s_Resources[name];
}

Resource& ResourceIO::CreateBuffer(const std::string& name, uint64_t size)
{
    s_Resources[name] = {};
    s_Resources[name].Type = ResourceType::BUFFER;
    s_Resources[name].Buffer.Initialize(size);
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
