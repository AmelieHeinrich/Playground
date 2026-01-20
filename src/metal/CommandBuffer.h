#pragma once

#include "BlitEncoder.h"
#include "ComputeEncoder.h"
#include "RenderEncoder.h"
#include "Texture.h"
#include "Fence.h"
#include "AccelerationEncoder.h"

#include <simd/vector_make.h>

#include <vector>

struct RenderPassInfo
{
    NSString* Name;
    std::vector<id<MTLTexture>> Textures;
    std::vector<simd_float4> ClearColors;
    std::vector<bool> ShouldClear;

    id<MTLTexture> DepthStencilTexture;
    bool ShouldClearDepthStencil;
    bool ShouldStoreDepthStencil = true;

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

    RenderPassInfo& AddTexture(const Texture& texture, bool shouldClear = true, simd_float4 clearColor = simd_make_float4(0.0f, 0.0f, 0.0f, 1.0f))
    {
        Textures.push_back(texture.GetTexture());
        ClearColors.push_back(clearColor);
        ShouldClear.push_back(shouldClear);
        return *this;
    }

    RenderPassInfo& AddDepthStencilTexture(id<MTLTexture> texture, bool shouldClear = true, bool shouldStore = true, simd_float4 clearColor = simd_make_float4(0, 0, 0, 1))
    {
        DepthStencilTexture = texture;
        ShouldClearDepthStencil = shouldClear;
        ShouldStoreDepthStencil = shouldStore;
        return *this;
    }

    RenderPassInfo& AddDepthStencilTexture(const Texture& texture, bool shouldClear = true, bool shouldStore = true, simd_float4 clearColor = simd_make_float4(0, 0, 0, 1))
    {
        DepthStencilTexture = texture.GetTexture();
        ShouldClearDepthStencil = shouldClear;
        ShouldStoreDepthStencil = shouldStore;
        return *this;
    }
};

class CommandBuffer
{
public:
    CommandBuffer(NSString* name = @"Command Buffer");
    ~CommandBuffer() = default;

    RenderEncoder RenderPass(const RenderPassInfo& info);
    ComputeEncoder ComputePass(NSString* name = @"Compute Pass");
    BlitEncoder BlitPass(NSString* name = @"Blit Pass");
    AccelerationEncoder AccelerationPass(NSString* name = @"Acceleration Pass");

    void Commit();
    id<MTLCommandBuffer> GetCommandBuffer() { return m_CommandBuffer; }
    id<MTLTexture> GetDrawable() { return m_Drawable; }

    void SetDrawable(id<MTLTexture> drawable) { m_Drawable = drawable; }
private:
    id<MTLCommandBuffer> m_CommandBuffer;
    id<MTLTexture> m_Drawable;
    Fence m_Fence;
};
