#include "world.h"

void World::Update()
{
    m_LightList.Update();
}

Entity& World::AddModel(const std::string& path)
{
    Entity entity;
    entity.Mesh.Load(path);
    entity.Position = simd_make_float3(0, 0, 0);
    entity.Scale = simd_make_float3(1, 1, 1);

    m_Entities.push_back(entity);
    return m_Entities.back();
}
