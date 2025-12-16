#include "render_encoder.h"

#include "metal/device.h"
#include "metal/graphics_pipeline.h"
#include <Metal/Metal.h>

RenderEncoder::RenderEncoder(id<MTLCommandBuffer> commandBuffer, MTLRenderPassDescriptor* renderPassDescriptor, NSString* name, Fence* fence)
    : m_Fence(fence)
{
    m_RenderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    m_RenderEncoder.label = name;
    [m_RenderEncoder waitForFence:m_Fence->GetFence() beforeStages:MTLRenderStageVertex];
}

void RenderEncoder::End()
{
    [m_RenderEncoder waitForFence:m_Fence->GetFence() beforeStages:MTLRenderStageFragment];
    [m_RenderEncoder endEncoding];
}

void RenderEncoder::SetGraphicsPipeline(const GraphicsPipeline& pipeline)
{
    [m_RenderEncoder setRenderPipelineState:pipeline.GetPipelineState()];
    if (pipeline.GetDesc().DepthEnabled)
        [m_RenderEncoder setDepthStencilState:pipeline.GetDepthStencilState()];
}

void RenderEncoder::SetBytes(ShaderStage stages, const void* bytes, size_t size, int index)
{
    if (HasFlag(stages, ShaderStage::VERTEX)) [m_RenderEncoder setVertexBytes:bytes length:size atIndex:index];
    if (HasFlag(stages, ShaderStage::FRAGMENT)) [m_RenderEncoder setFragmentBytes:bytes length:size atIndex:index];
}

void RenderEncoder::SetBuffer(ShaderStage stages, const Buffer& buffer, int index, int offset)
{
    SetBuffer(stages, buffer.GetBuffer(), index, offset);
}

void RenderEncoder::SetBuffer(ShaderStage stages, id<MTLBuffer> buffer, int index, int offset)
{
    if (HasFlag(stages, ShaderStage::VERTEX)) [m_RenderEncoder setVertexBuffer:buffer offset:offset atIndex:index];
    if (HasFlag(stages, ShaderStage::FRAGMENT)) [m_RenderEncoder setFragmentBuffer:buffer offset:offset atIndex:index];
}

void RenderEncoder::SetTexture(ShaderStage stages, const Texture& texture, int index)
{
    SetTexture(stages, texture.GetTexture(), index);
}

void RenderEncoder::SetTexture(ShaderStage stages, id<MTLTexture> texture, int index)
{
    if (HasFlag(stages, ShaderStage::VERTEX)) [m_RenderEncoder setVertexTexture:texture atIndex:index];
    if (HasFlag(stages, ShaderStage::FRAGMENT)) [m_RenderEncoder setFragmentTexture:texture atIndex:index];
}

void RenderEncoder::ResourceBarrier(const Buffer& buffer)
{
    id<MTLBuffer> mtlBuffer = buffer.GetBuffer();
    [m_RenderEncoder memoryBarrierWithResources:&mtlBuffer
                     count:1
                     afterStages:MTLRenderStageVertex | MTLRenderStageMesh
                     beforeStages:MTLRenderStageVertex | MTLRenderStageFragment | MTLRenderStageMesh];
}

void RenderEncoder::ResourceBarrier(const Texture& texture)
{
    id<MTLTexture> mtlTexture = texture.GetTexture();
    [m_RenderEncoder memoryBarrierWithResources:&mtlTexture
                     count:1
                     afterStages:MTLRenderStageVertex | MTLRenderStageMesh
                     beforeStages:MTLRenderStageVertex | MTLRenderStageFragment | MTLRenderStageMesh];
}

void RenderEncoder::ResourceBarrier(const IndirectCommandBuffer& commandBuffer)
{
    id<MTLResource> resources[2] = {
        commandBuffer.GetBuffer().GetBuffer(),
        commandBuffer.GetCommandBuffer()
    };

    [m_RenderEncoder memoryBarrierWithResources:resources
                     count:2
                     afterStages:MTLRenderStageVertex | MTLRenderStageMesh
                     beforeStages:MTLRenderStageVertex | MTLRenderStageFragment | MTLRenderStageMesh];
}

void RenderEncoder::Draw(MTLPrimitiveType primitiveType, uint32_t vertexCount, uint32_t vertexOffset)
{
    [m_RenderEncoder drawPrimitives:primitiveType vertexStart:vertexOffset vertexCount:vertexCount];
}

void RenderEncoder::DrawIndexed(MTLPrimitiveType primitiveType, const Buffer& indexBuffer, uint32_t indexCount, uint32_t indexOffset)
{
    DrawIndexed(primitiveType, indexBuffer.GetBuffer(), indexCount, indexOffset);
}

void RenderEncoder::DrawIndexed(MTLPrimitiveType primitiveType, id<MTLBuffer> indexBuffer, uint32_t indexCount, uint32_t indexOffset)
{
    [m_RenderEncoder drawIndexedPrimitives:primitiveType indexCount:indexCount indexType:MTLIndexTypeUInt32 indexBuffer:indexBuffer indexBufferOffset:indexOffset];
}

void RenderEncoder::ExecuteIndirect(const IndirectCommandBuffer& commandBuffer, uint maxCommandCount)
{
    [m_RenderEncoder executeCommandsInBuffer:commandBuffer.GetCommandBuffer() withRange:NSMakeRange(0, maxCommandCount)];
}
