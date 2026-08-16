//
//  Live2DBridge.h
//  Aria
//
//  Objective-C bridge for Live2D Cubism Framework
//  Hides C++ implementation from Swift
//

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

NS_ASSUME_NONNULL_BEGIN

@interface Live2DBridge : NSObject

/// Initialize Live2D Framework with model path
/// @param modelPath Path to directory containing model3.json
/// @param modelName Name of the model (e.g., "sumire_free_001", "Poblanc")
/// @param error Error pointer for initialization failures
/// @return YES if initialization succeeded, NO otherwise
- (BOOL)initializeWithModelPath:(NSString *)modelPath modelName:(NSString *)modelName error:(NSError **)error;

/// Resize the rendering surface
/// @param size New size for the rendering surface
- (void)resize:(CGSize)size;

/// Update Live2D model state
/// @param deltaTime Time elapsed since last update in seconds
- (void)update:(NSTimeInterval)deltaTime;

/// Draw the Live2D model to the Metal command buffer
/// @param commandBuffer Metal command buffer for rendering
/// @param renderPassDescriptor Render pass descriptor
- (void)drawWithCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
         renderPassDescriptor:(MTLRenderPassDescriptor *)renderPassDescriptor;

/// Convenience method for rendering (alias for drawWithCommandBuffer)
/// @param commandBuffer Metal command buffer for rendering
/// @param renderPassDescriptor Render pass descriptor
- (void)render:(id<MTLCommandBuffer>)commandBuffer
renderPassDescriptor:(MTLRenderPassDescriptor *)renderPassDescriptor;

/// Set avatar talking state
/// @param talking YES if avatar should be in talking state
- (void)setTalking:(BOOL)talking;

/// Set mouth open value for lip sync
/// @param value Mouth open value (0.0 to 2.1 for PB model)
- (void)setMouthOpen:(float)value;

/// Dispose Live2D resources
- (void)dispose;

/// Check if Live2D is initialized
@property (nonatomic, readonly) BOOL isInitialized;

/// Check if model is loaded
@property (nonatomic, readonly) BOOL isModelLoaded;

@end

NS_ASSUME_NONNULL_END