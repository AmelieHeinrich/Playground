#include "app_delegate.h"

#import "metal_view.h"

#include <objc/objc.h>
#include <imgui.h>
#include <imgui_impl_metal.h>

#if !TARGET_OS_IPHONE
#include <imgui_impl_osx.h>
#else
#import <GameController/GameController.h>
#endif

#if TARGET_OS_IPHONE

API_AVAILABLE(ios(15.0))
@interface PlaygroundViewController : UIViewController
@property (assign, nonatomic) AppDelegate *appDelegate;
@end

@implementation PlaygroundViewController {
    GCVirtualController *_virtualController;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // Set up controller notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(controllerDidConnect:)
                                                 name:GCControllerDidConnectNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(controllerDidDisconnect:)
                                                 name:GCControllerDidDisconnectNotification
                                               object:nil];

    // Set up virtual controller (iOS 15.0+)
    if (@available(iOS 15.0, *)) {
        if (!_virtualController) {
            GCVirtualControllerConfiguration* config = [[GCVirtualControllerConfiguration alloc] init];
            config.elements = [NSSet setWithArray:@[
                GCInputLeftThumbstick,
            ]];
            _virtualController = [[GCVirtualController alloc] initWithConfiguration:config];
        }
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    // Connect virtual controller if no physical controllers are present (iOS 15.0+)
    if (@available(iOS 15.0, *)) {
        if (GCController.controllers.count == 0 && _virtualController != nil) {
            [_virtualController connectWithReplyHandler:^(NSError * _Nullable error) {
                if (error) {
                    NSLog(@"Failed to connect virtual controller: %@", error);
                } else {
                    NSLog(@"Virtual controller connected successfully");
                }
            }];
        }
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (@available(iOS 15.0, *)) {
        if (_virtualController) {
            [_virtualController disconnect];
        }
    }
}

- (void)controllerDidConnect:(NSNotification *)notification {
    if (@available(iOS 15.0, *)) {
        if (_virtualController != nil) {
            BOOL hasPhysicalController = NO;
            for (GCController *controller in GCController.controllers) {
                if (controller != _virtualController.controller) {
                    hasPhysicalController = YES;
                    break;
                }
            }
            if (hasPhysicalController) {
                NSLog(@"Physical controller connected. Disconnecting virtual controller");
                [_virtualController disconnect];
            }
        }
    }
}

- (void)controllerDidDisconnect:(NSNotification *)notification {
    if (@available(iOS 15.0, *)) {
        if (GCController.controllers.count == 0 && _virtualController != nil) {
            [_virtualController connectWithReplyHandler:^(NSError * _Nullable error) {
                if (error) {
                    NSLog(@"Failed to connect virtual controller: %@", error);
                }
            }];
        }
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];

    if (@available(iOS 13.0, *)) {
        if (self.traitCollection.userInterfaceStyle != previousTraitCollection.userInterfaceStyle) {
            [self.appDelegate updateImGuiTheme];
            NSLog(@"Theme changed to: %@",
                  self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? @"Dark" : @"Light");
        }
    }
}

@end

// iOS Implementation
@implementation AppDelegate {
    Application *_application;
    CFTimeInterval _lastFrameTime;
    PlaygroundViewController *_viewController;
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

    // Create a custom view controller
    _viewController = [[PlaygroundViewController alloc] init];
    _viewController.appDelegate = self;

    // Add MetalView as a subview so virtual controller can display on top
    self.metalView.frame = _viewController.view.bounds;
    self.metalView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [_viewController.view addSubview:self.metalView];

    self.window.rootViewController = _viewController;
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

    io.FontGlobalScale = 0.6f;

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
                                                    inDirectory:@"fonts"];
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
    _application->OnRender(view.currentDrawable);

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
    self.metalView.framebufferOnly = NO;

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
                                                    inDirectory:@"fonts"];
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
    _application->OnRender(view.currentDrawable);

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
