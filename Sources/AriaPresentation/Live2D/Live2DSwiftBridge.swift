import Foundation
import Metal

// C function declarations for Live2D bridge
@_silgen_name("ARLive2DCreate")
fileprivate func ARLive2DCreate() -> UnsafeMutableRawPointer?

@_silgen_name("ARLive2DInitialize")
fileprivate func ARLive2DInitialize(_ handle: UnsafeMutableRawPointer?, _ metalDevice: UnsafeMutableRawPointer?, _ modelPath: UnsafePointer<Int8>) -> Bool

@_silgen_name("ARLive2DResize")
fileprivate func ARLive2DResize(_ handle: UnsafeMutableRawPointer?, _ size: ARLive2DSize)

@_silgen_name("ARLive2DUpdate")
fileprivate func ARLive2DUpdate(_ handle: UnsafeMutableRawPointer?, _ deltaTime: TimeInterval)

@_silgen_name("ARLive2DRender")
fileprivate func ARLive2DRender(_ handle: UnsafeMutableRawPointer?, _ commandBuffer: UnsafeMutableRawPointer?, _ renderPassDescriptor: UnsafeMutableRawPointer?)

@_silgen_name("ARLive2DSetTalking")
fileprivate func ARLive2DSetTalking(_ handle: UnsafeMutableRawPointer?, _ talking: Bool)

@_silgen_name("ARLive2DIsInitialized")
fileprivate func ARLive2DIsInitialized(_ handle: UnsafeMutableRawPointer?) -> Bool

@_silgen_name("ARLive2DIsModelLoaded")
fileprivate func ARLive2DIsModelLoaded(_ handle: UnsafeMutableRawPointer?) -> Bool

@_silgen_name("ARLive2DDestroy")
fileprivate func ARLive2DDestroy(_ handle: UnsafeMutableRawPointer?)

// C struct definitions
fileprivate struct ARLive2DSize {
    var width: Float
    var height: Float
}

/// Swift wrapper for the Live2D C API
/// Hides unsafe pointer operations and provides Swift-friendly interface
class Live2DSwiftBridge {
    private var handle: UnsafeMutableRawPointer?
    
    init() {
        self.handle = ARLive2DCreate()
        print("[Live2D Swift] Bridge created")
    }
    
    deinit {
        if let handle = self.handle {
            ARLive2DDestroy(handle)
            print("[Live2D Swift] Bridge destroyed")
        }
    }
    
    func initialize(modelPath: String) -> Bool {
        guard let handle = self.handle else {
            print("[Live2D Swift] ERROR: Invalid handle")
            return false
        }
        
        let success = modelPath.withCString { path in
            let metalDevice: UnsafeMutableRawPointer? = nil
            return ARLive2DInitialize(handle, metalDevice, path)
        }
        
        if success {
            print("[Live2D Swift] Initialization successful")
        } else {
            print("[Live2D Swift] ERROR: Initialization failed")
        }
        
        return success
    }
    
    func resize(width: CGFloat, height: CGFloat) {
        guard let handle = self.handle else { return }
        
        let size = ARLive2DSize(width: Float(width), height: Float(height))
        ARLive2DResize(handle, size)
    }
    
    func update(deltaTime: TimeInterval) {
        guard let handle = self.handle else { return }
        ARLive2DUpdate(handle, deltaTime)
    }
    
    func render(commandBuffer: MTLCommandBuffer, renderPassDescriptor: MTLRenderPassDescriptor) {
        guard let handle = self.handle else { return }
        
        let cmdBufferPtr = Unmanaged.passUnretained(commandBuffer).toOpaque()
        let renderDescPtr = Unmanaged.passUnretained(renderPassDescriptor).toOpaque()
        
        ARLive2DRender(handle, cmdBufferPtr, renderDescPtr)
    }
    
    func setTalking(_ talking: Bool) {
        guard let handle = self.handle else { return }
        ARLive2DSetTalking(handle, talking)
    }
    
    var isInitialized: Bool {
        guard let handle = self.handle else { return false }
        return ARLive2DIsInitialized(handle)
    }
    
    var isModelLoaded: Bool {
        guard let handle = self.handle else { return false }
        return ARLive2DIsModelLoaded(handle)
    }
}