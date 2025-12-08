#pragma once

#include <simd/simd.h>

class Input {
public:
    virtual ~Input() = default;

    virtual vector_float3 GetMoveVector() const = 0;
    virtual vector_float2 GetRotateVector() const = 0;
    virtual void Update(float deltaTime) = 0;
};
