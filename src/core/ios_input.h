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

private:
    vector_float3 m_MoveVector;
    vector_float2 m_RotateVector;
    vector_float2 m_CurrentMousePos;
    vector_float2 m_PreviousMousePos;
    bool m_FirstMouse;
    bool m_MouseButtonDown;
};
