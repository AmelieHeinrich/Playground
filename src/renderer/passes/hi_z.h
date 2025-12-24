#pragma once

#include "renderer/pass.h"

constexpr const char* HI_Z_MIPCHAIN = "HiZ/MipChain";

class HiZPass : public Pass
{
public:
    HiZPass();
    ~HiZPass() = default;

    void Resize(int width, int height) override;
    void Render(CommandBuffer& cmdBuffer, World& world, Camera& camera) override;
private:
    ComputePipeline m_ComputePipeline;
};
