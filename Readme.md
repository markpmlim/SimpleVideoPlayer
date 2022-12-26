
## Creating a 360 Video Player with Metal and OpenGL

Overview:

The original demo Go360-sample was written by Hanton Yang together. He had also provided a step-by-step write-up on how to create a 360 degree video player at weblink 1. This version runs on iOS' OpenGLES and GLKit frameworks. 


This project includes the entire source code of Yang's demo as well as a demo that runs on Apple's Metal. Before looking at the source code of the Metal version, it is advisable to read the write-up posted at the reference 1 weblink because the structure and logic of the Metal and macOS versions follows the original sample code.

In the Metal version, we have added a custom NSView class backed by an instance of CAMetalLayer. The source code for the rendering class, *MetalRenderer* had to be re-written to setup the various objects required to support rendering to a Metal texture (MTLTexture). The method *updateTextures* of the original renderer class has to be modified to extract 2 separate MTLTextures (lumaTexture and chormaTexture) which will be passed to a simple kernel function. The compute shader will convert the yuv colours of each video frame to rgb and output to an MTLTexture *outputTexture*. A simple vertex-fragment pair of functions will render the video frame .
Porting the Metal version to iOS should not be difficult.


**macOS OpenGL versions**
There are 2 versions. The first version configures the AVPlayerItemVideoOutput object with a pixel format of kCVPixelFormatType_32ARGB. The *updateTexture* function of the Renderer object is simpler compared to the corresponding function of the iOS version.

The second version uses a BiPlanar ioSurface. The video player must be configured  wtih a different set of  pixelBufferAttributes. The *updateTextures* function has to be modified extensively since the 2 corresponding functions of macOS OpenGL, *CVOpenGLTextureCacheCreate* and *CVOpenGLTextureCacheCreateTextureFromImage* can not be used to instantiate the luminance and chrominance textures. The recommendation is to use the function *CGLTexImageIOSurface2D*. According to Apple's documentation, only textures of type GL_TEXTURE_RECTANGLE are supported (reference 6). 


**Notes:**

a) macOS does not support the sub-class GLKViewController. We have to instantiate a CVDIsplayLink object to drive the display as well as implement a custom update function named *updateFrame*. Careful must be taken to ensure drawing to the display is done on the main thread. The video frames rendered don't look sharp.

b) The quality of display of the resulting video frames is not as good if the original video is played by Apple's AVGreenPlayer demo. Since the generated textures are equirectangular images, instead of rendering a sphere, we could create cubemap texturess and render a skybox.


**Requirements:**

XCode 8.x or XCode 9.x
Swift 3.x

Runtime time:

macOS 10.13.x or later.

**References:**


1) https://medium.com/@hanton.yang/how-to-create-a-360-video-player-with-opengl-es-3-0-and-glkit-360-3f29a9cfac88


2) http://flexmonkey.blogspot.com/2015/07/generating-filtering-metal-textures.html


3) https://github.com/McZonk/MetalCameraSample

4) https://developer.apple.com/library/archive/samplecode/AVGreenScreenPlayer/Listings/AVGreenScreenPlayer_GSPlayerView_m.html

5) Technical Q&A QA1501

6) CGLIOSurface.h - Comment section of CGLTexImageIOSurface2D
