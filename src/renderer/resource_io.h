#pragma once

#include "metal/buffer.h"
#include "metal/indirect_command_buffer.h"
#include "metal/texture.h"

#include <Metal/MTLIndirectCommandBuffer.h>
#import <Metal/Metal.h>

#include <unordered_map>
#include <string>

constexpr const char* DEFAULT_WHITE = "Default/White";
constexpr const char* DEFAULT_BLACK = "Default/Black";

enum class ResourceType
{
    TEXTURE,
    BUFFER,
    INDIRECT_COMMAND_BUFFER
};

struct Resource
{
    std::string Name;
    ResourceType Type;

    Texture* Texture;
    Buffer* Buffer;
    IndirectCommandBuffer* IndirectCommandBuffer;
};

class ResourceIO
{
public:
    static void Initialize();
    static void Shutdown();

    static Resource& CreateTexture(const std::string& name, MTLTextureDescriptor* descriptor);
    static Resource& CreateBuffer(const std::string& name, uint64_t size);
    static Resource& CreateIndirectCommandBuffer(const std::string& name, bool inherit, MTLIndirectCommandType type, uint maxCommandCount);

    // TODO: Auto barrier insertion
    static Resource& Get(const std::string& name);
    static Texture& GetTexture(const std::string& name);
    static Buffer& GetBuffer(const std::string& name);
    static IndirectCommandBuffer& GetIndirectCommandBuffer(const std::string& name);
private:
    static std::unordered_map<std::string, Resource> s_Resources;
};
