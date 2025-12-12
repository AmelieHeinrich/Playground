#pragma once

#include <Metal/Metal.h>

class API_AVAILABLE(macos(15.0)) ResidencySet
{
public:
    ResidencySet() = default;
    ~ResidencySet();

    void Initialize();
    void AddResource(id<MTLAllocation> resource);
    void RemoveResource(id<MTLAllocation> resource);
    
    void Update();

    id<MTLResidencySet> GetResidencySet() const { return m_ResidencySet; }
private:
    id<MTLResidencySet> m_ResidencySet;
    
    bool m_Dirty = false;
};
