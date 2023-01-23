///// Copyright (c) 2017 Razeware LLC
/// 
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
/// 
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
/// 
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
/// 
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import Foundation
import CoreVideo
import AVFoundation

class VideoPlayer {
    private var avPlayer: AVPlayer!
    private var avPlayerItem: AVPlayerItem!
    private var avAsset: AVAsset!
    private var output: AVPlayerItemVideoOutput!

    init(url: URL, framesPerSecond: Int) {
        avAsset = AVAsset(url: url)
        avPlayerItem = AVPlayerItem(asset: avAsset)
        avPlayer = AVPlayer(playerItem: avPlayerItem)

        configureOutput(framesPerSecond: framesPerSecond)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(playEnd),
                                               name: .AVPlayerItemDidPlayToEndTime,
                                               object: nil)
    }

    func play() {
        avPlayer.play()
    }

    func retrievePixelBuffer() -> CVPixelBuffer? {
        if output.hasNewPixelBuffer(forItemTime: avPlayerItem.currentTime()) {
            let pixelBuffer = output.copyPixelBuffer(forItemTime: avPlayerItem.currentTime(),
                                                     itemTimeForDisplay: nil)
            return pixelBuffer
        }
        else {
            return nil
        }
    }

    private func configureOutput(framesPerSecond: Int) {
    #if os(iOS)
        let pixelBufferAttrs = [
            kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
        ]
    #else
        // BGRA32 is native fast path RGBA upload on Intel x86/x64 machines for 4:4:4 sampling RGB.
        let pixelFormatKeys = [kCVPixelFormatType_32BGRA] as CFArray

        let pixelBufferAttrs: [String : Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: pixelFormatKeys,
            kCVPixelBufferOpenGLCompatibilityKey as String: true
        ]
    #endif
        output = AVPlayerItemVideoOutput(pixelBufferAttributes: pixelBufferAttrs)
        output.requestNotificationOfMediaDataChange(withAdvanceInterval: 1.0 / TimeInterval(framesPerSecond))
        avPlayerItem.add(output)
    }

    @objc private func playEnd() {
        avPlayer.seek(to: kCMTimeZero)
        avPlayer.play()
    }
}
