#include "app_delegate.h"

#if TARGET_OS_IPHONE
// iOS Implementation
@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Create the main window
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor systemBackgroundColor];
    
    // Create a simple view controller
    UIViewController *rootViewController = [[UIViewController alloc] init];
    rootViewController.view.backgroundColor = [UIColor systemBackgroundColor];
    
    // Add a label
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 300, 100)];
    label.text = @"Hello, iOS!";
    label.textAlignment = NSTextAlignmentCenter;
    label.center = rootViewController.view.center;
    [rootViewController.view addSubview:label];
    
    self.window.rootViewController = rootViewController;
    [self.window makeKeyAndVisible];
    
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
}

@end

#else
// macOS Implementation
@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    // Create the main window
    NSRect frame = NSMakeRect(0, 0, 800, 600);
    self.window = [[NSWindow alloc] initWithContentRect:frame
                                              styleMask:(NSWindowStyleMaskTitled |
                                                        NSWindowStyleMaskClosable |
                                                        NSWindowStyleMaskMiniaturizable |
                                                        NSWindowStyleMaskResizable)
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    
    [self.window setTitle:@"Playground"];
    [self.window center];
    
    // Create a simple view with a label
    NSView *contentView = [[NSView alloc] initWithFrame:frame];
    
    NSTextField *label = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 300, 100)];
    [label setStringValue:@"Hello, macOS!"];
    [label setBezeled:NO];
    [label setDrawsBackground:NO];
    [label setEditable:NO];
    [label setSelectable:NO];
    [label setAlignment:NSTextAlignmentCenter];
    [label setFont:[NSFont systemFontOfSize:24]];
    
    // Center the label in the window
    CGFloat labelX = (frame.size.width - 300) / 2;
    CGFloat labelY = (frame.size.height - 100) / 2;
    [label setFrame:NSMakeRect(labelX, labelY, 300, 100)];
    
    [contentView addSubview:label];
    [self.window setContentView:contentView];
    [self.window makeKeyAndOrderFront:nil];
    
    NSLog(@"Window created and displayed");
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    // Application will terminate
}

@end

#endif