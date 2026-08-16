//
//  Live2DBridge.mm
//  Aria
//
//  Objective-C++ implementation for Live2D Cubism Framework
//

#import "Live2DBridge.h"
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <AppKit/AppKit.h>

// MARK: - Cubism Framework includes
#include "CubismFramework.hpp"
#include "CubismModelSettingJson.hpp"
#include "Rendering/Metal/CubismRenderer_Metal.hpp"
#include "Model/CubismUserModel.hpp"
#include "Id/CubismIdManager.hpp"
#include "ICubismAllocator.hpp"
#include "Math/CubismViewMatrix.hpp"

using namespace Live2D::Cubism::Framework;
using namespace Live2D::Cubism::Framework::Rendering;

// MARK: - Allocator Implementation
class Live2DAllocator : public ICubismAllocator {
public:
    void* Allocate(const csmSizeType size) override {
        return malloc(size);
    }
    
    void Deallocate(void* memory) override {
        free(memory);
    }
    
    void* AllocateAligned(const csmSizeType size, const csmUint32 alignment) override {
        size_t offset, shift, alignedAddress;
        void* allocation;
        void** preamble;
        
        offset = alignment - 1 + sizeof(void*);
        
        allocation = Allocate(size + static_cast<csmUint32>(offset));
        
        alignedAddress = reinterpret_cast<size_t>(allocation) + sizeof(void*);
        
        shift = alignedAddress % alignment;
        
        if (shift) {
            alignedAddress += (alignment - shift);
        }
        
        preamble = reinterpret_cast<void**>(alignedAddress);
        preamble[-1] = allocation;
        
        return reinterpret_cast<void*>(alignedAddress);
    }
    
    void DeallocateAligned(void* alignedMemory) override {
        void** preamble;
        
        preamble = static_cast<void**>(alignedMemory);
        
        Deallocate(preamble[-1]);
    }
};

// Static allocator instance with lifetime exceeding framework usage
static Live2DAllocator g_cubismAllocator;

// MARK: - Log Function for Cubism Framework
static void CubismLogFunction(const csmChar* message) {
    NSLog(@"[Live2D Cubism] %s", message);
}

// MARK: - File Loading Functions for Cubism Framework (wrapper)
static csmByte* CubismLoadFileAsBytes(const std::string path, csmSizeInt* outSize) {
    NSString* nsPath = [NSString stringWithUTF8String:path.c_str()];
    NSData* data = [NSData dataWithContentsOfFile:nsPath];
    if (!data) {
        return nullptr;
    }
    
    csmSizeInt size = static_cast<csmSizeInt>(data.length);
    csmByte* buffer = static_cast<csmByte*>(malloc(size));
    if (buffer) {
        memcpy(buffer, data.bytes, size);
        *outSize = size;
    }
    
    return buffer;
}

static void CubismReleaseBytes(csmByte* buffer) {
    if (buffer) {
        free(buffer);
    }
}

// MARK: - Bridge File Loading (used by bridge directly)
static csmByte* LoadFileAsBytes(const csmChar* path, csmSizeInt* outSize) {
    return CubismLoadFileAsBytes(std::string(path), outSize);
}

static void ReleaseBytesBridge(csmByte* buffer) {
    CubismReleaseBytes(buffer);
}

// MARK: - Bridge Implementation
@interface Live2DBridgeImpl : NSObject
@property (nonatomic, strong) NSString *modelPath;
@property (nonatomic, strong) NSString *modelName;
@property (nonatomic, assign) CubismUserModel *model;
@property (nonatomic, assign) CubismRenderer_Metal *renderer;
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, assign) BOOL initialized;
@property (nonatomic, assign) BOOL modelLoaded;
@property (nonatomic, assign) csmFloat32 lastUpdateTime;
@property (nonatomic, assign) csmUint32 width;
@property (nonatomic, assign) csmUint32 height;
@property (nonatomic, assign) CubismViewMatrix* viewMatrix;
@property (nonatomic, assign) CubismPhysics* physics;
@property (nonatomic, assign) csmFloat32 breathTime;
@property (nonatomic, assign) csmFloat32 blinkTime;
@property (nonatomic, assign) csmFloat32 nextBlinkTime;
@property (nonatomic, assign) BOOL isBlinking;
@property (nonatomic, assign) csmFloat32 mouthOpenValue;
@end

