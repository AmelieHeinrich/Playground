#include "ios_input.h"

#import <GameController/GameController.h>

IOSInput::IOSInput()
{

}

vector_float3 IOSInput::GetMoveVector() const
{
    return simd_make_float3(0.0f, 0.0f, 0.0f);
}

vector_float2 IOSInput::GetRotateVector() const
{
    return simd_make_float2(0.0f, 0.0f);
}

void IOSInput::Update(float deltaTime)
{
}
