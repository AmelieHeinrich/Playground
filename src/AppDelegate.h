#pragma once

#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

#include "MetalView.h"
#include "Application.h"

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate, MTKViewDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) MetalView *metalView;
@property (strong, nonatomic) id<MTLDevice> device;
@property (strong, nonatomic) id<MTLCommandQueue> commandQueue;

- (void)updateImGuiTheme;

@end

#else
#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate, MTKViewDelegate>

@property (strong, nonatomic) NSWindow *window;
@property (strong, nonatomic) MetalView *metalView;
@property (strong, nonatomic) id<MTLDevice> device;
@property (strong, nonatomic) id<MTLCommandQueue> commandQueue;

- (void)updateImGuiTheme;

@end

#endif
