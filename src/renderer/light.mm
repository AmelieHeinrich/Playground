#include "light.h"

LightList::LightList()
{
    m_PointLightBuffer.Initialize(sizeof(PointLight) * MAX_POINT_LIGHTS);
}

void LightList::Update()
{
    void* data = m_PointLightBuffer.Contents();
    memcpy(data, m_PointLights.data(), sizeof(PointLight) * m_PointLights.size());
}
