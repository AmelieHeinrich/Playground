#include "debug_renderer.h"
#include "deferred.h"
#include "gbuffer.h"

#include "renderer/resource_io.h"
#include "math/AAPLMath.h"

#include <imgui.h>
#include <simd/vector_make.h>
#include <cmath>

std::vector<LineVertex> DebugRendererPass::s_LineVertices;

DebugRendererPass::DebugRendererPass()
{
    // Pipelines
    GraphicsPipelineDesc desc;
    desc.VertexFunctionName = "debug_vs";
    desc.FragmentFunctionName = "debug_fs";
    desc.ColorFormats = { MTLPixelFormatRGBA16Float };
    m_NoDepthPipeline = GraphicsPipeline::Create(desc);

    desc.DepthEnabled = true;
    desc.DepthWriteEnabled = false;
    desc.DepthFunc = MTLCompareFunctionLess;
    desc.DepthFormat = MTLPixelFormatDepth32Float;
    m_DepthPipeline = GraphicsPipeline::Create(desc);

    // Line buffer
    m_LineBuffer.Initialize(kMaxDebugLines * sizeof(LineVertex));
    m_LineBuffer.SetLabel(@"Debug Line Buffer");
}

void DebugRendererPass::Render(CommandBuffer& cmdBuffer, World& world, Camera& camera)
{
    // Copy
    void* contents = m_LineBuffer.Contents();
    memcpy(contents, s_LineVertices.data(), s_LineVertices.size() * sizeof(LineVertex));

    // Render
    Texture& color = ResourceIO::GetTexture(DEFERRED_COLOR);
    Texture& depth = ResourceIO::GetTexture(GBUFFER_DEPTH_OUTPUT);

    RenderPassInfo info = RenderPassInfo().AddTexture(color, false).SetName(@"Debug Renderer Pass");
    if (m_UseDepth) {
        info = info.AddDepthStencilTexture(depth, false, false);
    }

    simd::float4x4 cameraMatrix = camera.GetViewProjectionMatrix();

    RenderEncoder encoder = cmdBuffer.RenderPass(info);
    encoder.SetGraphicsPipeline(m_UseDepth ? m_DepthPipeline : m_NoDepthPipeline);
    encoder.SetBuffer(ShaderStage::VERTEX, m_LineBuffer, 0);
    encoder.SetBytes(ShaderStage::VERTEX, &cameraMatrix, sizeof(cameraMatrix), 1);
    encoder.Draw(MTLPrimitiveTypeLine, (uint32_t)s_LineVertices.size(), 0);
    encoder.End();

    s_LineVertices.clear();
}

void DebugRendererPass::DebugUI()
{
    if (ImGui::TreeNodeEx("Debug Renderer", ImGuiTreeNodeFlags_Framed)) {
        ImGui::Checkbox("Use Depth", &m_UseDepth);
        ImGui::TreePop();
    }
}

void DebugRendererPass::DrawLine(const simd::float4& start, const simd::float4& end, const simd::float3& color)
{
    if (s_LineVertices.size() + 2 >= kMaxDebugLines)
        return;
    
    s_LineVertices.push_back({ start, simd_make_float4(color, 1.0f) });
    s_LineVertices.push_back({ end, simd_make_float4(color, 1.0f) });
}

void DebugRendererPass::DrawLineV3(const simd::float3& start, const simd::float3& end, const simd::float3& color)
{
    s_LineVertices.push_back({ simd_make_float4(start, 1.0f), simd_make_float4(color, 1.0f) });
    s_LineVertices.push_back({ simd_make_float4(end, 1.0f), simd_make_float4(color, 1.0f) });
}

void DebugRendererPass::DrawUnitCube(simd::float4x4 transform, const simd::float3& color)
{
    DrawCube(transform, simd_make_float3(-1.0f, -1.0f, -1.0f), simd_make_float3(1.0f, 1.0f, 1.0f), color);
}

