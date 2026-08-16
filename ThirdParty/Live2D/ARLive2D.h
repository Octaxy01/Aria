//
//  ARLive2D.h
//  Aria
//
//  Objective-C-compatible C API wrapper for Live2D Cubism Framework
//  Swift-compatible interface hiding all C++ implementation
//

#ifndef ARLIVE2D_H
#define ARLIVE2D_H

#include <stdint.h>
#include <stdbool.h>

// Opaque handle type for Live2D instance
typedef void* ARLive2DHandle;

// Metal device opaque handle (avoid Metal types in C API)
typedef void* ARLive2DMetalDevice;

// Render pass descriptor opaque handle
typedef void* ARLive2DRenderPassDescriptor;

// Command buffer opaque handle
typedef void* ARLive2DCommandBuffer;

// Size structure
typedef struct {
    float width;
    float height;
} ARLive2DSize;

/**
 * Create a new Live2D instance
 * @return Opaque handle to Live2D instance, or NULL on failure
 */
ARLive2DHandle ARLive2DCreate(void);

/**
 * Initialize Live2D with Metal device
 * @param handle Live2D instance handle
 * @param metalDevice Metal device (as opaque pointer)
 * @param modelPath Path to directory containing model3.json
 * @return true if initialization succeeded, false otherwise
 */
bool ARLive2DInitialize(
    ARLive2DHandle handle,
    ARLive2DMetalDevice metalDevice,
    const char* modelPath
);

/**
 * Resize the rendering surface
 * @param handle Live2D instance handle
 * @param size New dimensions
 */
void ARLive2DResize(
    ARLive2DHandle handle,
    ARLive2DSize size
);

/**
 * Update Live2D model state
 * @param handle Live2D instance handle
 * @param deltaTime Time elapsed since last update in seconds
 */
void ARLive2DUpdate(
    ARLive2DHandle handle,
    double deltaTime
);

/**
 * Render the Live2D model
 * @param handle Live2D instance handle
 * @param commandBuffer Metal command buffer (as opaque pointer)
 * @param renderPassDescriptor Render pass descriptor (as opaque pointer)
 */
void ARLive2DRender(
    ARLive2DHandle handle,
    ARLive2DCommandBuffer commandBuffer,
    ARLive2DRenderPassDescriptor renderPassDescriptor
);

/**
 * Set talking state for lip sync
 * @param handle Live2D instance handle
 * @param talking true if avatar should be in talking state
 */
void ARLive2DSetTalking(
    ARLive2DHandle handle,
    bool talking
);

/**
 * Check if Live2D is initialized
 * @param handle Live2D instance handle
 * @return true if initialized, false otherwise
 */
bool ARLive2DIsInitialized(ARLive2DHandle handle);

/**
 * Check if model is loaded
 * @param handle Live2D instance handle
 * @return true if model loaded, false otherwise
 */
bool ARLive2DIsModelLoaded(ARLive2DHandle handle);

/**
 * Destroy Live2D instance and release resources
 * @param handle Live2D instance handle
 */
void ARLive2DDestroy(ARLive2DHandle handle);

#endif // ARLIVE2D_H