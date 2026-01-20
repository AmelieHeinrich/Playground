#pragma once

#include "Renderer/Pass.h"
#include <simd/vector_make.h>
#include <vector>

constexpr uint kMaxDebugLines = 1'000'000;

struct LineVertex
{
    simd::float4 position;
    simd::float4 color;
};

class DebugRendererPass : public Pass
{
public:
    DebugRendererPass();
    ~DebugRendererPass() = default;

    void Render(CommandBuffer& cmdBuffer, World& world, Camera& camera) override;
    void DebugUI() override;
    void RegisterCVars() override;

    // Accessors for SwiftUI bridge
    bool GetUseDepth() const { return m_UseDepth; }
    void SetUseDepth(bool use) { m_UseDepth = use; }

    static void DrawLine(const simd::float4& start, const simd::float4& end, const simd::float3& color = simd::make_float3(1.0f, 1.0f, 1.0f));
    static void DrawLineV3(const simd::float3& start, const simd::float3& end, const simd::float3& color = simd::make_float3(1.0f, 1.0f, 1.0f));
    static void DrawTriangle(simd::float4x4 transform, const simd::float3& a, const simd::float3& b, const simd::float3& c, const simd::float3& color = simd::make_float3(1.0f, 1.0f, 1.0f));
    static void DrawArrow(const simd::float3& from, const simd::float3& to, const simd::float3& color = simd::make_float3(1.0f, 1.0f, 1.0f), float size = 0.1f);
    static void DrawUnitCube(simd::float4x4 transform, const simd::float3& color = simd::make_float3(1.0f, 1.0f, 1.0f));
    static void DrawCube(simd::float4x4 transform, const simd::float3& min, const simd::float3& max, const simd::float3& color = simd::make_float3(1.0f, 1.0f, 1.0f));
    static void DrawFrustum(simd::float4x4 projview, const simd::float3& color = simd::make_float3(1.0f, 1.0f, 1.0f));
    static void DrawCoordinateSystem(simd::float4x4 transform, float size);
    static void DrawSphere(const simd::float3& center, float radius, const simd::float3& color = simd::make_float3(1.0f, 1.0f, 1.0f), int level = 3);
    static void DrawRing(const simd::float3& center, const simd::float3& normal, float radius, const simd::float3& color = simd::make_float3(1.0f, 1.0f, 1.0f), int level = 32);
    static void DrawRings(const simd::float3& center, float radius, const simd::float3& color = simd::make_float3(1.0f, 1.0f, 1.0f), int level = 32);
    static void DrawQuad(simd::float4x4 transform, const simd::float3 corners[4], const simd::float3& color = simd::make_float3(1.0f, 1.0f, 1.0f));
    static void DrawCone(simd::float4x4 transform, const simd::float3& position, float size, const simd::float3& forward, float angle, const simd::float3& color = simd::make_float3(1.0f, 1.0f, 1.0f));
    static void DrawCapsule(simd::float4x4 transform, float height, float radius, const simd::float3& color = simd::make_float3(1.0f, 1.0f, 1.0f));

private:
    GraphicsPipeline m_DepthPipeline;
    GraphicsPipeline m_NoDepthPipeline;

    bool m_UseDepth = false;
    Buffer m_LineBuffer;

    static std::vector<LineVertex> s_LineVertices;
    
    static void DrawWireUnitSphereRecursive(simd::float4x4 matrix, const simd::float3& color, const simd::float3& dir1, const simd::float3& dir2, const simd::float3& dir3, int level);
};
