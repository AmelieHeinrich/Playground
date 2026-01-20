#include "Light.h"

LightList::LightList()
{
    m_PointLightBuffer.Initialize(sizeof(PointLight) * MAX_POINT_LIGHTS);
    m_PointLightBuffer.SetLabel(@"Point Light Buffer");
}

void LightList::Update()
{
    void* data = m_PointLightBuffer.Contents();
    memcpy(data, m_PointLights.data(), sizeof(PointLight) * m_PointLights.size());
}
