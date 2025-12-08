#include "app_delegate.h"
#import "metal_view.h"
#include <objc/objc.h>
#include <imgui.h>
#include <imgui_impl_metal.h>

#if !TARGET_OS_IPHONE
#include <imgui_impl_osx.h>
#endif

#if TARGET_OS_IPHONE
// iOS Implementation
@implementation AppDelegate {
    Application *_application;
    CFTimeInterval _lastFrameTime;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Create Metal device
    self.device = MTLCreateSystemDefaultDevice();
    if (!self.device) {
        NSLog(@"Metal is not supported on this device");
        return NO;
    }

    NSLog(@"Metal device created: %@", [self.device name]);

    // Create the main window
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor blackColor];

    // Create MTKView
    self.metalView = [[MetalView alloc] initWithFrame:self.window.bounds device:self.device];
    self.metalView.delegate = self;
    self.metalView.enableSetNeedsDisplay = NO;
    self.metalView.preferredFramesPerSecond = 60;
    self.metalView.colorPixelFormat = MTLPixelFormatBGRA8Unorm;

    // Create a view controller for the Metal view
    UIViewController *rootViewController = [[UIViewController alloc] init];
    rootViewController.view = self.metalView;

    self.window.rootViewController = rootViewController;
    [self.window makeKeyAndVisible];

    // Create command queue
    self.commandQueue = [self.device newCommandQueue];

    // Initialize ImGui
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO(); (void)io;
    io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;
    io.ConfigFlags |= ImGuiConfigFlags_NavEnableGamepad;
    io.ConfigFlags |= ImGuiConfigFlags_DockingEnable;

    // Setup Dear ImGui style based on system appearance
#if TARGET_OS_IPHONE
    if (@available(iOS 13.0, *)) {
        UIUserInterfaceStyle style = UITraitCollection.currentTraitCollection.userInterfaceStyle;
        if (style == UIUserInterfaceStyleDark) {
            ImGui::StyleColorsDark();
            NSLog(@"Using dark theme");
        } else {
            ImGui::StyleColorsLight();
            NSLog(@"Using light theme");
        }
    } else {
        ImGui::StyleColorsDark();
    }
#else
    ImGui::StyleColorsDark();
#endif

    // Load custom font
    NSString* fontPath = [[NSBundle mainBundle] pathForResource:@"SFMonoRegular"
                                                         ofType:@"ttf"
                                                    inDirectory:@"assets/fonts"];
    if (fontPath) {
        io.FontDefault = io.Fonts->AddFontFromFileTTF([fontPath UTF8String], 16.0f);
        NSLog(@"Loaded SF Mono font from: %@", fontPath);
    } else {
        NSLog(@"Warning: Could not find SFMonoRegular.ttf, using default font");
    }

    // Setup Platform/Renderer backends
    ImGui_ImplMetal_Init(self.device);
    // Note: iOS backend initialization would go here when available

    // Initialize Application
    _application = new Application();
    if (!_application->Initialize(self.device)) {
        NSLog(@"Failed to initialize Application");
        return NO;
    }

    // Send initial resize event
    CGSize size = self.metalView.drawableSize;
    _application->OnResize((uint32_t)size.width, (uint32_t)size.height);

    // Observe trait collection changes for theme updates
    if (@available(iOS 13.0, *)) {
        [self.window.rootViewController.view addObserver:self
                                              forKeyPath:@"traitCollection"
                                                 options:NSKeyValueObservingOptionNew
                                                 context:nil];
    }

    return YES;
}

- (UIInterfaceOrientationMask)application:(UIApplication *)application 
    supportedInterfaceOrientationsForWindow:(UIWindow *)window {
    return UIInterfaceOrientationMaskLandscape;
}

