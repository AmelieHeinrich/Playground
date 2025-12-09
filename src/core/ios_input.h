#pragma once

#include "input.h"

class IOSInput : public Input
{
public:
    IOSInput();
    virtual ~IOSInput() = default;

    vector_float3 GetMoveVector() const override;
    vector_float2 GetRotateVector() const override;
    void Update(float deltaTime) override;
};
