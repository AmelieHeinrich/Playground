#include "shadows.h"
#include "gbuffer.h"
#include "renderer/passes/debug_renderer.h"
#include "renderer/resource_io.h"



int ResolutionToIndex(ShadowResolution resolution)
{
    switch (resolution)
    {
        case ShadowResolution::LOW: return 0;
        case ShadowResolution::MEDIUM: return 1;
        case ShadowResolution::HIGH: return 2;
        case ShadowResolution::ULTRA: return 3;
    }
    return 0;
}

ShadowResolution IndexToResolution(int index)
{
    switch (index)
    {
        case 0: return ShadowResolution::LOW;
        case 1: return ShadowResolution::MEDIUM;
        case 2: return ShadowResolution::HIGH;
        case 3: return ShadowResolution::ULTRA;
    }
    return ShadowResolution::LOW;
}

ShadowPass::ShadowPass()
{
    // Hard RT Kernel
    m_HardRTKernel.Initialize("rt_shadows_cs");

    // CSM pipelines
    m_CullCascadesKernel.Initialize("cull_geometry");

    GraphicsPipelineDesc drawShadowDesc;
    drawShadowDesc.DepthEnabled = YES;
    drawShadowDesc.DepthFormat = MTLPixelFormatDepth32Float;
    drawShadowDesc.DepthFunc = MTLCompareFunctionLess;
    drawShadowDesc.VertexFunctionName = "shadow_vs";
    drawShadowDesc.FragmentFunctionName = "shadow_fs";
    drawShadowDesc.SupportsIndirect = YES;
    drawShadowDesc.DepthWriteEnabled = YES;
    m_DrawCascadesPipeline = GraphicsPipeline::Create(drawShadowDesc);

    m_FillCascadesKernel.Initialize("csm_visibility");

    // Shadow maps
    for (int i = 0; i < SHADOW_CASCADE_COUNT; ++i) {
        MTLTextureDescriptor* descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float width:(int)m_Resolution height:(int)m_Resolution mipmapped:NO];
        descriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite | MTLTextureUsageRenderTarget;

        m_ShadowCascades[i].Initialize(descriptor);
        m_ShadowCascades[i].SetLabel([NSString stringWithFormat:@"Shadow Cascade %d", i]);

        m_CascadeICBs[i].Initialize(true, MTLIndirectCommandTypeDrawIndexed, MAX_SCENE_INSTANCES);
        m_CascadeICBs[i].SetLabel([NSString stringWithFormat:@"Cascade Indirect Command Buffer %d", i]);
    }

    // Shadow Visibility Output
    MTLTextureDescriptor* descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm width:1 height:1 mipmapped:NO];
    descriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite | MTLTextureUsageRenderTarget;

    ResourceIO::CreateTexture(SHADOW_VISIBILITY_OUTPUT, descriptor);
}

void ShadowPass::Resize(int width, int height)
{
    ResourceIO::GetTexture(SHADOW_VISIBILITY_OUTPUT).Resize(width, height);
}

void ShadowPass::Render(CommandBuffer& cmdBuffer, World& world, Camera& camera)
{
    switch (m_Technique) {
        case ShadowTechnique::NONE:
            None(cmdBuffer, world, camera);
            break;
        case ShadowTechnique::CSM:
            CSM(cmdBuffer, world, camera);
            break;
        case ShadowTechnique::RAYTRACED_HARD:
            RaytracedHard(cmdBuffer, world, camera);
            break;
    }
}

void ShadowPass::DebugUI()
{
    // UI is now handled by SwiftUI
    
    // Check if resolution changed and resize shadow cascades
    if ((int)m_Resolution != m_ShadowCascades[0].Width()) {
        for (int i = 0; i < SHADOW_CASCADE_COUNT; ++i) {
            m_ShadowCascades[i].Resize((int)m_Resolution, (int)m_Resolution);
        }
    }
}

void ShadowPass::None(CommandBuffer& cmdBuffer, World& world, Camera& camera)
{
    Texture& visibility = ResourceIO::GetTexture(SHADOW_VISIBILITY_OUTPUT);

    RenderEncoder encoder = cmdBuffer.RenderPass(RenderPassInfo()
                                                 .AddTexture(visibility, true, simd::make_float4(1.0f, 1.0f, 1.0f, 1.0f))
                                                 .SetName(@"Shadow Pass (None)"));
    encoder.End();
}

