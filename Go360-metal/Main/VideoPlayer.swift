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
// Apple Documentation: "Responding to Playback State Changes"

import Foundation
import CoreVideo
import AVFoundation

class VideoPlayer: NSObject {
    var naturalSize: CGSize!                    // natural size of a video frame
    var nominalFrameRate: Float!                // # of frames per second

    private var avPlayer: AVPlayer!
    private var avPlayerItem: AVPlayerItem!
    private var avAsset: AVAsset!
    private var output: AVPlayerItemVideoOutput!

    // Key-value observing context
    private var playerItemContext = 0
    
    
    let requiredAssetKeys = [
        "playable",
        "hasProtectedContent"
    ]

    init(url: URL, framesPerSecond: Int) {
        super.init()
        avAsset = AVAsset(url: url)
        let tracks = avAsset.tracks(withMediaType: AVMediaTypeVideo)
        // All frames are expected to have the same size.
        naturalSize = tracks[0].naturalSize
        nominalFrameRate = tracks[0].nominalFrameRate
        // Create a new AVPlayerItem with the asset and an array of asset keys
        // to be automatically loaded
        avPlayerItem = AVPlayerItem(asset: avAsset,
                                    automaticallyLoadedAssetKeys: requiredAssetKeys)
        // Associate the player item with the player
        avPlayer = AVPlayer(playerItem: avPlayerItem)

        configureOutput(framesPerSecond: Int(nominalFrameRate))

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(playEnd),
                                               name: .AVPlayerItemDidPlayToEndTime,
                                               object: nil)

        // Register as an observer of the player item's status property
        avPlayerItem.addObserver(self,
                                 forKeyPath: #keyPath(AVPlayerItem.status),
                                 options: [.old, .new],
                                 context: &playerItemContext)
        
    }

    deinit {
        NotificationCenter.default.removeObserver(self,
                                                  name: .AVPlayerItemDidPlayToEndTime,
                                                  object: nil)
        avPlayerItem.removeObserver(self,
                                    forKeyPath: #keyPath(AVPlayerItem.status),
                                    context: nil)
    }

    func play() {
        avPlayer.play()
    }

    func retrievePixelBuffer() -> CVPixelBuffer? {
        let pixelBuffer = output.copyPixelBuffer(forItemTime: avPlayerItem.currentTime(),
                                                 itemTimeForDisplay: nil)
        return pixelBuffer
    }

    private func configureOutput(framesPerSecond: Int) {
        let pixelBuffer = [
            kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),
            kCVPixelBufferMetalCompatibilityKey as String : true
        ]
        output = AVPlayerItemVideoOutput(pixelBufferAttributes: pixelBuffer)
        output.requestNotificationOfMediaDataChange(withAdvanceInterval: 1.0 / TimeInterval(framesPerSecond))
        avPlayerItem.add(output)
    }

    @objc private func playEnd() {
        avPlayer.seek(to: kCMTimeZero)
        avPlayer.play()
    }

    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey : Any]?,
                               context: UnsafeMutableRawPointer?) {
        
        
        // Only handle observations for the playerItemContext
        guard context == &playerItemContext else {
            super.observeValue(forKeyPath: keyPath,
                               of: object,
                               change: change,
                               context: context)
            return
        }

        if keyPath == #keyPath(AVPlayerItem.status) {
            let status: AVPlayerItemStatus
            if let statusNumber = change?[.newKey] as? NSNumber {
                status = AVPlayerItemStatus(rawValue: statusNumber.intValue)!
            }
            else {
                status = .unknown
            }
            
            
            // Switch over status value
            switch status {
            case .readyToPlay:
                // Player item is ready to play.
                // The presentation size is only known when avPlayer starts playing.
                // We want to pass this size to the MetalRenderer to instantiate
                //  the output texture just once.
                print("presentation size:", (object as! AVPlayerItem).presentationSize)
                break
            case .failed:
                // Player item failed. See error.
                break
            case .unknown:
                // Player item is not yet ready.
                break
            }
        }
    }
}
