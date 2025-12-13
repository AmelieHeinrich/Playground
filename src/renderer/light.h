#pragma once

#include "metal/buffer.h"
#include <simd/simd.h>

#include <vector>

constexpr uint32_t MAX_POINT_LIGHTS = 4096;

struct PointLight
{
    simd::float3 Position;
    float Radius;

    simd::float3 Color;
    float Pad0;
};

class LightList
{
public:
    LightList();
    ~LightList() = default;

    void AddPointLight(const PointLight& light) { m_PointLights.push_back(light); }
    void Update();

    Buffer& GetPointLightBuffer() { return m_PointLightBuffer; }
    int GetPointLightCount() { return (int)m_PointLights.size();  }
private:
    Buffer m_PointLightBuffer;

    std::vector<PointLight> m_PointLights;
};
