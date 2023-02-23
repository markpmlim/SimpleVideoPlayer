//
//  ViewController.swift
//  Go360-metal
//
//  Created by mark lim pak mun on 06/12/2022.
//  Copyright © 2022 Incremental Innovation. All rights reserved.
//
// An instance of CVDisplayLink will drive the display.

import Cocoa
import MetalKit
import AVFoundation

class MetalViewController: NSViewController, NSWindowDelegate {
    var metalView: MetalView {
        return self.view as! MetalView
    }
    
    let nameOfVideo = "demo.m4v"
    
    var displayLink: CVDisplayLink?
    var displaySource: DispatchSource!
    var currentTime = CVTimeStamp()
    
    var videoPlayer: VideoPlayer?
    var metalRenderer: MetalRenderer?
    var currentMouseLocation: CGPoint!
    var previousMouseLocation: CGPoint!
    var rotateX: Float = 0.0
    var rotateY: Float = 0.0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        prepareView()
        setupVideoPlayer()
        metalRenderer = MetalRenderer(metalLayer: metalView.metalLayer!,
                                      frameSize: (videoPlayer?.naturalSize)!,
                                      device: metalView.metalLayer!.device!)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(windowWillClose),
                                               name: Notification.Name.NSWindowWillClose,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(windowDidMiniaturize),
                                               name: Notification.Name.NSWindowDidMiniaturize,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(windowDidDeminiaturize),
                                               name: Notification.Name.NSWindowDidDeminiaturize,
                                               object: nil)
        videoPlayer?.play()
    }
    
    @objc func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSWindow == self.metalView.window) {
            CVDisplayLinkStop(displayLink!)
        }
    }
    
    @objc func windowDidMiniaturize(_ notification: Notification)
    {
        if (notification.object as? NSWindow == self.metalView.window) {
            videoPlayer?.pause()
            CVDisplayLinkStop(displayLink!)
        }
    }
    
    @objc func windowDidDeminiaturize(_ notification: Notification)
    {
        if (notification.object as? NSWindow == self.metalView.window) {
            CVDisplayLinkStart(displayLink!)
            videoPlayer?.play()
        }
    }

    deinit
    {
        CVDisplayLinkStop(displayLink!)
        NotificationCenter.default.removeObserver(self,
                                                  name: Notification.Name.NSWindowWillClose,
                                                  object: nil)
        NotificationCenter.default.removeObserver(self,
                                                  name: Notification.Name.NSWindowDidMiniaturize,
                                                  object: nil)
        NotificationCenter.default.removeObserver(self,
                                                  name: Notification.Name.NSWindowDidDeminiaturize,
                                                  object: nil)
    }
    
    override var representedObject: Any? {
        didSet {
        }
    }
    
    func prepareView() {
        metalView.metalLayer?.device = MTLCreateSystemDefaultDevice()
        guard metalView.metalLayer?.device != nil else {
            print("Metal is not supported on this device.");
            exit(1)
        }
        metalView.metalLayer?.framebufferOnly = false
        
        // Create a display link capable of being used with all active displays
        var cvReturn = CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        // The CVDisplayLink callback never executes on the main thread.
        // To execute rendering on the main thread, create a dispatch source
        // using the main queue (the main thread).
        let queue = DispatchQueue.main
        displaySource = DispatchSource.makeUserDataAddSource(queue: queue) as? DispatchSource
        displaySource.setEventHandler {
            // Get the current "now" time of the display link.
            CVDisplayLinkGetCurrentTime(self.displayLink!, &self.currentTime)
            // We should be getting 60 frames/s
            let fps = (self.currentTime.rateScalar * Double(self.currentTime.videoTimeScale) / Double(self.currentTime.videoRefreshPeriod))
            self.newFrame(fps)
        }
        displaySource.resume()
        
        cvReturn = CVDisplayLinkSetCurrentCGDisplay(displayLink!, CGMainDisplayID())
        cvReturn = CVDisplayLinkSetOutputCallback(displayLink!, {
            (timer: CVDisplayLink,
            inNow: UnsafePointer<CVTimeStamp>,
            inOutputTime: UnsafePointer<CVTimeStamp>,
            flagsIn: CVOptionFlags,
            flagsOut: UnsafeMutablePointer<CVOptionFlags>,
            displayLinkContext: UnsafeMutableRawPointer?) -> CVReturn in
            
            // CVDisplayLink callback merges the dispatch source in each call
            //  to execute rendering on the main thread.
            let sourceUnmanaged = Unmanaged<DispatchSourceUserDataAdd>.fromOpaque(displayLinkContext!)
            sourceUnmanaged.takeUnretainedValue().add(data: 1)
            return kCVReturnSuccess
        }, Unmanaged.passUnretained(displaySource).toOpaque())
        
        CVDisplayLinkStart(displayLink!)
    }
    
    private func setupVideoPlayer() {
        let pathComponents = nameOfVideo.components(separatedBy: ".")
        if let path = Bundle.main.path(forResource: pathComponents[0],
                                       ofType: pathComponents[1]) {
            let url = URL(fileURLWithPath: path)
            videoPlayer = VideoPlayer(url: url,
                                      framesPerSecond: 60)
        }
    }
    
    // This function is called on the main thread.
    fileprivate func newFrame(_ frameRate: Double) {
        guard let pixelBufer = self.videoPlayer?.retrievePixelBuffer() else {
            return
        }
        
        self.metalRenderer?.updateTextures(pixelBufer)
        self.metalRenderer?.draw()
    }
    
    // This method is called whenever there is a window/view resize
    override func viewDidLayout() {
        let viewSizePoints = metalView.bounds.size
        let viewSizePixels = metalView.convertToBacking(viewSizePoints)
        
        metalRenderer?.resize(viewSizePixels)
        
        if CVDisplayLinkIsRunning(displayLink!) {
            CVDisplayLinkStart(displayLink!)
        }
    }
    
    override func viewWillDisappear() {
        CVDisplayLinkStop(displayLink!)
    }
    
    override func viewDidAppear() {
        self.metalView.window!.makeFirstResponder(self)
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
        self.metalRenderer?.rotateX = self.rotateX
        self.metalRenderer?.rotateY = self.rotateY
    }
    
    override func mouseUp(with event: NSEvent) {
        let mouseLocation = self.view.convert(event.locationInWindow, from: nil)
        previousMouseLocation = mouseLocation
        currentMouseLocation = mouseLocation
    }
}