- (void)updateImGuiTheme {
#if TARGET_OS_IPHONE
    if (@available(iOS 13.0, *)) {
        UIUserInterfaceStyle style = UITraitCollection.currentTraitCollection.userInterfaceStyle;
        if (style == UIUserInterfaceStyleDark) {
            ImGui::StyleColorsDark();
        } else {
            ImGui::StyleColorsLight();
        }
    }
#endif
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    if ([keyPath isEqualToString:@"traitCollection"]) {
        [self updateImGuiTheme];
        NSLog(@"Theme changed");
    }
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, etc.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate
    if (@available(iOS 13.0, *)) {
        [self.window.rootViewController.view removeObserver:self forKeyPath:@"traitCollection"];
    }

    ImGui_ImplMetal_Shutdown();
    ImGui::DestroyContext();

    if (_application) {
        delete _application;
        _application = nullptr;
    }
}

// MTKViewDelegate methods
- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    if (_application) {
        _application->OnResize((uint32_t)size.width, (uint32_t)size.height);
    }
}

- (void)drawInMTKView:(MTKView *)view {
    if (!_application) {
        return;
    }

    CFTimeInterval currentTime = CACurrentMediaTime();
    float deltaTime = _lastFrameTime > 0.0 ? (float)(currentTime - _lastFrameTime) : 0.016f;
    _lastFrameTime = currentTime;

    _application->OnUpdate(deltaTime);

    ImGuiIO& io = ImGui::GetIO();
    io.DisplaySize.x = view.bounds.size.width;
    io.DisplaySize.y = view.bounds.size.height;

    CGFloat framebufferScale = view.window.screen.scale ?: UIScreen.mainScreen.scale;
    io.DisplayFramebufferScale = ImVec2(framebufferScale, framebufferScale);

    MTLRenderPassDescriptor* renderPassDescriptor = view.currentRenderPassDescriptor;

    if (renderPassDescriptor == nil) {
        return;
    }

    // Start the Dear ImGui frame
    ImGui_ImplMetal_NewFrame(renderPassDescriptor);
    ImGui::NewFrame();

    // Call application UI callback
    _application->OnUI();

    // Rendering
    ImGui::Render();

    // Application rendering (separate command buffer for compute, blit, AS, etc.)
    id<MTLCommandBuffer> renderCommandBuffer = [self.commandQueue commandBuffer];
    _application->OnRender(renderCommandBuffer, view.currentDrawable);
    [renderCommandBuffer commit];

    // Presentation command buffer (for final UI and presentation)
    id<MTLCommandBuffer> presentationCommandBuffer = [self.commandQueue commandBuffer];
    [presentationCommandBuffer setLabel:@"Presentation"];

    // Simple clear color
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.1, 0.1, 0.1, 1.0);
    renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionLoad;
    renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;

    id<MTLRenderCommandEncoder> renderEncoder = [presentationCommandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];

    // Render ImGui
    [renderEncoder pushDebugGroup:@"ImGui"];
    ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(), presentationCommandBuffer, renderEncoder);
    [renderEncoder popDebugGroup];

    [renderEncoder endEncoding];

    // Present
    [presentationCommandBuffer presentDrawable:view.currentDrawable];
    [presentationCommandBuffer commit];
}

-(void)updateIOWithTouchEvent:(UIEvent *)event
{
    UITouch *anyTouch = event.allTouches.anyObject;
    CGPoint touchLocation = [anyTouch locationInView:self.metalView];
    ImGuiIO &io = ImGui::GetIO();
    io.AddMouseSourceEvent(ImGuiMouseSource_TouchScreen);
    io.AddMousePosEvent(touchLocation.x, touchLocation.y);

    BOOL hasActiveTouch = NO;
    for (UITouch *touch in event.allTouches)
    {
        if (touch.phase != UITouchPhaseEnded && touch.phase != UITouchPhaseCancelled)
        {
            hasActiveTouch = YES;
            break;
        }
    }
    io.AddMouseButtonEvent(0, hasActiveTouch);
}

