#include "command_buffer.h"
#include "device.h"
#include "metal/render_encoder.h"
#include <Metal/Metal.h>

CommandBuffer::CommandBuffer(NSString* name)
{
    m_CommandBuffer = [Device::GetCommandQueue() commandBuffer];
    m_CommandBuffer.label = name;
}

void CommandBuffer::Commit()
{
    [m_CommandBuffer commit];
}

RenderEncoder CommandBuffer::RenderPass(const RenderPassInfo& info)
{
    MTLRenderPassDescriptor* descriptor = [MTLRenderPassDescriptor new];
    for (int i = 0; i < info.Textures.size(); i++) {
        descriptor.colorAttachments[i].texture = info.Textures[i];
        descriptor.colorAttachments[i].loadAction = info.ShouldClear[i] ? MTLLoadActionClear : MTLLoadActionLoad;
        descriptor.colorAttachments[i].clearColor = MTLClearColorMake(info.ClearColors[i].r, info.ClearColors[i].g, info.ClearColors[i].b, info.ClearColors[i].a);
        descriptor.colorAttachments[i].storeAction = MTLStoreActionStore;
    }

    if (info.DepthStencilTexture) {
        descriptor.depthAttachment.texture = info.DepthStencilTexture;
        descriptor.depthAttachment.loadAction = info.ShouldClearDepthStencil ? MTLLoadActionClear : MTLLoadActionLoad;
        descriptor.depthAttachment.clearDepth = 1.0f;
        descriptor.depthAttachment.storeAction = MTLStoreActionStore;
    }

    return RenderEncoder(m_CommandBuffer, descriptor, info.Name);
}
