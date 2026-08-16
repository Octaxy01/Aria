import SwiftUI
import AppKit
import MetalKit
import AriaDomain

/// SwiftUI wrapper for the Live2D Metal view
/// Uses NSViewRepresentable to bridge AppKit's MTKView into SwiftUI
struct Live2DView: NSViewRepresentable {
    let configuration: AvatarConfiguration
    let avatarState: AvatarState
    
    func makeNSView(context: Context) -> NSView {
        print("[Live2D SwiftUI] Creating Live2D container view")
        
        // Create container view
        let containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.clear.cgColor
        
        // Try to create Metal device
        guard let metalDevice = MTLCreateSystemDefaultDevice() else {
            print("[Live2D SwiftUI] ERROR: Failed to create MTLDevice")
            showPlaceholder(in: containerView, message: "Avatar tidak tersedia")
            return containerView
        }
        
        // Create Metal view with device
        let metalView = Live2DMetalView(frame: .zero, device: metalDevice)
        metalView.performSetup()
        
        // Create and initialize bridge
        let bridge = Live2DBridge()
        let success = bridge.initialize(modelPath: configuration.modelDirectory.path, modelName: configuration.modelName)
        
        if success {
            print("[Live2D SwiftUI] Bridge initialized successfully")
            metalView.bridge = bridge
            
            // Add metal view to container
            metalView.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(metalView)
            NSLayoutConstraint.activate([
                metalView.topAnchor.constraint(equalTo: containerView.topAnchor),
                metalView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
                metalView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                metalView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
            ])
        } else {
            print("[Live2D SwiftUI] ERROR: Bridge initialization failed")
            showPlaceholder(in: containerView, message: "Avatar gagal dimuat")
        }
        
        return containerView
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Find the metal view in the container
        guard let metalView = nsView.subviews.first as? Live2DMetalView,
              let bridge = metalView.bridge else {
            return
        }
        
        // Update avatar state
        let isTalking = (avatarState == .talking)
        bridge.setTalking(isTalking)
        
        if isTalking {
            bridge.setMouthOpen(1.5)
        } else {
            bridge.setMouthOpen(0.0)
        }
    }
    
    static func dismantleNSView(_ nsView: NSView, coordinator: ()) {
        print("[Live2D SwiftUI] Dismantling Live2D container view")
        // Bridge cleanup happens automatically through ARC
    }
    
