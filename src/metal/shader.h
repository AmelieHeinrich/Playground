#pragma once

#include <unordered_map>
#include <vector>
#include <string>

#import <Metal/Metal.h>

enum class ShaderType
{
    GRAPHICS,
    MESH,
    COMPUTE,
    RAYTRACING
};

enum class ShaderStage
{
    VERTEX,
    FRAGMENT,
    MESH,
    COMPUTE,
    CLOSEST_HIT,
    MISS,
    RAY_GENERATION,
    ANY_HIT
};

struct ShaderModule
{
    ShaderStage Stage;
    id<MTLFunction> Function;
    std::string EntryPoint;
};

struct Shader
{
    ShaderType Type;
    id<MTLLibrary> Library;
    std::unordered_map<ShaderStage, ShaderModule> AvailableModules;

    bool HasStage(ShaderStage stage) const {
        return AvailableModules.find(stage) != AvailableModules.end();
    }

    id<MTLFunction> GetFunction(ShaderStage stage) const {
        auto it = AvailableModules.find(stage);
        return it != AvailableModules.end() ? it->second.Function : nil;
    }
};

class ShaderCompiler
{
public:
    static Shader Compile(id<MTLDevice> device, const std::string& path, ShaderType type);
};