-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event      { [self updateIOWithTouchEvent:event]; }
-(void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event      { [self updateIOWithTouchEvent:event]; }
-(void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event  { [self updateIOWithTouchEvent:event]; }
-(void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event      { [self updateIOWithTouchEvent:event]; }

@end

#else
// macOS Implementation
@implementation AppDelegate {
    Application *_application;
    CFTimeInterval _lastFrameTime;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    // Set up application menu with Cmd+Q support
    [self setupApplicationMenu];

    // Create Metal device
    self.device = MTLCreateSystemDefaultDevice();
    if (!self.device) {
        NSLog(@"Metal is not supported on this device");
        return;
    }

    NSLog(@"Metal device created: %@", [self.device name]);

    // Create the main window
    NSRect frame = NSMakeRect(0, 0, 1280, 720);
    self.window = [[NSWindow alloc] initWithContentRect:frame
                                              styleMask:(NSWindowStyleMaskTitled |
                                                        NSWindowStyleMaskClosable |
                                                        NSWindowStyleMaskMiniaturizable |
                                                        NSWindowStyleMaskResizable)
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];

    [self.window setTitle:@"Metal Playground"];
    [self.window center];

    // Create MTKView
    self.metalView = [[MetalView alloc] initWithFrame:frame device:self.device];
    self.metalView.delegate = self;
    self.metalView.enableSetNeedsDisplay = NO;
    self.metalView.preferredFramesPerSecond = 60;
    self.metalView.colorPixelFormat = MTLPixelFormatBGRA8Unorm;

    [self.window setContentView:self.metalView];
    [self.window makeKeyAndOrderFront:nil];
    [self.window makeFirstResponder:self.metalView];

    // Create command queue
    self.commandQueue = [self.device newCommandQueue];

    // Initialize ImGui
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO(); (void)io;
    io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;
    io.ConfigFlags |= ImGuiConfigFlags_NavEnableGamepad;
    io.ConfigFlags |= ImGuiConfigFlags_DockingEnable;
    io.ConfigFlags |= ImGuiConfigFlags_ViewportsEnable;

    // Setup Dear ImGui style based on system appearance
    NSString* osxMode = [[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"];
    if ([osxMode isEqualToString:@"Dark"]) {
        ImGui::StyleColorsDark();
        NSLog(@"Using dark theme");
    } else {
        ImGui::StyleColorsLight();
        NSLog(@"Using light theme");
    }

    // When viewports are enabled we tweak WindowRounding/WindowBg
    ImGuiStyle& style = ImGui::GetStyle();
    if (io.ConfigFlags & ImGuiConfigFlags_ViewportsEnable) {
        style.WindowRounding = 0.0f;
        style.Colors[ImGuiCol_WindowBg].w = 1.0f;
    }

    // Load custom font
    NSString* fontPath = [[NSBundle mainBundle] pathForResource:@"SFMonoRegular"
                                                         ofType:@"ttf"
                                                    inDirectory:@"assets/fonts"];
    if (fontPath) {
        io.FontDefault = io.Fonts->AddFontFromFileTTF([fontPath UTF8String], 16.0f);
        NSLog(@"Loaded SF Mono font from: %@", fontPath);
    } else {
        NSLog(@"Warning: Could not find SFMonoRegular.ttf, using default font");
    }

    // Setup Platform/Renderer backends
    ImGui_ImplMetal_Init(self.device);
    ImGui_ImplOSX_Init(self.metalView);

    // Initialize Application
    _application = new Application();
    if (!_application->Initialize(self.device)) {
        NSLog(@"Failed to initialize Application");
        return;
    }

    // Send initial resize event
    CGSize size = self.metalView.drawableSize;
    _application->OnResize((uint32_t)size.width, (uint32_t)size.height);

    NSLog(@"Application initialized and window displayed");

    // Observe system appearance changes
    [NSDistributedNotificationCenter.defaultCenter addObserver:self
                                                      selector:@selector(updateImGuiTheme)
                                                          name:@"AppleInterfaceThemeChangedNotification"
                                                        object:nil];
}

- (void)updateImGuiTheme {
    NSString* osxMode = [[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"];
    if ([osxMode isEqualToString:@"Dark"]) {
        ImGui::StyleColorsDark();
    } else {
        ImGui::StyleColorsLight();
    }
}

- (void)setupApplicationMenu {
    // Create main menu bar
    NSMenu *mainMenu = [[NSMenu alloc] init];

    // Create app menu item (container)
    NSMenuItem *appMenuItem = [[NSMenuItem alloc] init];
    [mainMenu addItem:appMenuItem];

    // Create app menu
    NSMenu *appMenu = [[NSMenu alloc] init];
    [appMenuItem setSubmenu:appMenu];

    // Add Quit menu item with Cmd+Q shortcut
    NSString *appName = [[NSProcessInfo processInfo] processName];
    NSString *quitTitle = [NSString stringWithFormat:@"Quit %@", appName];
    NSMenuItem *quitMenuItem = [[NSMenuItem alloc] initWithTitle:quitTitle
                                                         action:@selector(terminate:)
                                                  keyEquivalent:@"q"];
    [appMenu addItem:quitMenuItem];

    // Set the menu bar
    [NSApp setMainMenu:mainMenu];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    // Application will terminate
    [NSDistributedNotificationCenter.defaultCenter removeObserver:self
                                                             name:@"AppleInterfaceThemeChangedNotification"
                                                           object:nil];

    ImGui_ImplMetal_Shutdown();
    ImGui_ImplOSX_Shutdown();
    ImGui::DestroyContext();

    if (_application) {
        delete _application;
        _application = nullptr;
    }
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}

// MTKViewDelegate methods
- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    if (_application) {
        _application->OnResize((uint32_t)size.width, (uint32_t)size.height);
    }
}

- (void)drawInMTKView:(MTKView *)view {
    if (!_application) {
        return;
    }

    CFTimeInterval currentTime = CACurrentMediaTime();
    float deltaTime = _lastFrameTime > 0.0 ? (float)(currentTime - _lastFrameTime) : 0.016f;
    _lastFrameTime = currentTime;

    _application->OnUpdate(deltaTime);

    ImGuiIO& io = ImGui::GetIO();
    io.DisplaySize.x = view.bounds.size.width;
    io.DisplaySize.y = view.bounds.size.height;

    CGFloat framebufferScale = view.window.screen.backingScaleFactor ?: NSScreen.mainScreen.backingScaleFactor;
    io.DisplayFramebufferScale = ImVec2(framebufferScale, framebufferScale);

    MTLRenderPassDescriptor* renderPassDescriptor = view.currentRenderPassDescriptor;
    renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionLoad;
    renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;

    if (renderPassDescriptor == nil) {
        return;
    }

    // Start the Dear ImGui frame
    ImGui_ImplMetal_NewFrame(renderPassDescriptor);
    ImGui_ImplOSX_NewFrame(view);
    ImGui::NewFrame();

    // Call application UI callback
    _application->OnUI();

    // Rendering
    ImGui::Render();

    // Application rendering (separate command buffer for compute, blit, AS, etc.)
    id<MTLCommandBuffer> renderCommandBuffer = [self.commandQueue commandBuffer];
    _application->OnRender(renderCommandBuffer, view.currentDrawable);
    [renderCommandBuffer commit];

    // Presentation command buffer (for final UI and presentation)
    id<MTLCommandBuffer> presentationCommandBuffer = [self.commandQueue commandBuffer];
    [presentationCommandBuffer setLabel:@"Presentation"];

    // Simple clear color
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.1, 0.1, 0.1, 1.0);

    id<MTLRenderCommandEncoder> renderEncoder = [presentationCommandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];

    // Render ImGui
    [renderEncoder pushDebugGroup:@"ImGui"];
    ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(), presentationCommandBuffer, renderEncoder);
    [renderEncoder popDebugGroup];

    [renderEncoder endEncoding];

    // Present
    [presentationCommandBuffer presentDrawable:view.currentDrawable];
    [presentationCommandBuffer commit];

    // Update and Render additional Platform Windows
    if (io.ConfigFlags & ImGuiConfigFlags_ViewportsEnable) {
        ImGui::UpdatePlatformWindows();
        ImGui::RenderPlatformWindowsDefault();
    }
}

@end

#endif