void DebugRendererPass::DrawCube(simd::float4x4 transform, const simd::float3& min, const simd::float3& max, const simd::float3& color)
{
    simd::float4 v1 = transform * simd_make_float4(min.x, min.y, min.z, 1.0);
    simd::float4 v2 = transform * simd_make_float4(min.x, min.y, max.z, 1.0);
    simd::float4 v3 = transform * simd_make_float4(min.x, max.y, min.z, 1.0);
    simd::float4 v4 = transform * simd_make_float4(min.x, max.y, max.z, 1.0);
    simd::float4 v5 = transform * simd_make_float4(max.x, min.y, min.z, 1.0);
    simd::float4 v6 = transform * simd_make_float4(max.x, min.y, max.z, 1.0);
    simd::float4 v7 = transform * simd_make_float4(max.x, max.y, min.z, 1.0);
    simd::float4 v8 = transform * simd_make_float4(max.x, max.y, max.z, 1.0);

    // Draw 12 edges of the box
    DrawLine(v1, v2, color); // Edge 1
    DrawLine(v1, v3, color); // Edge 2
    DrawLine(v1, v5, color); // Edge 3
    DrawLine(v2, v4, color); // Edge 4
    DrawLine(v2, v6, color); // Edge 5
    DrawLine(v3, v4, color); // Edge 6
    DrawLine(v3, v7, color); // Edge 7
    DrawLine(v4, v8, color); // Edge 8
    DrawLine(v5, v6, color); // Edge 9
    DrawLine(v5, v7, color); // Edge 10
    DrawLine(v6, v8, color); // Edge 11
    DrawLine(v7, v8, color); // Edge 12
}

void DebugRendererPass::DrawTriangle(simd::float4x4 transform, const simd::float3& a, const simd::float3& b, const simd::float3& c, const simd::float3& color)
{
    simd::float4 v1 = transform * simd_make_float4(a, 1.0);
    simd::float4 v2 = transform * simd_make_float4(b, 1.0);
    simd::float4 v3 = transform * simd_make_float4(c, 1.0);

    // Draw 3 edges of the triangle
    DrawLine(v1, v2, color); // Edge 1
    DrawLine(v2, v3, color); // Edge 2
    DrawLine(v3, v1, color); // Edge 3
}

void DebugRendererPass::DrawArrow(const simd::float3& from, const simd::float3& to, const simd::float3& color, float size)
{
    DrawLineV3(from, to, color);

    if (size > 0.0f) {
        simd::float3 dir = to - from;
        float len = simd_length(dir);
        if (len != 0.0f)
            dir = dir * (size / len);
        else
            dir = simd_make_float3(size, 0, 0);

        simd::float3 perpendicular = simd_make_float3(0.0f, 0.0f, 0.0f);
        if (std::abs(dir.x) > std::abs(dir.y)) {
            float len = std::sqrt(dir.x * dir.x + dir.y * dir.y);
            perpendicular = simd_make_float3(dir.z, 0.0f, -dir.x) / len;
        } else {
            float len = std::sqrt(dir.y * dir.y + dir.z * dir.z);
            perpendicular = simd_make_float3(0.0f, dir.z, -dir.y) / len;
        }

        DrawLineV3(to - dir + perpendicular, to, color);
        DrawLineV3(to - dir - perpendicular, to, color);
    }
}

