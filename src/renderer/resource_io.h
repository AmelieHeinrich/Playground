#pragma once

#include "metal/arg_buffer.h"
#include "metal/buffer.h"
#include "metal/texture.h"

#import <Metal/Metal.h>

#include <unordered_map>
#include <string>

enum class ResourceType
{
    TEXTURE,
    BUFFER,
    ARGUMENT_BUFFER
};

struct Resource
{
    std::string Name;
    ResourceType Type;

    Texture Texture;
    Buffer Buffer;
    ArgBuffer ArgBuffer;
};

class ResourceIO
{
public:
    static Resource& CreateTexture(const std::string& name, MTLTextureDescriptor* descriptor);
    static Resource& CreateBuffer(const std::string& name, uint64_t size);
    static Resource& CreateArgumentBuffer(const std::string& name, id<MTLFunction> function, int index);

    // TODO: Auto barrier insertion
    static Resource& Get(const std::string& name);
private:
    static std::unordered_map<std::string, Resource> s_Resources;
};
