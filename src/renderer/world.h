#pragma once

#include "asset/mesh_loader.h"

#include <simd/quaternion.h>
#include <simd/simd.h>
#include <vector>

#include "core/camera.h"
#include "scene_ab.h"

struct Entity
{
    Model Mesh;
};

class World
{
public:
    World();
    ~World() = default;

    void Update(Camera& camera);

    Entity& AddModel(const std::string& modelPath);
    std::vector<Entity>& GetEntities() { return m_Entities; };

    LightList& GetLightList() { return m_LightList; }
    Buffer& GetSceneAB() { return m_SceneAB; }

    uint GetInstanceCount() const { return m_SceneInstances.size(); }
private:
    std::vector<Entity> m_Entities;
    LightList m_LightList;

    SceneArgumentBuffer m_SceneArgumentBuffer;
    std::vector<SceneMaterial> m_SceneMaterials;
    std::vector<SceneInstance> m_SceneInstances;
    SceneCamera m_SceneCamera;

    Buffer m_SceneAB;
    Buffer m_InstanceBuffer;
    Buffer m_MaterialBuffer;
    Buffer m_CameraBuffer;
};
