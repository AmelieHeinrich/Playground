# Input Focus Management

This document describes the input focus management system that prevents camera/game input when UI elements (like text fields) have focus.

## Problem

When typing in SwiftUI text fields (console command input, search fields, etc.), the keyboard input was still being processed by the game's input system. This caused:

- Camera movement when typing WASD
- Unwanted game actions when typing commands
- Poor user experience when interacting with UI elements

## Solution

A hierarchical input control system that allows SwiftUI views to disable game input when they need keyboard focus.

## Architecture

### 1. Input Base Class (`src/Core/Input.h`)

Added enabled state to the base Input class:

```cpp
class Input {
public:
    void SetEnabled(bool enabled) { m_Enabled = enabled; }
    bool IsEnabled() const { return m_Enabled; }

protected:
    bool m_Enabled = true;
};
```

### 2. Platform Input Implementation (`src/Core/MacosInput.mm`)

Modified `GetMoveVector()` to check enabled state before processing keyboard input:

```cpp
vector_float3 MacOSInput::GetMoveVector() const
{
    // Don't process keyboard input if input is disabled
    if (!IsEnabled()) {
        return simd_make_float3(0.0f, 0.0f, 0.0f);
    }
    
    // Process WASD, Space, Shift keys...
}
```

### 3. ApplicationBridge (`src/Swift/ApplicationBridge.h/mm`)

Added `inputEnabled` property to control input from Swift:

```objc
@property (nonatomic) BOOL inputEnabled;
```

Implementation synchronizes with the C++ Input system:

```objc
- (void)setInputEnabled:(BOOL)enabled {
    _inputEnabled = enabled;
    _application->GetInput().SetEnabled(enabled);
}
```

### 4. InputController (`src/Swift/Views/InputController.swift`)

Created an `@Observable` class to manage input state across SwiftUI views:

```swift
@Observable
class InputController {
    var bridge: ApplicationBridge?
    
    func setInputEnabled(_ enabled: Bool) {
        bridge?.inputEnabled = enabled
    }
}
```

### 5. Environment Integration

Added `InputController` to SwiftUI environment:

```swift
extension EnvironmentValues {
    var inputController: InputController? {
        get { self[InputControllerKey.self] }
        set { self[InputControllerKey.self] = newValue }
    }
}
```

### 6. View Focus Tracking

Views with text fields track focus state and disable input accordingly:

**Console Command Input:**
```swift
@FocusState private var isFocused: Bool
@Environment(\.inputController) private var inputController

TextField("Enter command...", text: $viewModel.commandText)
    .focused($isFocused)
    .onChange(of: isFocused) { _, focused in
        inputController?.setInputEnabled(!focused)
    }
```

**Console Search Field:**
```swift
@FocusState private var searchFocused: Bool
@Environment(\.inputController) private var inputController

TextField("Search...", text: $viewModel.searchText)
    .focused($searchFocused)
    .onChange(of: searchFocused) { _, focused in
        inputController?.setInputEnabled(!focused)
    }
```

## Flow Diagram

```
User clicks text field
    ↓
SwiftUI @FocusState changes
    ↓
onChange(of: isFocused) triggers
    ↓
InputController.setInputEnabled(false)
    ↓
ApplicationBridge.inputEnabled = false
    ↓
Input.SetEnabled(false)
    ↓
MacOSInput.GetMoveVector() returns (0,0,0)
    ↓
Camera doesn't move while typing
```

## Usage

### Adding Focus Tracking to New Text Fields

1. Add the environment variable and focus state:
```swift
@FocusState private var isFocused: Bool
@Environment(\.inputController) private var inputController
```

2. Attach to your TextField:
```swift
TextField("...", text: $text)
    .focused($isFocused)
    .onChange(of: isFocused) { _, focused in
        inputController?.setInputEnabled(!focused)
    }
```

### Manually Controlling Input

You can manually disable/enable input from any view with access to InputController:

```swift
@Environment(\.inputController) private var inputController

Button("Disable Input") {
    inputController?.setInputEnabled(false)
}
```

## Benefits

1. **Automatic**: Text fields automatically disable game input when focused
2. **Hierarchical**: Uses SwiftUI's environment system for clean propagation
3. **Extensible**: Easy to add to new text fields or UI elements
4. **Platform-aware**: Works with both macOS and iOS input systems
5. **Type-safe**: Swift's type system prevents misuse

## Files Modified

### C++ Layer
- `src/Core/Input.h` - Added enabled state
- `src/Core/MacosInput.mm` - Check enabled state before processing keyboard
- `src/Swift/ApplicationBridge.h` - Added inputEnabled property
- `src/Swift/ApplicationBridge.mm` - Implemented inputEnabled synchronization

### Swift Layer
- `src/Swift/Views/InputController.swift` - New InputController class and environment key
- `src/Swift/Views/ContentView.swift` - Initialize and provide InputController
- `src/Swift/Views/ConsoleView.swift` - Track focus in search and command fields

## Testing

To verify the fix:

1. Run the application
2. Open the console (bottom panel)
3. Click in the command input field
4. Type WASD keys
5. **Expected**: Camera should NOT move
6. Click outside the text field
7. Type WASD keys
8. **Expected**: Camera SHOULD move

## Future Improvements

Potential enhancements:

1. **Visual Indicator**: Show when input is disabled (e.g., dim camera icon)
2. **Keyboard Shortcuts**: Allow certain shortcuts even when text fields are focused
3. **Focus History**: Track which field last had focus for better UX
4. **Input Lock**: Temporary lock input during certain game states
5. **Partial Disable**: Disable only certain inputs (e.g., movement but not mouse look)

## Related Systems

- **Camera System** (`src/Core/Camera.h/mm`) - Consumes input for movement/rotation
- **MetalViewRepresentable** (`src/Swift/MetalViewRepresentable.swift`) - Metal view that handles mouse input
- **ConsoleBridge** (`src/Swift/ConsoleBridge.h/mm`) - Console command system