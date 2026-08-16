import AppKit
import Metal
import MetalKit
import AriaDomain

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

// Live2D bridge C API declarations are in Live2DConstants.swift

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

/// macOS window for displaying Live2D avatar
/// Uses Metal for rendering and hosts the Live2D model
@MainActor
public class Live2DWindow: NSWindow {
    
    private let metalView: Live2DMetalView
    private let configuration: AvatarConfiguration
    private var bridge: Live2DBridge?
    
    /// Creates a new Live2D window
    /// - Parameter configuration: Avatar configuration including model path
    public init(configuration: AvatarConfiguration = .sumireDefault) {
        self.configuration = configuration
        
        print("[Live2D] Creating Live2DWindow")
        
        // Create Metal device first
        guard let metalDevice = MTLCreateSystemDefaultDevice() else {
            print("[Live2D] ERROR: Failed to create MTLDevice")
            fatalError("Metal is not supported on this device")
        }
        
        print("[Live2D] MTLDevice created: \(metalDevice)")
        
        // Create custom Metal view with device - smaller portrait window for desktop companion
        let windowSize = NSSize(width: 300, height: 400)
        self.metalView = Live2DMetalView(frame: NSRect(origin: .zero, size: windowSize), device: metalDevice)
        print("[Live2D] MTKView created with device")
        
        // Now perform MTKView setup with valid device
        self.metalView.performSetup()
        
        // Initialize window with transparent background - no title bar for desktop companion
        super.init(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        // Set window to be transparent
        self.isOpaque = false
        self.backgroundColor = .clear
        self.titlebarAppearsTransparent = true
        self.hasShadow = false  // Remove shadow for cleaner transparency
        
        // Additional transparency settings
        if let contentView = self.contentView {
            contentView.wantsLayer = true
            contentView.layer?.backgroundColor = NSColor.clear.cgColor
        }
        
        // Set content size explicitly
        setContentSize(windowSize)
        
        print("[Live2D] NSWindow initialized")
        
        setupWindow()
    }
    
    /// Setup window properties
    private func setupWindow() {
        title = "Aria"
        
        // Don't use contentViewController - directly set content view
        contentView = metalView
        
        // Window level for desktop companion
        level = .floating
        
        // Ensure metal view has transparency settings
        metalView.wantsLayer = true
        if let metalLayer = metalView.layer {
            metalLayer.backgroundColor = NSColor.clear.cgColor
            metalLayer.isOpaque = false
        }
        
        // Position window in bottom right corner for desktop companion
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowWidth = frame.width
            let x = screenFrame.maxX - windowWidth - 20  // 20px from right edge
            let y = screenFrame.minY + 20  // 20px from bottom edge
            setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        // Enable autoresizing
        metalView.autoresizingMask = [.width, .height]
        
        print("[Live2D] Window created with Metal view")
        print("[Live2D] Model path: \(configuration.modelDirectory.path)")
        print("[Live2D] Model name: \(configuration.modelName)")
        
        validateModelAssets()
        initializeBridge()
    }
    
    /// Validate model assets exist
    private func validateModelAssets() {
        let modelDir = configuration.modelDirectory
        let moc3Path = modelDir.appendingPathComponent("\(configuration.modelName).moc3")
        let model3Path = modelDir.appendingPathComponent("\(configuration.modelName).model3.json")
        
        let moc3Exists = FileManager.default.fileExists(atPath: moc3Path.path)
        let model3Exists = FileManager.default.fileExists(atPath: model3Path.path)
        
        // Count textures
        let textureDir = modelDir.appendingPathComponent("\(configuration.modelName).8192")
        var textureCount = 0
        if FileManager.default.fileExists(atPath: textureDir.path) {
            if let textureFiles = try? FileManager.default.contentsOfDirectory(atPath: textureDir.path) {
                textureCount = textureFiles.filter { $0.hasPrefix("texture_") && $0.hasSuffix(".png") }.count
            }
        }
        
        print("[Live2D Model]")
        print("directory=\(configuration.modelDirectory.path)")
        print("modelName=\(configuration.modelName)")
        print("model3=\(model3Path.path)")
        print("moc3=\(moc3Path.path)")
        print("textures=\(textureCount)")
        
        print("[Live2D] Model file found: \(moc3Exists)")
        print("[Live2D] Model3.json found: \(model3Exists)")
        print("[Live2D] Texture count: \(textureCount)")
    }
    
    /// Initialize the Live2D bridge
    private func initializeBridge() {
        print("[Live2D] Initializing Live2D bridge")
        
        // Create bridge
        self.bridge = Live2DBridge()
        
        // Initialize with model path and model name
        let success = bridge?.initialize(modelPath: configuration.modelDirectory.path, modelName: configuration.modelName)
        
        if success == true {
            print("[Live2D] Bridge initialized successfully")
            print("[Live2D] MOC3 loaded successfully")
            print("[Live2D] Renderer initialized with model")
            metalView.bridge = bridge
        } else {
            print("[Live2D] ERROR: Bridge initialization failed")
        }
    }
    
    /// Show the window and start rendering
    public func showWindow() {
        NSLog("[Live2D] showWindow() called")
        
        // Ensure the Metal view has proper frame before showing
        metalView.frame = contentView!.bounds
        NSLog("[Live2D] Metal view frame set to: \(metalView.frame)")
        
        NSLog("[Live2D] Calling makeKeyAndOrderFront")
        makeKeyAndOrderFront(nil)
        orderFrontRegardless()
        
        NSLog("[Live2D] Window shown")
        NSLog("[Live2D] Window frame: \(frame)")
        NSLog("[Live2D] Metal view frame: \(metalView.frame)")
        NSLog("[Live2D] Drawable size: \(metalView.drawableSize)")
        NSLog("[Live2D] Window visible: \(isVisible)")
        
        // Additional diagnostic logs
        NSLog("[Live2D] MTKView device: \(String(describing: metalView.device))")
        NSLog("[Live2D] MTKView delegate: \(String(describing: metalView.delegate))")
        NSLog("[Live2D] MTKView isPaused: \(metalView.isPaused)")
        NSLog("[Live2D] MTKView enableSetNeedsDisplay: \(metalView.enableSetNeedsDisplay)")
        NSLog("[Live2D] MTKView preferredFramesPerSecond: \(metalView.preferredFramesPerSecond)")
    }
    
    /// Hide the window and stop rendering
    public func hideWindow() {
        orderOut(nil)
        print("[Live2D] Window hidden")
    }
    
    /// Update avatar state
    /// - Parameter state: New avatar state
    public func updateAvatarState(_ state: AvatarState) {
        print("[Live2D] Avatar state: \(state)")
        
        guard let bridge = self.bridge else { return }
        
        let isTalking = (state == .talking)
        bridge.setTalking(isTalking)
        
        // Set mouth open value for lip sync
        if isTalking {
            bridge.setMouthOpen(1.5) // Open mouth when talking
        } else {
            bridge.setMouthOpen(0.0) // Close mouth when not talking
        }
    }
    
    /// Clean up resources
    public func dispose() {
        // Bridge cleanup happens in deinit
        self.bridge = nil
        
        print("[Live2D] Resources disposed")
    }
    
    deinit {
        // Bridge cleanup happens automatically through ARC
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
        // Don't call setup() here - wait until device is properly assigned
    }
    
    required init(coder: NSCoder) {
        print("[Live2D] Creating MTKView from coder")
        super.init(coder: coder)
        // Don't call setup() here - wait until device is properly assigned
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
        self.framebufferOnly = false  // Allow reading for transparency
        self.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)  // Fully transparent
        
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
        
        // First frame logging
        if frameCounter == 1 {
            NSLog("[Live2D] FIRST draw(in:) callback received - frame \(frameCounter)")
        }
        
        if frameCounter == 60 {
            NSLog("[Live2D] 60 frames rendered")
        }
        
        guard let bridge = bridge else {
            if frameCounter == 1 {
                NSLog("[Live2D] WARNING: No bridge set in MTKView")
            }
            return
        }
        
        // Get current drawable and render pass
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
        
        // Update model state before drawing
        let deltaTime = 1.0 / 60.0 // Assuming 60 FPS
        bridge.update(deltaTime: deltaTime)
        
        if frameCounter == 1 {
            NSLog("[Live2D] First Cubism model update")
        }
        
        // Draw with bridge
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