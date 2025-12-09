#include "ios_input.h"

#import <GameController/GameController.h>
#include <imgui.h>

IOSInput::IOSInput()
    : m_MoveVector(simd_make_float3(0.0f, 0.0f, 0.0f))
    , m_RotateVector(simd_make_float2(0.0f, 0.0f))
    , m_CurrentMousePos(simd_make_float2(0.0f, 0.0f))
    , m_PreviousMousePos(simd_make_float2(0.0f, 0.0f))
    , m_FirstMouse(true)
    , m_MouseButtonDown(false)
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
    ImGuiIO& io = ImGui::GetIO();

    if (io.WantCaptureMouse || !m_MouseButtonDown || m_FirstMouse) {
        return simd_make_float2(0.0f, 0.0f);
    }

    vector_float2 delta = m_CurrentMousePos - m_PreviousMousePos;
    return -simd_make_float2(delta.x, delta.y) * 0.3f;
}

void IOSInput::Update(float deltaTime)
{
    ImGuiIO& io = ImGui::GetIO();
    
    // Update mouse position tracking
    m_PreviousMousePos = m_CurrentMousePos;
    m_CurrentMousePos = simd_make_float2(io.MousePos.x, io.MousePos.y);

    // Track mouse button state (touch acts as left mouse button in ImGui)
    bool isMouseDown = !io.WantCaptureMouse && ImGui::IsMouseDown(ImGuiMouseButton_Left);

    if (isMouseDown) {
        if (!m_MouseButtonDown) {
            m_FirstMouse = true;
            m_PreviousMousePos = m_CurrentMousePos;
        } else {
            m_FirstMouse = false;
        }
        m_MouseButtonDown = true;
    } else {
        m_MouseButtonDown = false;
        m_FirstMouse = true;
    }
    
    // Reset move vector
    m_MoveVector = simd_make_float3(0.0f, 0.0f, 0.0f);
    
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
}
