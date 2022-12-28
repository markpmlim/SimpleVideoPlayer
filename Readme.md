
## Creating a 360 Simple Video Player with Metal and OpenGL

<br />
<br />

### Overview:

The original demo Go360-sample was written by Hanton Yang. He had also provided a step-by-step write-up on how to create a 360 degree video player posted at weblink 1. This version runs on iOS' OpenGLES and GLKit frameworks. 

<br />
<br />

### Details


<br />

This project includes the entire source code of Yang's demo as well as demos that runs on Apple's Metal and macOS' OpenGL implementation. Before looking at the source codes of the Metal and OpenGL versions, it is advisable to read the write-up posted at the reference 1 weblink because the structure and logic of the Metal and macOS OpenGL versions follows the original sample code.

In the Metal version, we have added a custom NSView class backed by an instance of CAMetalLayer. The source code for the rendering class, *MetalRenderer* had to be re-written to setup the various objects required to support rendering to a Metal texture (MTLTexture). The method *updateTextures* of the original renderer class has to be modified to extract 2 separate MTLTextures (*lumaTexture* and *chormaTexture*) which will be passed to a simple kernel function. The compute shader will convert the yuv colours of each video frame to rgb and output to an MTLTexture *outputTexture*. A simple vertex-fragment pair of functions will render the video frame.

Porting the Metal version to iOS should not be difficult.

<br />

**macOS OpenGL versions**

There are 2 versions. The first version configures the AVPlayerItemVideoOutput object with a pixel format of *kCVPixelFormatType_32BGRA*. The *updateTexture* function of its Renderer object is simpler compared to the corresponding function of the iOS version. The code of the fragment shader is much simpler.

The second version tell the AVPlayerItem object to instantiate a CVPixelBuffer object backed by a BiPlanar ioSurface. The video player must be configured wtih a different set of pixelBufferAttributes. The *updateTextures* function has to be modified extensively since the 2 corresponding functions of macOS OpenGL, *CVOpenGLTextureCacheCreate* and *CVOpenGLTextureCacheCreateTextureFromImage* can not be used to instantiate the luminance and chrominance textures. The recommendation is to use the function *CGLTexImageIOSurface2D*. According to Apple's documentation, only textures of type GL_TEXTURE_RECTANGLE are supported (reference 6). 

<br />
<br />
<br />

**Notes:**

a) macOS does not support the sub-class GLKViewController. We have to instantiate a CVDIsplayLink object to drive the display as well as implement a custom update function named *updateFrame*. Careful must be taken to ensure drawing to the display is done on the main thread. The video frames rendered don't look sharp.

b) The quality of display of the resulting video frames is not good. The video should be played with a view resolution 480:320. Higher resolutions will result in a grainy display. 

c) Since the generated texture of each video frame has the resolution 1920:960 pixels (equirectangular projection), instead of rendering a sphere, we could create a cubemap texture and render a skybox. In order to capture each 1920:960 video frame as a cubemap texture,  code must be written to render to a framebuffer object. Once the cubemap texture of each video frame is capture, the demo can use it to texture a skybox.

d) If the video is played with Apple's **AVGreenScreenPlayer**, the display looks odd. Each video frame is displayed as an EquiRectangular image at its original resolution of 1920:960 pixels.

e) We have made modifications to some of the source files, so that they could be compiled for both Go360 and Go360-macOS demos.

<br />
<br />
<br />

**Requirements:**

XCode 8.x or XCode 9.x
Swift 3.x

Runtime time:

macOS 10.12.x or later.

<br />
<br />

**References:**


1) https://medium.com/@hanton.yang/how-to-create-a-360-video-player-with-opengl-es-3-0-and-glkit-360-3f29a9cfac88


2) http://flexmonkey.blogspot.com/2015/07/generating-filtering-metal-textures.html


3) https://github.com/McZonk/MetalCameraSample

4) https://developer.apple.com/library/archive/samplecode/AVGreenScreenPlayer/Listings/AVGreenScreenPlayer_GSPlayerView_m.html

5) Technical Q&A QA1501

6) CGLIOSurface.h - Comment section of CGLTexImageIOSurface2D
