#pragma once

#include "asset/mesh_loader.h"

#include <simd/quaternion.h>
#include <simd/simd.h>
#include <vector>

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

    Entity& AddModel(const std::string& modelPath);
    std::vector<Entity>& GetEntities() { return m_Entities; };
private:
    std::vector<Entity> m_Entities;
};
