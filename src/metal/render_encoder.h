#pragma once

#import <Metal/Metal.h>

#include "graphics_pipeline.h"
#include "shader.h"
#include "buffer.h"
#include "texture.h"

class RenderEncoder
{
public:
    RenderEncoder(id<MTLCommandBuffer> commandBuffer, MTLRenderPassDescriptor* renderPassDescriptor, NSString* name = @"RenderEncoder");
    ~RenderEncoder() = default;

    void End();

    void SetGraphicsPipeline(const GraphicsPipeline& pipeline);
    void SetBytes(ShaderStage stages, const void* bytes, size_t size, int index);

    void SetBuffer(ShaderStage stages, const Buffer& buffer, int index, int offset = 0);
    void SetBuffer(ShaderStage stages, id<MTLBuffer> buffer, int index, int offset = 0);

    void SetTexture(ShaderStage stages, const Texture& texture, int index);
    void SetTexture(ShaderStage stages, id<MTLTexture> texture, int index);

    void DrawIndexed(MTLPrimitiveType primitiveType, const Buffer& indexBuffer,  uint32_t indexCount, uint32_t indexOffset);
    void DrawIndexed(MTLPrimitiveType primitiveType, id<MTLBuffer> indexBuffer, uint32_t indexCount, uint32_t indexOffset);

    id<MTLRenderCommandEncoder> GetCommandEncoder() const { return m_RenderEncoder; }
private:
    id<MTLRenderCommandEncoder> m_RenderEncoder;
};
