#include "app_delegate.h"
#include <objc/objc.h>

#if TARGET_OS_IPHONE
// iOS Implementation
@implementation AppDelegate {
    Application *_application;
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
    self.metalView = [[MTKView alloc] initWithFrame:self.window.bounds device:self.device];
    self.metalView.delegate = self;
    self.metalView.enableSetNeedsDisplay = NO;
    self.metalView.preferredFramesPerSecond = 60;
    self.metalView.colorPixelFormat = MTLPixelFormatBGRA8Unorm;

    // Create a view controller for the Metal view
    UIViewController *rootViewController = [[UIViewController alloc] init];
    rootViewController.view = self.metalView;

    self.window.rootViewController = rootViewController;
    [self.window makeKeyAndVisible];

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
    if (_application) {
        id<CAMetalDrawable> drawable = view.currentDrawable;
        _application->OnRender(drawable);
    }
}

@end

#else
// macOS Implementation
@implementation AppDelegate {
    Application *_application;
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
    self.metalView = [[MTKView alloc] initWithFrame:frame device:self.device];
    self.metalView.delegate = self;
    self.metalView.enableSetNeedsDisplay = NO;
    self.metalView.preferredFramesPerSecond = 60;
    self.metalView.colorPixelFormat = MTLPixelFormatBGRA8Unorm;

    [self.window setContentView:self.metalView];
    [self.window makeKeyAndOrderFront:nil];

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
    if (_application) {
        id<CAMetalDrawable> drawable = view.currentDrawable;
        _application->OnRender(drawable);
    }
}

@end

#endif