void ShadowPass::RaytracedHard(CommandBuffer& cmdBuffer, World& world, Camera& camera)
{
    Texture& visibility = ResourceIO::GetTexture(SHADOW_VISIBILITY_OUTPUT);
    Texture& depth = ResourceIO::GetTexture(GBUFFER_DEPTH_OUTPUT);
    Texture& normal = ResourceIO::GetTexture(GBUFFER_NORMAL_OUTPUT);

    ComputeEncoder encoder = cmdBuffer.ComputePass(@"Shadow Pass (Raytraced Hard)");
    encoder.SetPipeline(m_HardRTKernel);
    encoder.SetTexture(visibility, 0);
    encoder.SetTexture(depth, 1);
    encoder.SetTexture(normal, 2);
    encoder.SetBuffer(world.GetSceneAB(), 0);
    encoder.Dispatch(
        MTLSizeMake((visibility.Width() + 7) / 8, (visibility.Height() + 7) / 8, 1),
        MTLSizeMake(8, 8, 1)
    );
    encoder.End();
}

void ShadowPass::CSM(CommandBuffer& cmdBuffer, World& world, Camera& camera)
{
    // 4 passes
    // - Update shadow cascades
    // - Generate draw lists
    // - Generate shadow maps
    // - Generate visibility mask

    if (m_UpdateCascades) UpdateCascades(cmdBuffer, world, camera);
    else {
        for (int i = 0; i < SHADOW_CASCADE_COUNT; i++) {
            DebugRendererPass::DrawFrustum(m_Cascades[i].Projection * m_Cascades[i].View);
        }
    }
    CullCascades(cmdBuffer, world, camera);
    DrawCascades(cmdBuffer, world, camera);
    PopulateCSMVisibility(cmdBuffer, world, camera);
}

void ShadowPass::UpdateCascades(CommandBuffer& cmdBuffer, World& world, Camera& camera)
{
    float near = camera.GetNearPlane();
    float far = camera.GetFarPlane();

    uint cascadeSize = (uint)m_Resolution;
    std::vector<float> splits(SHADOW_CASCADE_COUNT + 1);

    splits[0] = near;
    splits[SHADOW_CASCADE_COUNT] = far;
    for (int i = 1; i <= SHADOW_CASCADE_COUNT; i++) {
        float fraction = static_cast<float>(i) / SHADOW_CASCADE_COUNT;
        float linearSplit = near + (far - near) * fraction;
        float logSplit = near * std::pow(far / near, fraction);
        splits[i] = m_SplitLambda * logSplit + (1.0f - m_SplitLambda) * linearSplit;
    }

    // Camera-centered CSM: all cascades share the camera position as center
    simd::float3 center = camera.GetPosition();

    // Adjust light's up vector
    simd::float3 up = simd_make_float3(0.0f, 1.0f, 0.0f);
    if (abs(simd::dot(world.GetDirectionalLight().Direction, up)) > 0.999f) {
        up = simd_make_float3(1.0f, 0.0f, 0.0f);
    }

    for (int i = 0; i < SHADOW_CASCADE_COUNT; i++) {
        // Cascade size scales with split distance
        float cascadeRadius = splits[i + 1];
        cascadeRadius = simd::ceil(cascadeRadius * 16.0f) / 16.0f;

        // Shadow camera looks at center from light direction, far enough to capture shadow casters
        simd::float3 shadowCameraPos = center - world.GetDirectionalLight().Direction * cascadeRadius;

        simd::float4x4 lightView = matrix_look_at_right_hand(shadowCameraPos, center, up);
        
        // Ortho bounds: X/Y centered on camera, Z extends from shadow camera through the cascade volume
        // In view space, camera center is at Z = -cascadeRadius (right-hand, -Z forward)
        // We want Z range to go from 0 (at shadow camera) to 2*cascadeRadius (past the camera center)
        simd::float4x4 lightProjection = matrix_ortho_right_hand_z(
            -cascadeRadius,
            cascadeRadius,
            -cascadeRadius,
            cascadeRadius,
            0.0f,
            cascadeRadius * 2.0f
        );

        // Texel snapping
        {
            simd::float4x4 shadowMatrix = lightProjection * lightView;
            simd::float4 shadowOrigin = simd::make_float4(0.0f, 0.0f, 0.0f, 1.0f);
            shadowOrigin = shadowMatrix * shadowOrigin;
            shadowOrigin = simd_mul(shadowOrigin, matrix4x4_scale(simd::make_float3(cascadeSize / 2)));

            simd::float4 roundedOrigin = simd::round(shadowOrigin);
            simd::float4 roundedOffset = roundedOrigin - shadowOrigin;
            roundedOffset = roundedOffset * (2.0f / cascadeSize);
            roundedOffset.z = 0.0f;
            roundedOffset.w = 0.0f;
            lightProjection.columns[3] += roundedOffset;
        }

        m_Cascades[i].CascadeID = m_ShadowCascades[i].GetResourceID();
        m_Cascades[i].Projection = lightProjection;
        m_Cascades[i].View = lightView;
        m_Cascades[i].Split = splits[i + 1];
    }
}

