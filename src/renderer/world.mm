#include "world.h"
#include "metal/acceleration_encoder.h"
#include "metal/command_buffer.h"
#include "passes/debug_renderer.h"
#include <CoreData/CoreData.h>
#include <simd/quaternion.h>

World::World()
{
    m_SceneAB.Initialize(sizeof(SceneArgumentBuffer));
    m_SceneAB.SetLabel(@"Scene Argument Buffer");

    m_InstanceBuffer.Initialize(sizeof(SceneInstance) * MAX_SCENE_INSTANCES);
    m_InstanceBuffer.SetLabel(@"Scene Instance Buffer");

    m_MaterialBuffer.Initialize(sizeof(SceneMaterial) * MAX_SCENE_MATERIALS);
    m_MaterialBuffer.SetLabel(@"Scene Material Buffer");

    m_CameraBuffer.Initialize(sizeof(SceneCamera));
    m_CameraBuffer.SetLabel(@"Scene Camera Buffer");

    m_TLAS.Initialize();
    m_TLAS.SetLabel(@"Top Level Acceleration Structure");
}

World::~World()
{
    for (auto& entity : m_Entities) {
        delete entity->BLAS;
        delete entity;
    }
}

void World::Prepare()
{
    CommandBuffer cmdBuffer;

    AccelerationEncoder encoder = cmdBuffer.AccelerationPass(@"Build BLASes");
    for (auto& entity : m_Entities) {
        encoder.BuildBLAS(entity->BLAS);
    }
    encoder.End();
    cmdBuffer.Commit();

    for (auto& entity : m_Entities) {
        entity->BLAS->FreeScratchBuffer();
    }
}

