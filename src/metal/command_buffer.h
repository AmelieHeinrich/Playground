#pragma once

#include "metal/render_encoder.h"
#include "metal/texture.h"
#import <Metal/Metal.h>
#include <simd/vector_make.h>
#import <simd/simd.h>

#include <vector>

struct RenderPassInfo
{
    NSString* Name;
    std::vector<id<MTLTexture>> Textures;
    std::vector<simd_float4> ClearColors;
    std::vector<bool> ShouldClear;

    id<MTLTexture> DepthStencilTexture;
    bool ShouldClearDepthStencil;

    RenderPassInfo& SetName(NSString* name)
    {
        Name = name;
        return *this;
    }

    RenderPassInfo& AddTexture(id<MTLTexture> texture, bool shouldClear = true, simd_float4 clearColor = simd_make_float4(0.0f, 0.0f, 0.0f, 1.0f))
    {
        Textures.push_back(texture);
        ClearColors.push_back(clearColor);
        ShouldClear.push_back(shouldClear);
        return *this;
    }

    RenderPassInfo& AddTexture(Texture texture, bool shouldClear = true, simd_float4 clearColor = simd_make_float4(0.0f, 0.0f, 0.0f, 1.0f))
    {
        Textures.push_back(texture.GetTexture());
        ClearColors.push_back(clearColor);
        ShouldClear.push_back(shouldClear);
        return *this;
    }

    RenderPassInfo& AddDepthStencilTexture(id<MTLTexture> texture, bool shouldClear = true, simd_float4 clearColor = simd_make_float4(0, 0, 0, 1))
    {
        DepthStencilTexture = texture;
        ShouldClearDepthStencil = shouldClear;
        return *this;
    }

    RenderPassInfo& AddDepthStencilTexture(Texture texture, bool shouldClear = true, simd_float4 clearColor = simd_make_float4(0, 0, 0, 1))
    {
        DepthStencilTexture = texture.GetTexture();
        ShouldClearDepthStencil = shouldClear;
        return *this;
    }
};

class CommandBuffer
{
public:
    CommandBuffer(NSString* name = @"Command Buffer");
    ~CommandBuffer() = default;

    RenderEncoder RenderPass(const RenderPassInfo& info);

    void Commit();
    id<MTLCommandBuffer> GetCommandBuffer() { return m_CommandBuffer; }
private:
    id<MTLCommandBuffer> m_CommandBuffer;
};
