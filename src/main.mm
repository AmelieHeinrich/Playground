#include "AppDelegate.h"

#if TARGET_OS_IPHONE
// iOS Entry Point
#import <UIKit/UIKit.h>

int main(int argc, char *argv[])
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}

#else
// macOS Entry Point
#import <Cocoa/Cocoa.h>

int main(int argc, char *argv[])
{
    @autoreleasepool {
        [NSApplication sharedApplication];
        AppDelegate *appDelegate = [[AppDelegate alloc] init];
        [NSApp setDelegate:appDelegate];
        [NSApp run];
    }
    return 0;
}

#endif