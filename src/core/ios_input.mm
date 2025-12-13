#include "ios_input.h"

#import <GameController/GameController.h>
#include <imgui.h>

IOSInput::IOSInput()
    : m_MoveVector(simd_make_float3(0.0f, 0.0f, 0.0f))
    , m_RotateVector(simd_make_float2(0.0f, 0.0f))
{
    // Set up controller connection notifications
    [[NSNotificationCenter defaultCenter] addObserverForName:GCControllerDidConnectNotification
                                                       object:nil
                                                        queue:[NSOperationQueue mainQueue]
                                                   usingBlock:^(NSNotification *note) {
        GCController *controller = note.object;
        NSLog(@"Game controller connected: %@", controller.vendorName);
    }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:GCControllerDidDisconnectNotification
                                                       object:nil
                                                        queue:[NSOperationQueue mainQueue]
                                                   usingBlock:^(NSNotification *note) {
        GCController *controller = note.object;
        NSLog(@"Game controller disconnected: %@", controller.vendorName);
    }];
    
    // Start discovering controllers
    [GCController startWirelessControllerDiscoveryWithCompletionHandler:nil];
}

vector_float3 IOSInput::GetMoveVector() const
{
    return m_MoveVector;
}

vector_float2 IOSInput::GetRotateVector() const
{
    return m_RotateVector;
}

void IOSInput::Update(float deltaTime)
{
    // Reset move and rotate vectors
    m_MoveVector = simd_make_float3(0.0f, 0.0f, 0.0f);
    m_RotateVector = simd_make_float2(0.0f, 0.0f);
    
    // Get the first connected controller
    GCController *controller = [GCController controllers].firstObject;
    
    if (!controller) {
        return;
    }
    
    // Get extended gamepad (supports thumbsticks)
    GCExtendedGamepad *gamepad = controller.extendedGamepad;
    
    if (!gamepad) {
        return;
    }
    
    // Left thumbstick -> Move vector (X, Y, Z)
    // X: left/right strafe
    // Y: up/down (use shoulder buttons or triggers)
    // Z: forward/backward
    float leftX = gamepad.leftThumbstick.xAxis.value;
    float leftY = gamepad.leftThumbstick.yAxis.value;
    
    m_MoveVector.x = leftX;  // Strafe left/right
    m_MoveVector.z = leftY;  // Move forward/backward
    
    // Use shoulder buttons for up/down movement
    if (gamepad.rightShoulder.isPressed) {
        m_MoveVector.y = 1.0f;  // Move up
    }
    if (gamepad.leftShoulder.isPressed) {
        m_MoveVector.y = -1.0f;  // Move down
    }
    
    // Right thumbstick -> Rotation vector
    float rightX = gamepad.rightThumbstick.xAxis.value;
    float rightY = gamepad.rightThumbstick.yAxis.value;
    
    // Apply deadzone
    const float deadzone = 0.1f;
    if (fabsf(rightX) < deadzone) rightX = 0.0f;
    if (fabsf(rightY) < deadzone) rightY = 0.0f;
    
    m_RotateVector.x = -rightX * 2.0f;   // Horizontal rotation
    m_RotateVector.y = rightY * 2.0f;  // Vertical rotation (inverted for natural camera control)
}
