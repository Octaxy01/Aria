//
//  ARLive2D.m
//  Aria
//
//  Objective-C wrapper implementation for Live2D Cubism Framework
//

#import "include/ARLive2D.h"
#import "Live2DBridge.h"

// Global bridge storage for manual memory management
static Live2DBridge* g_bridge = nil;

ARLive2DHandle ARLive2DCreate(void) {
    g_bridge = [[Live2DBridge alloc] init];
    return (__bridge_retained void*)g_bridge;
}

bool ARLive2DInitialize(
    ARLive2DHandle handle,
    ARLive2DMetalDevice metalDevice,
    const char* modelPath,
    const char* modelName
) {
    if (!handle) return false;
    
    Live2DBridge* bridge = (__bridge Live2DBridge*)handle;
    
    // Note: Metal device is passed as opaque pointer but we don't use it directly
    // The bridge creates its own Metal device for simplicity
    NSString* nsPath = [NSString stringWithUTF8String:modelPath];
    NSString* nsModelName = [NSString stringWithUTF8String:modelName];
    NSError* error = nil;
    BOOL success = [bridge initializeWithModelPath:nsPath modelName:nsModelName error:&error];
    
    if (!success && error) {
        NSLog(@"[Live2D C API] Initialization failed: %@", error.localizedDescription);
    }
    
    return success;
}

void ARLive2DResize(
    ARLive2DHandle handle,
    ARLive2DSize size
) {
    if (!handle) return;
    
    Live2DBridge* bridge = (__bridge Live2DBridge*)handle;
    CGSize cgSize = CGSizeMake(size.width, size.height);
    [bridge resize:cgSize];
}

void ARLive2DUpdate(
    ARLive2DHandle handle,
    double deltaTime
) {
    if (!handle) return;
    
    Live2DBridge* bridge = (__bridge Live2DBridge*)handle;
    [bridge update:deltaTime];
}

void ARLive2DRender(
    ARLive2DHandle handle,
    ARLive2DCommandBuffer commandBuffer,
    ARLive2DRenderPassDescriptor renderPassDescriptor
) {
    if (!handle) return;
    
    Live2DBridge* bridge = (__bridge Live2DBridge*)handle;
    id<MTLCommandBuffer> cmdBuffer = (__bridge id<MTLCommandBuffer>)commandBuffer;
    MTLRenderPassDescriptor* renderDesc = (__bridge MTLRenderPassDescriptor*)renderPassDescriptor;
    
    [bridge drawWithCommandBuffer:cmdBuffer renderPassDescriptor:renderDesc];
}

void ARLive2DSetTalking(
    ARLive2DHandle handle,
    bool talking
) {
    if (!handle) return;
    
    Live2DBridge* bridge = (__bridge Live2DBridge*)handle;
    [bridge setTalking:talking];
}

void ARLive2DSetMouthOpen(
    ARLive2DHandle handle,
    float value
) {
    if (!handle) return;
    
    Live2DBridge* bridge = (__bridge Live2DBridge*)handle;
    [bridge setMouthOpen:value];
}

bool ARLive2DIsInitialized(ARLive2DHandle handle) {
    if (!handle) return false;
    
    Live2DBridge* bridge = (__bridge Live2DBridge*)handle;
    return [bridge isInitialized];
}

bool ARLive2DIsModelLoaded(ARLive2DHandle handle) {
    if (!handle) return false;
    
    Live2DBridge* bridge = (__bridge Live2DBridge*)handle;
    return [bridge isModelLoaded];
}

void ARLive2DDestroy(ARLive2DHandle handle) {
    if (!handle) return;
    
    Live2DBridge* bridge = (__bridge_transfer Live2DBridge*)handle;
    [bridge dispose];
    
    if (bridge == g_bridge) {
        g_bridge = nil;
    }
}