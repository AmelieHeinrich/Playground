#include "ResidencySet.h"
#include "Metal/Device.h"
#include "Core/Logger.h"

API_AVAILABLE(macos(15.0))
void ResidencySet::Initialize()
{
    @autoreleasepool {
        MTLResidencySetDescriptor* descriptor = [MTLResidencySetDescriptor new];
        descriptor.initialCapacity = 1000;
        descriptor.label = @"ResidencySet";

        NSError* error = nil;
        m_ResidencySet = [Device::GetDevice() newResidencySetWithDescriptor:descriptor error:&error];
        if (error) {
            LOG_ERROR_FMT("Error creating residency set: %@", error);
        }
    }
}

ResidencySet::~ResidencySet()
{
    // With ARC, don't call release - just set to nil
    m_ResidencySet = nil;
}

API_AVAILABLE(macos(15.0))
void ResidencySet::AddResource(id<MTLAllocation> resource)
{
    [m_ResidencySet addAllocation:resource];
    m_Dirty = true;
}

API_AVAILABLE(macos(15.0))
void ResidencySet::RemoveResource(id<MTLAllocation> resource)
{
    [m_ResidencySet removeAllocation:resource];
    m_Dirty = true;
}

void ResidencySet::Update()
{
    if (m_Dirty) {
        [m_ResidencySet commit];
        m_Dirty = false;
    }
}