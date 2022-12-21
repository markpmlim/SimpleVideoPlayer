
## Creating a 360 Video Player with Metal

Overview:

The original demo Go360-sample was written by Hanton Yang together. He had also provided a step-by-step write-up on how to create a 360 degree video player at weblink 1. This version runs on iOS' OpenGLES and GLKit frameworks. 


This project includes the entire source code of Yang's demo as well as a demo that runs on Apple's Metal. Before looking at the source code of the Metal version, it is advisable to read the write-up at weblink 1 because the structure and logic of the Metal version follows the original sample code.

In the Metal version, we have added a custom NSView class backed by an instance of CAMetalLayer. The source code for the rendering class, MetalRenderer had to be re-written to setup the various objects required to support rendering to a Metal texture (MTLTexture). The method *updateTexture* of the original renderer class has to be modified extensively to extract 2 separate MTLTextures (lumaTexture and chormaTexture) which will be passed to a simple kernel function. The compute shader will convert the yuv colours of each video frame to rgb and output to an MTLTexture *outputTexture*. A simple vertex-fragment pair of functions will render the video frame 


The VideoPlayer source code has been modified to return the natural size of a video frame which is used to instantiate a read-and-write MTLTexture during the intialization of the MetalRenderer object. At the same time, the number of threads per thread group and the number of threadgroups per grid are pre-computed in order to avoid having to compute these during the draw function of the renderer.

*Requirements*:

XCode 8.x or XCode 9.x
Swift 3.x


References:


1) https://medium.com/@hanton.yang/how-to-create-a-360-video-player-with-opengl-es-3-0-and-glkit-360-3f29a9cfac88


2) http://flexmonkey.blogspot.com/2015/07/generating-filtering-metal-textures.html


3) https://github.com/McZonk/MetalCameraSample

4) https://developer.apple.com/library/archive/samplecode/AVGreenScreenPlayer/Listings/AVGreenScreenPlayer_GSPlayerView_m.html