void ShadowPass::CullCascades(CommandBuffer& cmdBuffer, World& world, Camera& camera)
{
    if (world.GetInstanceCount() == 0)
        return;

    uint instanceCount = world.GetInstanceCount();

    BlitEncoder resetIcbEncoder = cmdBuffer.BlitPass(@"Reset CSM ICBs");
    for (int i = 0; i < SHADOW_CASCADE_COUNT; i++) {
        resetIcbEncoder.ResetIndirectCommandBuffer(m_CascadeICBs[i], MAX_SCENE_INSTANCES);
    }
    resetIcbEncoder.End();

    ComputeEncoder computeEncoder = cmdBuffer.ComputePass(@"Cull Cascades");
    computeEncoder.SetPipeline(m_CullCascadesKernel);
    computeEncoder.SetBytes(&instanceCount, sizeof(uint), 3);
    computeEncoder.SetBuffer(world.GetSceneAB(), 0);
    for (int i = 0; i < SHADOW_CASCADE_COUNT; i++) {
        // Planes
        Plane planes[6];
        simd::float4x4 vp = m_Cascades[i].Projection * m_Cascades[i].View;
        extract_frustum_planes(vp, planes);

        uint dispatchCount = (world.GetInstanceCount() + 63) / 64;

        computeEncoder.PushGroup([NSString stringWithFormat:@"Cascade %d", i]);
        computeEncoder.SetBuffer(m_CascadeICBs[i].GetBuffer(), 1);
        computeEncoder.SetBytes(planes, sizeof(planes), 2);
        computeEncoder.Dispatch(MTLSizeMake(dispatchCount, 1, 1), MTLSizeMake(64, 1, 1));
        computeEncoder.PopGroup();
    }
    computeEncoder.End();

    // Optimize indirect command buffers
    BlitEncoder optimizeIcbEncoder = cmdBuffer.BlitPass(@"Optimize CSM ICBs");
    for (int i = 0; i < SHADOW_CASCADE_COUNT; i++) {
        optimizeIcbEncoder.OptimizeIndirectCommandBuffer(m_CascadeICBs[i], MAX_SCENE_INSTANCES);
    }
    optimizeIcbEncoder.End();
}

void ShadowPass::DrawCascades(CommandBuffer& cmdBuffer, World& world, Camera& camera)
{
    for (int i = 0; i < SHADOW_CASCADE_COUNT; i++) {
        simd::float4x4 vp = m_Cascades[i].Projection * m_Cascades[i].View;

        RenderEncoder encoder = cmdBuffer.RenderPass(RenderPassInfo()
                                                     .AddDepthStencilTexture(m_ShadowCascades[i], true)
                                                     .SetName([NSString stringWithFormat:@"Shadow Pass (Cascade %d)", i]));
        encoder.SetGraphicsPipeline(m_DrawCascadesPipeline);
        encoder.SetDepthClamp(true);
        encoder.SetBuffer(ShaderStage::VERTEX | ShaderStage::FRAGMENT, world.GetSceneAB(), 0);
        encoder.SetBytes(ShaderStage::VERTEX, &vp, sizeof(vp), 1);
        encoder.ExecuteIndirect(m_CascadeICBs[i], MAX_SCENE_INSTANCES);
        encoder.SignalFence();
        encoder.End();
    }
}

void ShadowPass::PopulateCSMVisibility(CommandBuffer& cmdBuffer, World& world, Camera& camera)
{
    Texture& depth = ResourceIO::GetTexture(GBUFFER_DEPTH_OUTPUT);
    Texture& normal = ResourceIO::GetTexture(GBUFFER_NORMAL_OUTPUT);
    Texture& visibility = ResourceIO::GetTexture(SHADOW_VISIBILITY_OUTPUT);

    uint shadowResolution = (uint)m_Resolution;

    ComputeEncoder encoder = cmdBuffer.ComputePass(@"Populate CSM Visibility");
    encoder.WaitForFence();
    encoder.SetPipeline(m_FillCascadesKernel);
    encoder.SetBuffer(world.GetSceneAB(), 0);
    encoder.SetBytes(m_Cascades, sizeof(m_Cascades), 1);
    encoder.SetTexture(depth, 0);
    encoder.SetTexture(normal, 1);
    encoder.SetTexture(visibility, 2);
    encoder.Dispatch(
        MTLSizeMake((visibility.Width() + 7) / 8, (visibility.Height() + 7) / 8, 1),
        MTLSizeMake(8, 8, 1)
    );
    encoder.End();
}