void World::Update(Camera& camera)
{
    m_LightList.Update();

    // Update scene argument buffer
    m_SceneArgumentBuffer.PointLightCount = m_LightList.GetPointLightCount();
    m_SceneArgumentBuffer.PointLightBufferID = m_LightList.GetPointLightBuffer().GetResourceID();
    m_SceneArgumentBuffer.InstanceBufferID = m_InstanceBuffer.GetResourceID();
    m_SceneArgumentBuffer.CameraBufferID = m_CameraBuffer.GetResourceID();
    m_SceneArgumentBuffer.MaterialBufferID = m_MaterialBuffer.GetResourceID();
    m_SceneArgumentBuffer.SceneTLASID = m_TLAS.GetResourceID();

    // Update camera buffer
    m_SceneCamera.View = camera.GetViewMatrix();
    m_SceneCamera.Projection = camera.GetProjectionMatrix();
    m_SceneCamera.ViewProjection = camera.GetViewProjectionMatrix();
    m_SceneCamera.InverseView = simd::inverse(camera.GetViewMatrix());
    m_SceneCamera.InverseProjection = simd::inverse(camera.GetProjectionMatrix());
    m_SceneCamera.InverseViewProjection = simd::inverse(camera.GetViewProjectionMatrix());
    m_SceneCamera.Position = camera.GetPosition();
    m_SceneCamera.Near = camera.GetNearPlane();
    m_SceneCamera.Far = camera.GetFarPlane();

    // Update scene materials and instances
    m_SceneMaterials.clear();
    m_SceneInstances.clear();

    // Material cache: maps (AlbedoID, NormalID, MetallicRoughnessID) to material index
    std::unordered_map<uint64_t, uint32_t> materialCache;

    // Helper lambda to get or create a material index
    auto GetOrCreateMaterial = [&](uint64_t albedoID, uint64_t normalID, uint64_t metallicRoughnessID, bool hasAlbedo, bool hasNormal, bool hasMetallicRoughness) -> uint32_t {
        // Create a hash key from the texture IDs and boolean flags
        uint64_t boolFlags = (hasAlbedo ? 1ULL : 0ULL) |
                            (hasNormal ? 2ULL : 0ULL) |
                            (hasMetallicRoughness ? 4ULL : 0ULL);
        uint64_t key = albedoID ^ (normalID << 1) ^ (metallicRoughnessID << 2) ^ (boolFlags << 3);

        auto it = materialCache.find(key);
        if (it != materialCache.end()) {
            return it->second;
        }

        // Material not in cache, create new one
        uint32_t materialIndex = static_cast<uint32_t>(m_SceneMaterials.size());

        SceneMaterial material;
        material.AlbedoID = albedoID;
        material.NormalID = normalID;
        material.MetallicRoughnessID = metallicRoughnessID;
        material.HasAlbedo = hasAlbedo;
        material.HasNormal = hasNormal;
        material.HasMetallicRoughness = hasMetallicRoughness;

        m_SceneMaterials.push_back(material);
        materialCache[key] = materialIndex;

        return materialIndex;
    };

    // Loop over entities and create instances
    m_TLAS.ResetInstanceBuffer();
    for (const Entity* entity : m_Entities) {
        const Model& model = entity->Mesh;
        m_TLAS.AddInstance(entity->BLAS);

        // Create instances for each mesh in the model
        for (const Mesh& mesh : model.Meshes) {
            SceneInstance instance;
            instance.VertexBufferID = model.VertexBuffer.GetResourceID();
            instance.IndexBufferID = model.IndexBuffer.GetResourceID();
            instance.IndexCount = mesh.IndexCount;
            instance.IndexOffset = mesh.IndexOffset;

            // Get or create material
            if (mesh.MaterialIndex >= 0 && mesh.MaterialIndex < model.Materials.size()) {
                const MeshMaterial& meshMat = model.Materials[mesh.MaterialIndex];

                uint64_t albedoID = 0;
                uint64_t normalID = 0;
                uint64_t metallicRoughnessID = 0;

                // Get texture resource IDs
                if (meshMat.AlbedoIndex >= 0 && meshMat.AlbedoIndex < model.Textures.size() && model.Textures[meshMat.AlbedoIndex].Texture) {
                    albedoID = model.Textures[meshMat.AlbedoIndex].Texture->GetResourceID();
                }
                if (meshMat.NormalIndex >= 0 && meshMat.NormalIndex < model.Textures.size() && model.Textures[meshMat.NormalIndex].Texture) {
                    normalID = model.Textures[meshMat.NormalIndex].Texture->GetResourceID();
                }
                if (meshMat.PBRIndex >= 0 && meshMat.PBRIndex < model.Textures.size() && model.Textures[meshMat.PBRIndex].Texture) {
                    metallicRoughnessID = model.Textures[meshMat.PBRIndex].Texture->GetResourceID();
                }

                bool hasAlbedo = meshMat.AlbedoIndex != -1;
                bool hasNormal = meshMat.NormalIndex != -1;
                bool hasMetallicRoughness = meshMat.PBRIndex != -1;

                instance.MaterialID = GetOrCreateMaterial(albedoID, normalID, metallicRoughnessID, hasAlbedo, hasNormal, hasMetallicRoughness);
            } else {
                instance.MaterialID = GetOrCreateMaterial(0, 0, 0, false, false, false);
            }
            instance.Min = mesh.Min;
            instance.Max = mesh.Max;

            m_SceneInstances.push_back(instance);
        }
    }
    m_TLAS.Update();

    // Write to the buffers
    if (!m_SceneInstances.empty()) {
        m_InstanceBuffer.Write(m_SceneInstances.data(), sizeof(SceneInstance) * m_SceneInstances.size());
    }
    if (!m_SceneMaterials.empty()) {
        m_MaterialBuffer.Write(m_SceneMaterials.data(), sizeof(SceneMaterial) * m_SceneMaterials.size());
    }
    m_CameraBuffer.Write(&m_SceneCamera, sizeof(SceneCamera));
    m_SceneAB.Write(&m_SceneArgumentBuffer, sizeof(SceneArgumentBuffer));
}

Entity& World::AddModel(const std::string& path)
{
    Entity* entity = new Entity;
    entity->Mesh.Load(path);
    entity->BLAS = new BLAS(entity->Mesh);
    entity->BLAS->SetLabel([NSString stringWithUTF8String:path.c_str()]);

    m_Entities.push_back(entity);
    return *m_Entities.back();
}
