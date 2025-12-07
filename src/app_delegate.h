#pragma once

#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#include "application.h"

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate, MTKViewDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) MTKView *metalView;
@property (strong, nonatomic) id<MTLDevice> device;

@end

#else
#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate, MTKViewDelegate>

@property (strong, nonatomic) NSWindow *window;
@property (strong, nonatomic) MTKView *metalView;
@property (strong, nonatomic) id<MTLDevice> device;

@end

#endif