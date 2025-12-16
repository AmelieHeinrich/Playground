#pragma once

#import <Metal/Metal.h>
#include <vector>
#include <mutex>

// Fence wrapper for encoder-to-encoder synchronization
//
// Usage example:
//   // First pass signals a fence
//   BlitEncoder blit = cmdBuffer.BlitPass(@"Reset ICB");
//   blit.ResetIndirectCommandBuffer(icb, count);
//   Fence syncPoint = blit.End();  // Returns a fence that will be signaled
//
//   // Second pass waits on that fence
//   ComputeEncoder compute = cmdBuffer.ComputePass(@"Cull Geometry", &syncPoint);
//   compute.SetPipeline(cullPipeline);
//   compute.SetBuffer(sceneBuffer, 0);
//   Fence syncPoint2 = compute.End();
//
//   // Third pass waits on second pass
//   RenderEncoder render = cmdBuffer.RenderPass(renderPassInfo, &syncPoint2);
//   render.SetGraphicsPipeline(pipeline);
//   Fence finalSync = render.End();
//
//   // Fences are automatically recycled after use
//   Fence::Release(finalSync);

class Fence
{
public:
    Fence();
    ~Fence() = default;

    id<MTLFence> GetFence() const { return m_Fence; }
    bool IsValid() const { return m_Fence != nil; }

private:
    id<MTLFence> m_Fence;
};
