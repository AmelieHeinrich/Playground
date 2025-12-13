#pragma once

#include "asset/mesh_loader.h"

#include <simd/quaternion.h>
#include <simd/simd.h>
#include <vector>

#include "light.h"

struct Entity
{
    Model Mesh;

    simd::float3 Position;
    simd::quatf Rotation;
    simd::float3 Scale;
};

class World
{
public:
    World() = default;
    ~World() = default;

    void Update();
    
    Entity& AddModel(const std::string& modelPath);
    std::vector<Entity>& GetEntities() { return m_Entities; };

    LightList& GetLightList() { return m_LightList; }
private:
    std::vector<Entity> m_Entities;
    LightList m_LightList;
};
