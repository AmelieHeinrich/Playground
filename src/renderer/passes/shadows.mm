#include "shadows.h"
#include "gbuffer.h"
#include "math/AAPLMath.h"
#include "metal/blit_encoder.h"
#include "metal/compute_encoder.h"
#include "renderer/resource_io.h"
#include "renderer/scene_ab.h"

#include <Foundation/Foundation.h>
#include <Metal/Metal.h>
#include <cfloat>
#include <imgui.h>
#include <simd/common.h>
#include <simd/geometry.h>
#include <simd/math.h>
#include <simd/matrix.h>
#include <simd/quaternion.h>
#include <simd/vector_make.h>

ShadowPass::ShadowPass()
{
    // Hard RT Kernel
    m_HardRTKernel.Initialize("rt_shadows_cs");

    // CSM pipelines
    m_CullCascadesKernel.Initialize("cull_geometry");

    // Shadow maps
    for (int i = 0; i < SHADOW_CASCADE_COUNT; ++i) {
        MTLTextureDescriptor* descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float width:(int)m_Resolution height:(int)m_Resolution mipmapped:NO];
        descriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite | MTLTextureUsageRenderTarget;

        m_ShadowCascades[i] = std::make_shared<Texture>(descriptor);
        m_ShadowCascades[i]->SetLabel([NSString stringWithFormat:@"Shadow Cascade %d", i]);

        m_CascadeICBs[i] = std::make_shared<IndirectCommandBuffer>();
        m_CascadeICBs[i]->Initialize(true, MTLIndirectCommandTypeDrawIndexed, MAX_SCENE_INSTANCES);
        m_CascadeICBs[i]->SetLabel([NSString stringWithFormat:@"Cascade Indirect Command Buffer %d", i]);
    }

    // Shadow Visibility Output
    MTLTextureDescriptor* descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm width:1 height:1 mipmapped:NO];
    descriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite | MTLTextureUsageRenderTarget;

    ResourceIO::CreateTexture(SHADOW_VISIBILITY_OUTPUT, descriptor);
}

