#import "MetalView.h"

@implementation MetalView

#if !TARGET_OS_IPHONE

- (BOOL)acceptsFirstResponder
{
    return YES;
}

- (void)keyDown:(NSEvent *)event
{

}

- (void)keyUp:(NSEvent *)event
{

}

#endif

@end
