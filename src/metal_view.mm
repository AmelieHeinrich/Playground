#import "metal_view.h"

@implementation MetalView

#if !TARGET_OS_IPHONE

- (BOOL)acceptsFirstResponder
{
    return YES;
}

- (void)keyDown:(NSEvent *)event
{
    if (![self.delegate respondsToSelector:@selector(keyDown:)]) {
        [super keyDown:event];
    }
}

- (void)keyUp:(NSEvent *)event
{
    if (![self.delegate respondsToSelector:@selector(keyUp:)]) {
        [super keyUp:event];
    }
}

#endif

@end
