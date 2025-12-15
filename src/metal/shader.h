#pragma once

#include <string>

#import <Metal/Metal.h>

enum class ShaderStage : uint32_t
{
    VERTEX = 1 << 0,
    FRAGMENT = 1 << 1,
    MESH = 1 << 2,
    COMPUTE = 1 << 3,
    TILE = 1 << 4,
    CLOSEST_HIT = 1 << 5,
    MISS = 1 << 6,
    RAY_GENERATION = 1 << 7,
    ANY_HIT = 1 << 8
};

// Bitwise operators for ShaderStage
inline ShaderStage operator|(ShaderStage lhs, ShaderStage rhs) {
    return static_cast<ShaderStage>(static_cast<uint32_t>(lhs) | static_cast<uint32_t>(rhs));
}

inline ShaderStage operator&(ShaderStage lhs, ShaderStage rhs) {
    return static_cast<ShaderStage>(static_cast<uint32_t>(lhs) & static_cast<uint32_t>(rhs));
}

inline ShaderStage operator^(ShaderStage lhs, ShaderStage rhs) {
    return static_cast<ShaderStage>(static_cast<uint32_t>(lhs) ^ static_cast<uint32_t>(rhs));
}

inline ShaderStage operator~(ShaderStage stage) {
    return static_cast<ShaderStage>(~static_cast<uint32_t>(stage));
}

inline ShaderStage& operator|=(ShaderStage& lhs, ShaderStage rhs) {
    lhs = lhs | rhs;
    return lhs;
}

inline ShaderStage& operator&=(ShaderStage& lhs, ShaderStage rhs) {
    lhs = lhs & rhs;
    return lhs;
}

inline ShaderStage& operator^=(ShaderStage& lhs, ShaderStage rhs) {
    lhs = lhs ^ rhs;
    return lhs;
}

inline bool operator!(ShaderStage stage) {
    return static_cast<uint32_t>(stage) == 0;
}

// Helper function to test if a stage flag is set
inline bool HasFlag(ShaderStage flags, ShaderStage flag) {
    return (static_cast<uint32_t>(flags) & static_cast<uint32_t>(flag)) != 0;
}

class ShaderLibrary
{
public:
    static void Initialize(id<MTLDevice> device);
    static id<MTLLibrary> GetDefaultLibrary();
    static id<MTLFunction> GetFunction(const std::string& name);

private:
    static id<MTLLibrary> s_DefaultLibrary;
};