void DebugRendererPass::DrawFrustum(simd::float4x4 projview, const simd::float3& color)
{
    simd::float3 corners[8] = {
        simd_make_float3(-1.0f,  1.0f, 0.0f),
        simd_make_float3( 1.0f,  1.0f, 0.0f),
        simd_make_float3( 1.0f, -1.0f, 0.0f),
        simd_make_float3(-1.0f, -1.0f, 0.0f),
        simd_make_float3(-1.0f,  1.0f, 1.0f),
        simd_make_float3( 1.0f,  1.0f, 1.0f),
        simd_make_float3( 1.0f, -1.0f, 1.0f),
        simd_make_float3(-1.0f, -1.0f, 1.0f),
    };

    simd::float4x4 invProjView = simd_inverse(projview);
    
    // To convert from world space to NDC space, multiply by the inverse of the camera matrix then perspective divide
    for (int i = 0; i < 8; i++) {
        simd::float4 v = simd_make_float4(corners[i], 1.0);
        simd::float4 h = invProjView * v;
        h.x /= h.w;
        h.y /= h.w;
        h.z /= h.w;
        corners[i] = simd_make_float3(h.x, h.y, h.z);
    }

    for (int i = 0; i < 4; i++) {
        DrawLineV3(corners[i % 4],     corners[(i + 1) % 4],     color);
        DrawLineV3(corners[i],         corners[i + 4],           color);
        DrawLineV3(corners[i % 4 + 4], corners[(i + 1) % 4 + 4], color);
    }
}

void DebugRendererPass::DrawCoordinateSystem(simd::float4x4 transform, float size)
{
    simd::float3 translation = simd_make_float3(transform.columns[3].x, transform.columns[3].y, transform.columns[3].z);
    DrawArrow(translation, simd_make_float3((transform * simd_make_float4(size, 0, 0, 1.0f)).xyz), simd_make_float3(1.0f, 0.0f, 0.0f), 0.1f * size);
    DrawArrow(translation, simd_make_float3((transform * simd_make_float4(0, size, 0, 1.0f)).xyz), simd_make_float3(0.0f, 1.0f, 0.0f), 0.1f * size);
    DrawArrow(translation, simd_make_float3((transform * simd_make_float4(0, 0, size, 1.0f)).xyz), simd_make_float3(0.0f, 0.0f, 1.0f), 0.1f * size);
}

void DebugRendererPass::DrawSphere(const simd::float3& center, float radius, const simd::float3& color, int level)
{
    simd::float4x4 translation = matrix4x4_translation(center);
    simd::float4x4 scale = matrix4x4_scale(radius, radius, radius);
    simd::float4x4 matrix = matrix_multiply(translation, scale);
    
    simd::float3 xAxis = simd_make_float3(1.0f, 0.0f, 0.0f);
    simd::float3 yAxis = simd_make_float3(0.0f, 1.0f, 0.0f);
    simd::float3 zAxis = simd_make_float3(0.0f, 0.0f, 1.0f);

    DrawWireUnitSphereRecursive(matrix, color,  xAxis,  yAxis,  zAxis, level);
    DrawWireUnitSphereRecursive(matrix, color, -xAxis,  yAxis,  zAxis, level);
    DrawWireUnitSphereRecursive(matrix, color,  xAxis, -yAxis,  zAxis, level);
    DrawWireUnitSphereRecursive(matrix, color, -xAxis, -yAxis,  zAxis, level);
    DrawWireUnitSphereRecursive(matrix, color,  xAxis,  yAxis, -zAxis, level);
    DrawWireUnitSphereRecursive(matrix, color, -xAxis,  yAxis, -zAxis, level);
    DrawWireUnitSphereRecursive(matrix, color,  xAxis, -yAxis, -zAxis, level);
    DrawWireUnitSphereRecursive(matrix, color, -xAxis, -yAxis, -zAxis, level);
}

void DebugRendererPass::DrawRing(const simd::float3& center, const simd::float3& normal, float radius, const simd::float3& color, int level)
{
    int numSegments = std::max(level, 3);

    simd::float3 tangent;
    if (std::abs(normal.y) > 0.99f) {
        tangent = simd_make_float3(1.0f, 0.0f, 0.0f);
    } else {
        tangent = simd_normalize(simd_cross(normal, simd_make_float3(0.0f, 1.0f, 0.0f)));
    }
    simd::float3 bitangent = simd_normalize(simd_cross(normal, tangent));

    float angleStep = (2.0f * M_PI) / numSegments;
    simd::float3 prevPoint = center + radius * tangent;

    for (int i = 1; i <= numSegments; ++i) {
        float angle = i * angleStep;
        simd::float3 nextPoint = center + radius * (std::cos(angle) * tangent + std::sin(angle) * bitangent);

        DrawLineV3(prevPoint, nextPoint, color);

        prevPoint = nextPoint;
    }
}

