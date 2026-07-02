#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>

extern "C" {
    // Expose the function to Dart FFI
    __attribute__((visibility("default"))) __attribute__((used))
    void render_to_window_ios(const uint16_t* pixels, int width, int height);
}

// Forward declaration of the swift class property or method we'll call
// In Objective-C++, we can post a notification or call a block if we want.
// But the fastest way is to have the Swift code register a callback or provide the CVPixelBuffer.
// Since we want zero-copy (or close to it) RGB565 to CGImage, we will broadcast a notification with the CGImage.
// Wait, a notification is slow. Let's just create a shared pointer to the UIImageView layer.
// Actually, CoreGraphics is thread-safe. We can create a CGImage from the raw RGB565 pointer,
// and update a global CALayer's contents.

static CALayer* global_tv_layer = nil;

extern "C" {
    __attribute__((visibility("default"))) __attribute__((used))
    void set_global_tv_layer(void* layer) {
        global_tv_layer = (__bridge CALayer*)layer;
    }
}

void render_to_window_ios(const uint16_t* pixels, int width, int height) {
    if (global_tv_layer == nil) {
        return;
    }

    // Convert RGB565 to RGBA8888 for accurate CoreGraphics rendering
    size_t numPixels = width * height;
    uint32_t* rgba = (uint32_t*)malloc(numPixels * 4);
    
    for (size_t i = 0; i < numPixels; i++) {
        uint16_t p = pixels[i];
        uint8_t r = (p >> 11) & 0x1F;
        uint8_t g = (p >> 5) & 0x3F;
        uint8_t b = p & 0x1F;
        
        // Scale to 8-bit
        r = (r << 3) | (r >> 2);
        g = (g << 2) | (g >> 4);
        b = (b << 3) | (b >> 2);
        
        // ABGR format for CoreGraphics with kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big (which is RGBA in memory)
        rgba[i] = (0xFF << 24) | (b << 16) | (g << 8) | r;
    }

    NSData *data = [NSData dataWithBytesNoCopy:rgba length:numPixels * 4 freeWhenDone:YES];
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big;
    
    CGImageRef cgImage = CGImageCreate(
        width,
        height,
        8,
        32,
        width * 4,
        colorSpace,
        bitmapInfo,
        provider,
        NULL,
        false,
        kCGRenderingIntentDefault
    );

    if (cgImage) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            global_tv_layer.contents = (__bridge id)cgImage;
            global_tv_layer.magnificationFilter = kCAFilterLinear; // Use linear scaling to gracefully handle non-integer dynamic resolutions
            [CATransaction commit];
            CGImageRelease(cgImage);
        });
    }

    CGColorSpaceRelease(colorSpace);
    CGDataProviderRelease(provider);
}

#include "native-audio.mm"