@implementation Live2DBridgeImpl

- (instancetype)init {
    self = [super init];
    if (self) {
        _initialized = NO;
        _modelLoaded = NO;
        _model = nullptr;
        _renderer = nullptr;
        _physics = nullptr;
        _lastUpdateTime = 0.0f;
        _breathTime = 0.0f;
        _blinkTime = 0.0f;
        _nextBlinkTime = 2.0f + (static_cast<csmFloat32>(rand()) / RAND_MAX) * 4.0f; // Random 2-6 seconds
        _isBlinking = NO;
        _mouthOpenValue = 0.0f;
        _width = 600;
        _height = 800;
        _viewMatrix = nullptr;
        NSLog(@"[Live2D NATIVE] Bridge implementation initialized");
        NSLog(@"[Live2D NATIVE] mainBundle path: %@", [[NSBundle mainBundle] bundlePath]);
        NSLog(@"[Live2D NATIVE] mainBundle resourcePath: %@", [[NSBundle mainBundle] resourcePath]);
        NSLog(@"[Live2D NATIVE] mainBundle executablePath: %@", [[NSBundle mainBundle] executablePath]);
    }
    return self;
}

- (BOOL)initializeWithModelPath:(NSString *)modelPath modelName:(NSString *)modelName error:(NSError **)error {
    NSLog(@"[Live2D] Initialize with model path: %@", modelPath);
    NSLog(@"[Live2D] Model name: %@", modelName);
    NSLog(@"[Live2D] mainBundle path: %@", [[NSBundle mainBundle] bundlePath]);
    NSLog(@"[Live2D] mainBundle resourcePath: %@", [[NSBundle mainBundle] resourcePath]);
    
    self.modelPath = modelPath;
    self.modelName = modelName;
    
    // Initialize Metal
    self.device = MTLCreateSystemDefaultDevice();
    if (!self.device) {
        NSLog(@"[Live2D] ERROR: Failed to create Metal device");
        if (error) {
            *error = [NSError errorWithDomain:@"Live2DBridge"
                                         code:2
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to create Metal device"}];
        }
        return NO;
    }
    
    NSLog(@"[Live2D] Metal device created: %@", self.device);
    
    self.commandQueue = [self.device newCommandQueue];
    NSLog(@"[Live2D] Command queue created");
    
    // Initialize Cubism Framework
    NSLog(@"[Live2D] Allocator instance ready");
    
    // Setup Cubism Framework options
    CubismFramework::Option cubismOption;
    cubismOption.LogFunction = CubismLogFunction;
    cubismOption.LoggingLevel = Csm::CubismFramework::Option::LogLevel_Verbose;
    cubismOption.LoadFileFunction = CubismLoadFileAsBytes;
    cubismOption.ReleaseBytesFunction = CubismReleaseBytes;
    
    NSLog(@"[Live2D] Calling CubismFramework::StartUp");
    Csm::CubismFramework::StartUp(&g_cubismAllocator, &cubismOption);
    NSLog(@"[Live2D] CubismFramework::StartUp completed");
    
    NSLog(@"[Live2D] Calling CubismFramework::Initialize");
    CubismFramework::Initialize();
    NSLog(@"[Live2D] CubismFramework::Initialize completed");
    
    // Set Metal device info
    CubismRenderer_Metal::SetConstantSettings(self.device);
    NSLog(@"[Live2D] Metal constant settings configured");
    
    self.initialized = YES;
    
    // Load model
    return [self loadModel];
}

- (BOOL)loadModel {
    if (!self.initialized) {
        NSLog(@"[Live2D] ERROR: Framework not initialized");
        return NO;
    }
    
    NSLog(@"[Live2D] Loading model from: %@", self.modelPath);
    
    @try {
        // Simplified approach: load moc3 directly without CubismModelSettingJson
        NSString* moc3Path = [self.modelPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.moc3", self.modelName]];
        NSLog(@"[Live2D] Loading moc3 directly: %@", moc3Path);
        
        // Check if moc3 exists
        if (![[NSFileManager defaultManager] fileExistsAtPath:moc3Path]) {
            NSLog(@"[Live2D] ERROR: Moc3 file does not exist at %@", moc3Path);
            return NO;
        }
        
        NSLog(@"[Live2D] Moc3 file exists, proceeding to load...");
        
        // Load moc3
        NSLog(@"[Live2D] Reading moc3 file bytes...");
        csmSizeInt size;
        csmByte* buffer = LoadFileAsBytes([moc3Path UTF8String], &size);
        if (!buffer) {
            NSLog(@"[Live2D] ERROR: Failed to load moc3 file");
            return NO;
        }
        
        NSLog(@"[Live2D] Moc3 loaded, size: %d bytes", size);
        
        // Create user model
        NSLog(@"[Live2D] Creating CubismUserModel...");
        @try {
            self.model = new CubismUserModel();
            NSLog(@"[Live2D] CubismUserModel object created");
            NSLog(@"[Live2D] CubismUserModel created, loading moc data...");
            self.model->LoadModel(buffer, size, true);
            NSLog(@"[Live2D] LoadModel completed");
        } @catch (NSException* e) {
            NSLog(@"[Live2D] EXCEPTION during CubismUserModel creation/loading: %@", e);
            NSLog(@"[Live2D] Reason: %@", e.reason);
            ReleaseBytesBridge(buffer);
            return NO;
        }
        ReleaseBytesBridge(buffer);
        
        NSLog(@"[Live2D] MOC3 loaded successfully");
        
        // Create renderer
        CubismRenderer* baseRenderer = CubismRenderer_Metal::Create(self.width, self.height);
        self.renderer = static_cast<CubismRenderer_Metal*>(baseRenderer);
        
        if (!self.renderer) {
            NSLog(@"[Live2D] ERROR: Failed to create renderer");
            return NO;
        }
        
        NSLog(@"[Live2D] Renderer created");
        
        // Set model to renderer - use the base CubismModel
        CubismModel* cubismModel = self.model->GetModel();
        NSLog(@"[Live2D] About to call renderer->Initialize");
        self.renderer->Initialize(cubismModel, 0);
        NSLog(@"[Live2D] Renderer initialized with model");
        
        // Setup view matrix for proper viewport - simple framing
        self.viewMatrix = new CubismViewMatrix();
        if (self.viewMatrix) {
            // Calculate aspect ratio based on ACTUAL window dimensions
            float ratio = static_cast<float>(self.width) / static_cast<float>(self.height);
            
            // Normal viewport based on actual window aspect ratio
            float left = -ratio;
            float right = ratio;
            float bottom = -1.0f;
            float top = 1.0f;
            
            // Set screen rect
            self.viewMatrix->SetScreenRect(left, right, bottom, top);
            
            // Bust-up framing constants - tweak these for optimal crop
            const float kBustCropScale = 3.5f;  // Zoom level: higher = more zoom
            const float kBustCropOffsetY = -0.5f;  // Vertical position: negative = move down
            
            // Apply bust-up framing (zoom to head + shoulders + chest area)
            self.viewMatrix->Translate(0.0f, kBustCropOffsetY);
            self.viewMatrix->Scale(kBustCropScale, kBustCropScale);
            
            // Set max/min scale
            self.viewMatrix->SetMaxScale(3.0f);
            self.viewMatrix->SetMinScale(2.0f);
            
            NSLog(@"[Live2D] View matrix configured for bust-up framing: %ux%u", self.width, self.height);
        }
        
        // Load texture directly without using CubismModelSettingJson
        NSString* texturePath = [self.modelPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.8192/texture_00.png", self.modelName]];
        NSLog(@"[Live2D] Loading texture: %@", texturePath);
        
        // Check if texture exists
        NSData* textureData = [NSData dataWithContentsOfFile:texturePath];
        if (!textureData) {
            NSLog(@"[Live2D] WARNING: Failed to load texture");
        } else {
            NSLog(@"[Live2D] Texture data loaded: %lu bytes", (unsigned long)textureData.length);
            
            // Create Metal texture from image data
            id<MTLTexture> metalTexture = [self createMetalTextureFromData:textureData];
            if (metalTexture) {
                // Set texture to renderer
                self.renderer->BindTexture(0, metalTexture);
                NSLog(@"[Live2D] Texture bound to renderer");
            } else {
                NSLog(@"[Live2D] WARNING: Failed to create Metal texture");
            }
        }
        
        // Load physics
        NSString* physicsPath = [self.modelPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.physics3.json", self.modelName]];
        NSLog(@"[Live2D] Loading physics: %@", physicsPath);
        
        NSData* physicsData = [NSData dataWithContentsOfFile:physicsPath];
        if (physicsData) {
            NSLog(@"[Live2D] Physics data loaded: %lu bytes", (unsigned long)physicsData.length);
            
            const csmByte* physicsBytes = static_cast<const csmByte*>([physicsData bytes]);
            csmSizeType physicsSize = static_cast<csmSizeType>([physicsData length]);
            
            self.physics = CubismPhysics::Create(physicsBytes, physicsSize);
            if (self.physics) {
                NSLog(@"[Live2D] Physics created successfully");
            } else {
                NSLog(@"[Live2D] WARNING: Failed to create physics");
            }
        } else {
            NSLog(@"[Live2D] WARNING: Physics file not found, physics will be disabled");
            self.physics = nullptr;
        }
        
        self.modelLoaded = YES;
        NSLog(@"[Live2D] Model loaded successfully");
        
        return YES;
    } @catch (NSException* exception) {
        NSLog(@"[Live2D] EXCEPTION during model loading: %@", exception);
        NSLog(@"[Live2D] Reason: %@", exception.reason);
        return NO;
    }
}

- (id<MTLTexture>)createMetalTextureFromData:(NSData*)textureData {
    NSLog(@"[Live2D] Decoding PNG texture");
    
    // Create CGImageSource from PNG data
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((__bridge CFDataRef)textureData, NULL);
    if (!imageSource) {
        NSLog(@"[Live2D] ERROR: Failed to create CGImageSource");
        return nil;
    }
    
    // Create CGImage from source
    CGImageRef cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
    CFRelease(imageSource);
    if (!cgImage) {
        NSLog(@"[Live2D] ERROR: Failed to create CGImage");
        return nil;
    }
    
    // Get texture dimensions
    NSUInteger width = CGImageGetWidth(cgImage);
    NSUInteger height = CGImageGetHeight(cgImage);
    
    NSLog(@"[Live2D] Creating texture: %lux%lu", width, height);
    
    // Calculate expected raw buffer size
    NSUInteger expectedSize = width * height * 4;
    NSLog(@"[Live2D] Expected raw pixel buffer size: %lu bytes", (unsigned long)expectedSize);
    
    // Create Metal texture descriptor
    MTLTextureDescriptor* textureDescriptor = [[MTLTextureDescriptor alloc] init];
    textureDescriptor.pixelFormat = MTLPixelFormatRGBA8Unorm;
    textureDescriptor.width = width;
    textureDescriptor.height = height;
    textureDescriptor.textureType = MTLTextureType2D;
    textureDescriptor.usage = MTLTextureUsageShaderRead;
    
    // Create texture
    id<MTLTexture> texture = [self.device newTextureWithDescriptor:textureDescriptor];
    if (!texture) {
        NSLog(@"[Live2D] ERROR: Failed to create Metal texture");
        CGImageRelease(cgImage);
        return nil;
    }
    
    // Create bitmap context for RGBA8 conversion
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, width * 4, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    
    if (!context) {
        NSLog(@"[Live2D] ERROR: Failed to create bitmap context");
        CGImageRelease(cgImage);
        return nil;
    }
    
    // Draw image to context to decode to raw RGBA bytes
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), cgImage);
    CGImageRelease(cgImage);
    
    // Get raw pixel data from context
    void* pixelData = CGBitmapContextGetData(context);
    if (!pixelData) {
        NSLog(@"[Live2D] ERROR: Failed to get bitmap data");
        CGContextRelease(context);
        return nil;
    }
    
    NSLog(@"[Live2D] Decoded raw pixel buffer obtained");
    
    // Copy data to texture
    [texture replaceRegion:MTLRegionMake2D(0, 0, width, height)
               mipmapLevel:0
                 withBytes:pixelData
               bytesPerRow:width * 4];
    
    CGContextRelease(context);
    
    NSLog(@"[Live2D] Metal texture created successfully");
    return texture;
}

- (void)resize:(CGSize)size {
    NSLog(@"[Live2D] Resize to: %.0fx%.0f", size.width, size.height);
    
    self.width = static_cast<csmUint32>(size.width);
    self.height = static_cast<csmUint32>(size.height);
    
    // Recreate renderer with new dimensions
    if (self.renderer) {
        CubismRenderer::Delete(self.renderer);
        self.renderer = nullptr;
    }
    
    if (self.model && self.modelLoaded) {
        CubismModel* cubismModel = self.model->GetModel();
        CubismRenderer* baseRenderer = CubismRenderer_Metal::Create(self.width, self.height);
        self.renderer = static_cast<CubismRenderer_Metal*>(baseRenderer);
        
        if (self.renderer) {
            self.renderer->Initialize(cubismModel, 0);
            NSLog(@"[Live2D] Renderer recreated with new size");
        }
    }
}

- (void)update:(NSTimeInterval)deltaTime {
    if (!self.model || !self.modelLoaded) {
        return;
    }
    
    csmFloat32 dt = static_cast<csmFloat32>(deltaTime);
    self.lastUpdateTime += dt;
    
    CubismModel* cubismModel = self.model->GetModel();
    
    // Update breathing animation
    self.breathTime += dt;
    csmFloat32 breathValue = (sin(self.breathTime * 2.0f) + 1.0f) * 0.5f; // 0 to 1 sine wave
    breathValue = breathValue * 0.5f; // Scale to 0 to 0.5 for subtle breathing
    
    // Get parameter index for ParamBreath using CubismIdManager
    const CubismId* breathId = CubismFramework::GetIdManager()->GetId("ParamBreath");
    csmInt32 breathIndex = cubismModel->GetParameterIndex(breathId);
    if (breathIndex >= 0) {
        cubismModel->SetParameterValue(breathIndex, breathValue);
    }
    
    // Update eye blink
    self.blinkTime += dt;
    
    // Check if it's time to blink
    if (!self.isBlinking && self.blinkTime >= self.nextBlinkTime) {
        // Start blink
        self.isBlinking = YES;
        self.blinkTime = 0.0f;
    }
    
    // Handle blink animation
    if (self.isBlinking) {
        csmFloat32 eyeOpenValue = 1.0f;
        
        if (self.blinkTime < 0.05f) {
            // Closing phase (50ms)
            eyeOpenValue = 1.0f - (self.blinkTime / 0.05f);
        } else if (self.blinkTime < 0.15f) {
            // Closed phase (100ms)
            eyeOpenValue = 0.0f;
        } else if (self.blinkTime < 0.25f) {
            // Opening phase (100ms)
            eyeOpenValue = (self.blinkTime - 0.15f) / 0.1f;
        } else {
            // Blink complete
            self.isBlinking = NO;
            self.blinkTime = 0.0f;
            self.nextBlinkTime = 2.0f + (static_cast<csmFloat32>(rand()) / RAND_MAX) * 4.0f; // Random 2-6 seconds
            eyeOpenValue = 1.0f;
        }
        
        // Set eye open parameters
        const CubismId* eyeLOpenId = CubismFramework::GetIdManager()->GetId("ParamEyeLOpen");
        const CubismId* eyeROpenId = CubismFramework::GetIdManager()->GetId("ParamEyeROpen");
        
        csmInt32 eyeLOpenIndex = cubismModel->GetParameterIndex(eyeLOpenId);
        csmInt32 eyeROpenIndex = cubismModel->GetParameterIndex(eyeROpenId);
        
        if (eyeLOpenIndex >= 0) {
            cubismModel->SetParameterValue(eyeLOpenIndex, eyeOpenValue);
        }
        if (eyeROpenIndex >= 0) {
            cubismModel->SetParameterValue(eyeROpenIndex, eyeOpenValue);
        }
    }
    
    // Update physics if enabled
    if (self.physics) {
        self.physics->Evaluate(cubismModel, dt);
    }
    
    // Update model parameters through the CubismUpdateScheduler
    // The CubismUserModel uses an internal update scheduler
    // For now, we'll let the renderer handle the updates during draw
    
    // Apply mouth open value for lip sync
    const CubismId* mouthOpenId = CubismFramework::GetIdManager()->GetId("ParamMouthOpenY");
    csmInt32 mouthOpenIndex = cubismModel->GetParameterIndex(mouthOpenId);
    if (mouthOpenIndex >= 0) {
        cubismModel->SetParameterValue(mouthOpenIndex, self.mouthOpenValue);
    }
}

- (void)drawWithCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
         renderPassDescriptor:(MTLRenderPassDescriptor *)renderPassDescriptor {
    if (!self.renderer || !self.modelLoaded) {
        return;
    }
    
    // Set the viewport for proper rendering
    MTLViewport viewport;
    viewport.originX = 0;
    viewport.originY = 0;
    viewport.width = self.width;
    viewport.height = self.height;
    viewport.znear = 0.0;
    viewport.zfar = 1.0;
    
    self.renderer->SetRenderViewport(viewport);
    
    // Start frame with Metal command buffer and render pass descriptor
    self.renderer->StartFrame(commandBuffer, renderPassDescriptor);
    
    // Draw the model using public API
    self.renderer->DrawModel();
    
    NSLog(@"[Live2D] Model drawn");
}

- (void)setTalking:(BOOL)talking {
    NSLog(@"[Live2D] Set talking: %@", talking ? @"YES" : @"NO");
    // TODO: Implement lip sync parameter setting
}

- (void)setMouthOpen:(float)value {
    self.mouthOpenValue = value;
    NSLog(@"[Live2D] Set mouth open: %.2f", value);
}

- (void)dispose {
    NSLog(@"[Live2D] Dispose");
    
    if (self.viewMatrix) {
        delete self.viewMatrix;
        self.viewMatrix = nullptr;
    }
    
    if (self.renderer) {
        CubismRenderer::Delete(self.renderer);
        self.renderer = nullptr;
    }
    
    if (self.model) {
        delete self.model;
        self.model = nullptr;
    }
    
    CubismFramework::Dispose();
    
    self.initialized = NO;
    self.modelLoaded = NO;
}

- (void)dealloc {
    [self dispose];
    [super dealloc];
}

@end

// MARK: - Public Interface
@implementation Live2DBridge {
    Live2DBridgeImpl* _impl;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _impl = [[Live2DBridgeImpl alloc] init];
    }
    return self;
}

- (BOOL)initializeWithModelPath:(NSString *)modelPath modelName:(NSString *)modelName error:(NSError **)error {
    return [_impl initializeWithModelPath:modelPath modelName:modelName error:error];
}

- (void)resize:(CGSize)size {
    [_impl resize:size];
}

- (void)update:(NSTimeInterval)deltaTime {
    [_impl update:deltaTime];
}

- (void)drawWithCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
         renderPassDescriptor:(MTLRenderPassDescriptor *)renderPassDescriptor {
    [_impl drawWithCommandBuffer:commandBuffer renderPassDescriptor:renderPassDescriptor];
}

- (void)render:(id<MTLCommandBuffer>)commandBuffer
renderPassDescriptor:(MTLRenderPassDescriptor *)renderPassDescriptor {
    [_impl drawWithCommandBuffer:commandBuffer renderPassDescriptor:renderPassDescriptor];
}

- (void)setTalking:(BOOL)talking {
    [_impl setTalking:talking];
}

- (void)setMouthOpen:(float)value {
    [_impl setMouthOpen:value];
}

- (void)dispose {
    [_impl dispose];
}

- (BOOL)isInitialized {
    return _impl.initialized;
}

- (BOOL)isModelLoaded {
    return _impl.modelLoaded;
}

- (void)dealloc {
    [_impl dispose];
    [super dealloc];
}

@end