void DebugRendererPass::DrawRings(const simd::float3& center, float radius, const simd::float3& color, int level)
{
    DrawRing(center, simd_make_float3(1.0f, 0.0f, 0.0f), radius, color, level);
    DrawRing(center, simd_make_float3(0.0f, 1.0f, 0.0f), radius, color, level);
    DrawRing(center, simd_make_float3(0.0f, 0.0f, 1.0f), radius, color, level);
}

void DebugRendererPass::DrawWireUnitSphereRecursive(simd::float4x4 matrix, const simd::float3& color, const simd::float3& dir1, const simd::float3& dir2, const simd::float3& dir3, int level)
{
    if (level == 0) {
        simd::float4 d1 = matrix * simd_make_float4(dir1, 1.0f);
        simd::float4 d2 = matrix * simd_make_float4(dir2, 1.0f);
        simd::float4 d3 = matrix * simd_make_float4(dir3, 1.0f);

        DrawLine(d1, d2, color);
        DrawLine(d2, d3, color);
        DrawLine(d3, d1, color);
    } else {
        simd::float3 center1 = simd_normalize(dir1 + dir2);
        simd::float3 center2 = simd_normalize(dir2 + dir3);
        simd::float3 center3 = simd_normalize(dir3 + dir1);

        DrawWireUnitSphereRecursive(matrix, color, dir1, center1, center3, level - 1);
        DrawWireUnitSphereRecursive(matrix, color, center1, center2, center3, level - 1);
        DrawWireUnitSphereRecursive(matrix, color, center1, dir2, center2, level - 1);
        DrawWireUnitSphereRecursive(matrix, color, center3, center2, dir3, level - 1);
    }
}

void DebugRendererPass::DrawQuad(simd::float4x4 transform, const simd::float3 corners[4], const simd::float3& color)
{
    // Transform the 4 corners to world space
    simd::float3 v0 = simd_make_float3((transform * simd_make_float4(corners[0], 1.0f)).xyz);
    simd::float3 v1 = simd_make_float3((transform * simd_make_float4(corners[1], 1.0f)).xyz);
    simd::float3 v2 = simd_make_float3((transform * simd_make_float4(corners[2], 1.0f)).xyz);
    simd::float3 v3 = simd_make_float3((transform * simd_make_float4(corners[3], 1.0f)).xyz);

    // Draw the quad edges (assumes corners ordered consistently)
    DrawLineV3(v0, v1, color);
    DrawLineV3(v1, v2, color);
    DrawLineV3(v2, v3, color);
    DrawLineV3(v3, v0, color);
}

