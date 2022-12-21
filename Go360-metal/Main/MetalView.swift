//
//  MetalView.swfit
//  Go360-metal
//
//  Created by Mark Lim Pak Mun on 22/09/2020.
//  Copyright © 2020 Incremental Innovation. All rights reserved.
//


import AppKit

class MetalView: NSView {
    var metalLayer: CAMetalLayer?

    override var wantsUpdateLayer: Bool {
        return true
    }

    override func makeBackingLayer() -> CALayer {
        return CAMetalLayer()
    }

    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        let scale = NSScreen.main()?.backingScaleFactor
        metalLayer?.drawableSize = CGSize(width: self.bounds.size.width * scale!,
                                          height: self.bounds.size.height * scale!)
    }

    override func setBoundsSize(_ newSize: NSSize) {
        super.setBoundsSize(newSize)
        let scale = NSScreen.main()?.backingScaleFactor
        metalLayer?.drawableSize = CGSize(width: self.bounds.size.width * scale!,
                                          height: self.bounds.size.height * scale!)
    }

    // Never called
    override func updateLayer() {
        //Make changes to the layer here!
        Swift.print("updateLayer");
    }

    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)

        // The statement below should trigger a call to the func makeBackerLayer()
        self.wantsLayer = true
        // On return, the view's "layer" property is set to an instance of CAMetalLayer
        metalLayer = self.layer as? CAMetalLayer
        metalLayer?.pixelFormat = MTLPixelFormat.bgra8Unorm // default
        self.layerContentsRedrawPolicy = .duringViewResize
    }
}
