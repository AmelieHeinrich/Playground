#include "residency_set.h"
#include "metal/device.h"

API_AVAILABLE(macos(15.0))
void ResidencySet::Initialize()
{
    MTLResidencySetDescriptor* descriptor = [[MTLResidencySetDescriptor alloc] init];
    descriptor.initialCapacity = 1000;
    descriptor.label = @"ResidencySet";

    NSError* error = nil;
    m_ResidencySet = [Device::GetDevice() newResidencySetWithDescriptor:descriptor error:&error];
    if (error) {
        NSLog(@"Error creating residency set: %@", error);
    }
}

ResidencySet::~ResidencySet()
{
    [m_ResidencySet release];
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