void DebugRendererPass::DrawCone(simd::float4x4 transform, const simd::float3& position, float size, const simd::float3& forward, float angle, const simd::float3& color)
{
    simd::float3 pos = simd_make_float3((transform * simd_make_float4(position, 1.0f)).xyz);
    const int ringSegments = 16;

    // Normalize forward vector to ensure correct calculations
    simd::float3 normalizedForward = simd_normalize(forward);

    // Compute cone base center
    simd::float3 endCenter = pos + normalizedForward * size;

    // Get cone base radius
    float angleRad = angle / 2.0f;
    float radius = size * std::tan(angleRad);

    // Generate orthonormal basis for ring
    simd::float3 up = std::abs(normalizedForward.y) < 0.99f ? simd_make_float3(0,1,0) : simd_make_float3(1,0,0);
    simd::float3 right = simd_normalize(simd_cross(normalizedForward, up));
    up = simd_normalize(simd_cross(right, normalizedForward)); // Complete the orthonormal basis

    // Draw base ring
    DrawRing(endCenter, normalizedForward, radius, color);

    // Draw cone edges (connect apex to points on the base circle)
    for (int i = 0; i < ringSegments; i += ringSegments / 4) {
        float theta = (float)i / (float)ringSegments * 2.0f * M_PI;
        float x = std::cos(theta) * radius;
        float y = std::sin(theta) * radius;
        simd::float3 ringPoint = endCenter + right * x + up * y;
        DrawLineV3(pos, ringPoint, color);
    }

    // Optional: draw forward direction line (axis of the cone)
    DrawArrow(pos, endCenter, color);
}

void DebugRendererPass::DrawCapsule(simd::float4x4 transform, float height, float radius, const simd::float3& color)
{
    const int segments = 32;
    const int hemiSegments = 16;

    float halfCyl = height * 0.5f;

    simd::float3 bottom = simd_make_float3(0, -halfCyl, 0);
    simd::float3 top = simd_make_float3(0, halfCyl, 0);

    auto X = [&](simd::float3 p) {
        return simd_make_float3((transform * simd_make_float4(p, 1.0f)).xyz);
    };

    // -----------------------------
    // 1) Top and bottom circles
    // -----------------------------
    for (int i = 0; i < segments; i++) {
        float a0 = (i     / float(segments)) * 2.0f * M_PI;
        float a1 = ((i+1) / float(segments)) * 2.0f * M_PI;

        simd::float3 offset0 = simd_make_float3(std::cos(a0)*radius, 0, std::sin(a0)*radius);
        simd::float3 offset1 = simd_make_float3(std::cos(a1)*radius, 0, std::sin(a1)*radius);

        DrawLineV3(X(bottom + offset0), X(bottom + offset1), color);
        DrawLineV3(X(top    + offset0), X(top    + offset1), color);
    }

    // -----------------------------
    // 2) Cylinder vertical lines
    // -----------------------------
    const int verticalRays = 8;
    for (int i = 0; i < verticalRays; i++) {
        float a = (i / float(verticalRays)) * 2.0f * M_PI;
        simd::float3 dir = simd_make_float3(std::cos(a)*radius, 0, std::sin(a)*radius);

        DrawLineV3(X(bottom + dir), X(top + dir), color);
    }

    // -----------------------------
    // 3) Hemispheres
    // -----------------------------
    for (int i = 0; i < segments; i++) {
        float phi = (i / float(segments)) * 2.0f * M_PI;
        float cphi = std::cos(phi);
        float sphi = std::sin(phi);

        for (int j = 0; j < hemiSegments; j++) {
            float t0 = (j     / float(hemiSegments)) * (M_PI / 2.0f);
            float t1 = ((j+1) / float(hemiSegments)) * (M_PI / 2.0f);

            float ct0 = std::cos(t0), st0 = std::sin(t0);
            float ct1 = std::cos(t1), st1 = std::sin(t1);

            // bottom hemisphere arc
            simd::float3 b0 = simd_make_float3(cphi * ct0 * radius, -halfCyl - st0 * radius, sphi * ct0 * radius);
            simd::float3 b1 = simd_make_float3(cphi * ct1 * radius, -halfCyl - st1 * radius, sphi * ct1 * radius);
            DrawLineV3(X(b0), X(b1), color);

            // top hemisphere arc
            simd::float3 t0p = simd_make_float3(cphi * ct0 * radius, halfCyl + st0 * radius, sphi * ct0 * radius);
            simd::float3 t1p = simd_make_float3(cphi * ct1 * radius, halfCyl + st1 * radius, sphi * ct1 * radius);
            DrawLineV3(X(t0p), X(t1p), color);
        }
    }
}