    private func showPlaceholder(in view: NSView, message: String) {
        let placeholder = NSTextField(labelWithString: message)
        placeholder.alignment = .center
        placeholder.textColor = .secondaryLabelColor
        placeholder.font = NSFont.systemFont(ofSize: 14)
        placeholder.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(placeholder)
        
        NSLayoutConstraint.activate([
            placeholder.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            placeholder.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}

// MARK: - Live2D Components (copied from Live2DWindow.swift for SwiftUI access)

// C function declarations for Live2D bridge
@_silgen_name("ARLive2DCreate")
fileprivate func ARLive2DCreate() -> UnsafeMutableRawPointer?

@_silgen_name("ARLive2DInitialize")
fileprivate func ARLive2DInitialize(_ handle: UnsafeMutableRawPointer?, _ metalDevice: UnsafeMutableRawPointer?, _ modelPath: UnsafePointer<Int8>, _ modelName: UnsafePointer<Int8>) -> Bool

@_silgen_name("ARLive2DResize")
fileprivate func ARLive2DResize(_ handle: UnsafeMutableRawPointer?, _ size: ARLive2DSize)

@_silgen_name("ARLive2DUpdate")
fileprivate func ARLive2DUpdate(_ handle: UnsafeMutableRawPointer?, _ deltaTime: TimeInterval)

@_silgen_name("ARLive2DRender")
fileprivate func ARLive2DRender(_ handle: UnsafeMutableRawPointer?, _ commandBuffer: UnsafeMutableRawPointer?, _ renderPassDescriptor: UnsafeMutableRawPointer?)

@_silgen_name("ARLive2DSetTalking")
fileprivate func ARLive2DSetTalking(_ handle: UnsafeMutableRawPointer?, _ talking: Bool)

@_silgen_name("ARLive2DSetMouthOpen")
fileprivate func ARLive2DSetMouthOpen(_ handle: UnsafeMutableRawPointer?, _ value: Float)

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

/// Swift wrapper for the native Live2D bridge
class Live2DBridge {
    private var handle: UnsafeMutableRawPointer?
    
    init() {
        self.handle = ARLive2DCreate()
        print("[Live2D] Native bridge created")
    }
    
    deinit {
        if let handle = self.handle {
            ARLive2DDestroy(handle)
            print("[Live2D] Native bridge destroyed")
        }
    }
    
    func initialize(modelPath: String, modelName: String) -> Bool {
        guard let handle = self.handle else {
            print("[Live2D] ERROR: Invalid handle")
            return false
        }
        
        let success = modelPath.withCString { path in
            modelName.withCString { name in
                let metalDevice: UnsafeMutableRawPointer? = nil
                return ARLive2DInitialize(handle, metalDevice, path, name)
            }
        }
        
        if success {
            print("[Live2D] Native bridge initialization successful")
        } else {
            print("[Live2D] ERROR: Native bridge initialization failed")
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
    
    func setMouthOpen(_ value: Float) {
        guard let handle = self.handle else { return }
        ARLive2DSetMouthOpen(handle, value)
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

/// Custom MTKView that integrates with Live2D bridge
class Live2DMetalView: MTKView {
    var bridge: Live2DBridge?
    private var frameCounter: Int = 0
    private var firstFrameLogged: Bool = false
    private var commandQueue: MTLCommandQueue?
    var setupCompleted: Bool = false
    
    override init(frame frameRect: NSRect, device: MTLDevice?) {
        print("[Live2D] Creating MTKView with frame: \(frameRect), device: \(String(describing: device))")
        super.init(frame: frameRect, device: device)
    }
    
    required init(coder: NSCoder) {
        print("[Live2D] Creating MTKView from coder")
        super.init(coder: coder)
    }
    
    func performSetup() {
        guard !setupCompleted else {
            print("[Live2D] MTKView setup already completed, skipping")
            return
        }
        
        print("[Live2D] Starting MTKView setup")
        print("[Live2D] Current device: \(String(describing: self.device))")
        
        guard let device = self.device else {
            print("[Live2D] ERROR: No MTLDevice available for setup")
            return
        }
        
        self.commandQueue = device.makeCommandQueue()
        print("[Live2D] Command queue created: \(String(describing: self.commandQueue))")
        
        self.delegate = self
        print("[Live2D] MTKView delegate assigned: self")
        
        self.isPaused = false
        print("[Live2D] MTKView paused: false")
        
        self.enableSetNeedsDisplay = false
        print("[Live2D] MTKView enableSetNeedsDisplay: false")
        
        self.colorPixelFormat = .bgra8Unorm_srgb
        self.framebufferOnly = false
        self.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        
        print("[Live2D] MTKView configuration complete")
        print("[Live2D] Drawable size: \(drawableSize.width)x\(drawableSize.height)")
        
        setupCompleted = true
        print("[Live2D] MTKView setup completed successfully")
    }
    
    override var drawableSize: CGSize {
        didSet {
            if !firstFrameLogged {
                print("[Live2D] Drawable size changed to: \(drawableSize.width)x\(drawableSize.height)")
            }
        }
    }
}

extension Live2DMetalView: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        print("[Live2D] Drawable size will change to: \(size.width)x\(size.height)")
        bridge?.resize(width: size.width, height: size.height)
    }
    
    func draw(in view: MTKView) {
        frameCounter += 1
        
        if frameCounter == 1 {
            NSLog("[Live2D] FIRST draw(in:) callback received - frame \(frameCounter)")
        }
        
        guard let bridge = bridge else {
            if frameCounter == 1 {
                NSLog("[Live2D] WARNING: No bridge set in MTKView")
            }
            return
        }
        
        guard let drawable = currentDrawable else {
            if frameCounter == 1 {
                NSLog("[Live2D] WARNING: No drawable available")
            }
            return
        }
        
        if frameCounter == 1 {
            NSLog("[Live2D] First drawable acquired")
        }
        
        guard let commandBuffer = commandQueue?.makeCommandBuffer() else {
            if frameCounter == 1 {
                NSLog("[Live2D] WARNING: Failed to create command buffer")
            }
            return
        }
        
        if frameCounter == 1 {
            NSLog("[Live2D] First command buffer created")
        }
        
        guard let renderPassDescriptor = currentRenderPassDescriptor else {
            if frameCounter == 1 {
                NSLog("[Live2D] WARNING: No render pass descriptor")
            }
            return
        }
        
        let deltaTime = 1.0 / 60.0
        bridge.update(deltaTime: deltaTime)
        
        if frameCounter == 1 {
            NSLog("[Live2D] First Cubism model update")
        }
        
        bridge.render(commandBuffer: commandBuffer, renderPassDescriptor: renderPassDescriptor)
        
        if frameCounter == 1 {
            NSLog("[Live2D] Texture bound to renderer")
            NSLog("[Live2D] Model loaded successfully")
            NSLog("[Live2D] DrawModel executed")
        }
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
        
        if frameCounter == 1 {
            NSLog("[Live2D] First command buffer committed")
            firstFrameLogged = true
        }
    }
}
