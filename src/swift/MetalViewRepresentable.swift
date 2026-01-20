import SwiftUI
import MetalKit

#if os(macOS)
import AppKit

// Custom MTKView subclass that handles input events directly
class InputCapturingMTKView: MTKView {
    weak var appBridge: ApplicationBridge?

    override var acceptsFirstResponder: Bool {
        return true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        // Become first responder when added to window
        if window != nil {
            window?.makeFirstResponder(self)
        }
    }

    // Mouse position helper
    private func viewMousePosition(for event: NSEvent) -> simd_float2 {
        let locationInWindow = event.locationInWindow
        let locationInView = convert(locationInWindow, from: nil)
        // Flip Y (macOS origin bottom-left, Metal expects top-left)
        let flippedY = bounds.height - locationInView.y
        return simd_float2(Float(locationInView.x), Float(flippedY))
    }

    // Mouse movement tracking
    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        // Remove old tracking areas
        for area in trackingAreas {
            removeTrackingArea(area)
        }

        // Add new tracking area
        let options: NSTrackingArea.Options = [
            .activeAlways,
            .inVisibleRect,
            .mouseMoved,
            .mouseEnteredAndExited
        ]

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: options,
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    override func mouseEntered(with event: NSEvent) {
        // Only claim first responder if current responder is not a text field
        // This prevents stealing focus from console input
        if let currentResponder = window?.firstResponder as? NSView,
           !(currentResponder is NSTextView || currentResponder is NSTextField) {
            window?.makeFirstResponder(self)
        }
    }

    override func mouseMoved(with event: NSEvent) {
        let pos = viewMousePosition(for: event)
        appBridge?.setMousePosition(pos)
    }

    override func mouseDown(with event: NSEvent) {
        // Always claim first responder on click
        window?.makeFirstResponder(self)
        let pos = viewMousePosition(for: event)
        appBridge?.setMousePosition(pos)
    }

    override func mouseUp(with event: NSEvent) {
        let pos = viewMousePosition(for: event)
        appBridge?.setMousePosition(pos)
    }

    override func mouseDragged(with event: NSEvent) {
        let pos = viewMousePosition(for: event)
        appBridge?.setMousePosition(pos)
    }

    override func rightMouseDown(with event: NSEvent) {
        // Always claim first responder on right-click
        window?.makeFirstResponder(self)
        let pos = viewMousePosition(for: event)
        appBridge?.setMousePosition(pos)
        appBridge?.setRightMouseDown(true)
    }

    override func rightMouseUp(with event: NSEvent) {
        let pos = viewMousePosition(for: event)
        appBridge?.setMousePosition(pos)
        appBridge?.setRightMouseDown(false)
    }

    override func rightMouseDragged(with event: NSEvent) {
        let pos = viewMousePosition(for: event)
        appBridge?.setMousePosition(pos)
    }

    override func scrollWheel(with event: NSEvent) {
        // Available for future use
    }

    // Keyboard events - suppress beep
    // Suppress keyboard beep by overriding keyDown/keyUp without calling super
    override func keyDown(with event: NSEvent) {
        // Don't call super to prevent beep sound
        // Keyboard input is handled via CGEventSource polling in MacOSInput
    }

    override func keyUp(with event: NSEvent) {
        // Don't call super to prevent beep
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}

struct MetalViewRepresentable: NSViewRepresentable {
    let bridge: ApplicationBridge

    func makeNSView(context: Context) -> InputCapturingMTKView {
        let mtkView = InputCapturingMTKView(frame: .zero, device: bridge.device)
        mtkView.delegate = bridge
        mtkView.appBridge = bridge
        mtkView.enableSetNeedsDisplay = false
        mtkView.preferredFramesPerSecond = 60
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.framebufferOnly = false

        return mtkView
    }

    func updateNSView(_ nsView: InputCapturingMTKView, context: Context) {
        // Don't steal focus during updates
    }
}

#else
// iOS implementation
struct MetalViewRepresentable: UIViewRepresentable {
    let bridge: ApplicationBridge

    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView(frame: .zero, device: bridge.device)
        mtkView.delegate = bridge
        mtkView.enableSetNeedsDisplay = false
        mtkView.preferredFramesPerSecond = 60
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.framebufferOnly = false

        return mtkView
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        // Nothing to update
    }
}
#endif