void ShadowPass::Resize(int width, int height)
{
    ResourceIO::GetTexture(SHADOW_VISIBILITY_OUTPUT).Resize(width, height);

    if ((int)m_Resolution != m_ShadowCascades[0]->Width()) {
        // Resize
        for (int i = 0; i < SHADOW_CASCADE_COUNT; ++i) {
            m_ShadowCascades[i]->Resize((int)m_Resolution, (int)m_Resolution);
        }
    }
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
    if (ImGui::TreeNodeEx("Shadows", ImGuiTreeNodeFlags_Framed)) {
        const char* techniques[] = {"None", "Raytraced Hard", "CSM"};
        int selected = static_cast<int>(m_Technique);
        ImGui::Combo("Technique", &selected, techniques, IM_ARRAYSIZE(techniques));
        m_Technique = static_cast<ShadowTechnique>(selected);

        if (m_Technique == ShadowTechnique::CSM) {
            ImGui::Separator();

            const char* resolutions[] = {"Low", "Medium", "High", "Ultra"};
            int selected = static_cast<int>(m_Resolution);
            ImGui::Combo("Resolution", &selected, resolutions, IM_ARRAYSIZE(resolutions));
            m_Resolution = static_cast<ShadowResolution>(selected);

            ImGui::SliderFloat("Split Lambda", &m_SplitLambda, 0.01f, 1.0f);
        }

        ImGui::TreePop();
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

    UpdateCascades(cmdBuffer, world, camera);
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

    for (int i = 0; i < SHADOW_CASCADE_COUNT; i++) {
        simd::float4x4 projection = matrix_perspective_right_hand(radians_from_degrees(camera.GetFieldOfView()), camera.GetAspectRatio(), splits[i], splits[i + 1]);
        std::vector<simd::float4> corners = get_frustum_corners(camera.GetViewMatrix(), projection);

        simd::float3 center = simd_make_float3(0.0f);
        for (const simd::float4& corner : corners) {
            center += corner.xyz;
        }
        center /= corners.size();

        // Adjust light's up vector
        simd::float3 up = simd_make_float3(0.0f, 1.0f, 0.0f);
        if (abs(simd::dot(world.GetDirectionalLight().Direction, up)) > 0.999f) {
            up = simd_make_float3(1.0f, 0.0f, 0.0f);
        }

        // Calculate light-space bounding sphere
        simd::float3 minBounds(-FLT_MIN), maxBounds(-FLT_MAX);
        float sphereRadius = 0.0f;
        for (auto& corner : corners) {
            float dist = simd::length(corner.xyz - center);
            sphereRadius = simd::max(sphereRadius, dist);
        }
        sphereRadius = simd::ceil(sphereRadius * 16.0f) / 16.0f;
        maxBounds = simd::make_float3(sphereRadius);
        minBounds = -maxBounds;

        // Get extents and create view matrix
        simd::float3 cascadeExtents = maxBounds - minBounds;
        simd::float3 shadowCameraPos = center - world.GetDirectionalLight().Direction;

        simd::float4x4 lightView = matrix_look_at_right_hand(shadowCameraPos, center, up);
        simd::float4x4 lightProjection = matrix_ortho_right_hand(
            minBounds.x,
            maxBounds.x,
            minBounds.y,
            maxBounds.y,
            minBounds.z,
            maxBounds.z
        );

        // Texel snap
        {
            simd::float4x4 shadowMatrix = lightProjection * lightView;
            simd::float4 shadowOrigin = simd::make_float4(0.0f, 0.0f, 0.0f, 1.0f);
            shadowOrigin = shadowMatrix * shadowOrigin;
            shadowOrigin = simd_mul(matrix4x4_scale(simd::make_float3(cascadeSize / 2)), shadowOrigin);

            simd::float4 roundedOrigin = simd::round(shadowOrigin);
            simd::float4 roundedOffset = roundedOrigin - shadowOrigin;
            roundedOffset = roundedOffset * (2.0f / cascadeSize);
            roundedOffset.z = 0.0f;
            roundedOffset.w = 0.0f;
            lightProjection.columns[3] += roundedOffset;
        }

        m_Cascades[i].CascadeID = m_ShadowCascades[i]->GetResourceID();
        m_Cascades[i].Projection = lightProjection;
        m_Cascades[i].View = lightView;
        m_Cascades[i].Split = splits[i + 1];
    }
}

void ShadowPass::CullCascades(CommandBuffer& cmdBuffer, World& world, Camera& camera)
{
    if (world.GetInstanceCount() == 0)
        return;

    BlitEncoder resetIcbEncoder = cmdBuffer.BlitPass(@"Reset CSM ICBs");
    for (int i = 0; i < SHADOW_CASCADE_COUNT; i++) {
        resetIcbEncoder.ResetIndirectCommandBuffer(*m_CascadeICBs[i], MAX_SCENE_INSTANCES);
    }
    resetIcbEncoder.End();

    ComputeEncoder computeEncoder = cmdBuffer.ComputePass(@"Cull Cascades");
    computeEncoder.SetPipeline(m_CullCascadesKernel);
    for (int i = 0; i < SHADOW_CASCADE_COUNT; i++) {
        // Planes
        Plane planes[6];
        simd::float4x4 vp = m_Cascades[i].Projection * m_Cascades[i].View;
        extract_frustum_planes(vp, planes);

        uint dispatchCount = (world.GetInstanceCount() + 63) / 64;

        computeEncoder.PushGroup([NSString stringWithFormat:@"Cascade %d", i]);
        computeEncoder.SetBuffer(world.GetSceneAB(), 0);
        computeEncoder.SetBuffer(m_CascadeICBs[i]->GetBuffer(), 1);
        computeEncoder.SetBytes(planes, sizeof(planes), 2);
        computeEncoder.Dispatch(MTLSizeMake(dispatchCount, 1, 1), MTLSizeMake(64, 1, 1));
        computeEncoder.PopGroup();
    }
    computeEncoder.End();

    // Optimize indirect command buffers
    BlitEncoder optimizeIcbEncoder = cmdBuffer.BlitPass(@"Optimize CSM ICBs");
    for (int i = 0; i < SHADOW_CASCADE_COUNT; i++) {
        optimizeIcbEncoder.OptimizeIndirectCommandBuffer(*m_CascadeICBs[i], MAX_SCENE_INSTANCES);
    }
    optimizeIcbEncoder.End();
}

void ShadowPass::DrawCascades(CommandBuffer& cmdBuffer, World& world, Camera& camera)
{
    // Generate shadow maps
}

void ShadowPass::PopulateCSMVisibility(CommandBuffer& cmdBuffer, World& world, Camera& camera)
{
    // Generate visibility mask

    // TODO:
    Texture& visibility = ResourceIO::GetTexture(SHADOW_VISIBILITY_OUTPUT);
    RenderEncoder encoder = cmdBuffer.RenderPass(RenderPassInfo()
                                                 .AddTexture(visibility, true, simd::make_float4(1.0f, 1.0f, 1.0f, 1.0f))
                                                 .SetName(@"Shadow Pass (None)"));
    encoder.End();
}
