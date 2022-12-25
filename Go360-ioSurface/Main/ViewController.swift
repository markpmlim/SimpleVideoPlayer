
import Cocoa
import OpenGL

class ViewController: NSViewController {
    var oglView: NSOpenGLView {
        return self.view as! NSOpenGLView
    }

    var currentMouseLocation: CGPoint!
    var previousMouseLocation: CGPoint!
    var rotateX: Float = 0.0
    var rotateY: Float = 0.0
    var renderer: Renderer?
    var videoPlayer: VideoPlayer?
    var timer: Timer!
    var context: NSOpenGLContext!
    var framesPerSecond = 60.0
    var displayLink: CVDisplayLink?

    override func viewDidLoad() {
        super.viewDidLoad()
        prepareView()
        setupRenderer()
        setupVideoPlayer()

        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        CVDisplayLinkSetOutputCallback(displayLink!,
                                       displayLinkCallback,
                                       UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
        CVDisplayLinkStart(displayLink!)
 
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(windowWillClose),
                                               name: Notification.Name.NSWindowWillClose,
                                               object: nil)
    }

    let displayLinkCallback: CVDisplayLinkOutputCallback = {
        (displayLink: CVDisplayLink,
        inNow: UnsafePointer<CVTimeStamp>,
        inOutputTime: UnsafePointer<CVTimeStamp>,
        flagsIn: CVOptionFlags,
        flagsOut: UnsafeMutablePointer<CVOptionFlags>,
        displayLinkContext: UnsafeMutableRawPointer?) -> CVReturn in

        var currentTime = CVTimeStamp()
        CVDisplayLinkGetCurrentTime(displayLink, &currentTime)
        let fps = (currentTime.rateScalar * Double(currentTime.videoTimeScale) / Double(currentTime.videoRefreshPeriod))
        let vc = unsafeBitCast(displayLinkContext, to: ViewController.self)
        vc.updateFrame(fps)
        return kCVReturnSuccess
    }

    
    // This method is likely to be called on a secondary thread.
    @objc func updateFrame(_ framePerSecond: Double) {
        renderer?.updateModelViewProjectionMatrix(rotateX, rotateY)
        // Retrieve the video pixel buffer
        guard let pixelBufer = videoPlayer?.retrievePixelBuffer() else {
            return
        }
        DispatchQueue.main.async {
            CGLLockContext(self.context.cglContextObj!)
            // Update the OpenGL texture by using the current video pixel buffer
            self.context.makeCurrentContext()
            self.renderer?.updateTextures(pixelBufer)
            self.renderer?.render()
            CGLFlushDrawable(self.context.cglContextObj!)
            CGLUnlockContext(self.context.cglContextObj!)
        }
    }

    @objc func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSWindow == self.oglView.window) {
            CVDisplayLinkStop(displayLink!)
        }
    }

    deinit {
        CVDisplayLinkStop(displayLink!)
    }

    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }

    private func prepareView() {

        let pixelFormatAttrsBestCase: [NSOpenGLPixelFormatAttribute] = [
            UInt32(NSOpenGLPFADoubleBuffer),
            UInt32(NSOpenGLPFAAccelerated),
            UInt32(NSOpenGLPFABackingStore),
            UInt32(NSOpenGLPFADepthSize), UInt32(24),
            UInt32(NSOpenGLPFAOpenGLProfile), UInt32(NSOpenGLProfileVersion3_2Core),
            UInt32(0)
        ]
        
        let pf = NSOpenGLPixelFormat(attributes: pixelFormatAttrsBestCase)
        if (pf == nil) {
            Swift.print("Couldn't reset opengl attributes")
            abort()
        }
        oglView.pixelFormat = pf
        context = oglView.openGLContext!
    }

    private func setupRenderer() {
        context.makeCurrentContext()
        let shader = Shader()
        let model = Sphere()
        renderer = Renderer(view: oglView,
                            context: context,
                            shader: shader,
                            model: model)
    }

    private func setupVideoPlayer() {
        if let path = Bundle.main.path(forResource: "demo",
                                       ofType: "m4v") {
            let url = URL(fileURLWithPath: path)
            videoPlayer = VideoPlayer(url: url, framesPerSecond: Int(framesPerSecond))
            videoPlayer?.play()
        }
    }

    // This method is called whenever there is a window/view resize
    override func viewDidLayout() {
        let viewSizePoints = oglView.bounds.size
        let viewSizePixels = oglView.convertToBacking(viewSizePoints)
        
        renderer?.resize(viewSizePixels)
        
        if CVDisplayLinkIsRunning(displayLink!) {
            CVDisplayLinkStart(displayLink!)
        }
    }

    override func viewWillDisappear() {
        CVDisplayLinkStop(displayLink!)
    }

    override func viewDidAppear() {
        self.oglView.window!.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        
    }

    override func mouseDown(with event: NSEvent) {
        let mouseLocation = self.view.convert(event.locationInWindow, from: nil)
        currentMouseLocation = mouseLocation
        previousMouseLocation = mouseLocation
    }

    override func mouseDragged(with event: NSEvent) {
        let mouseLocation = self.view.convert(event.locationInWindow,
                                              from: nil)
        let radiansPerPoint: Float = 0.001
        var diffX = Float(mouseLocation.x - previousMouseLocation.x)
        var diffY = Float(mouseLocation.y - previousMouseLocation.y)

        diffX *= -radiansPerPoint
        diffY *= -radiansPerPoint
        rotateX += diffY
        rotateY += diffX
    }

    override func mouseUp(with event: NSEvent) {
        let mouseLocation = self.view.convert(event.locationInWindow, from: nil)
        previousMouseLocation = mouseLocation
        currentMouseLocation = mouseLocation
    }
}

