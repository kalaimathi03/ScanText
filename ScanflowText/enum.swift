//
//  enum.swift
//  ScanflowText
//
//  Created by Mac-OBS-46 on 22/12/22.
//

import Foundation
import UIKit

typealias FileInfo = (name: String, extension: String)

typealias CompletionHandler = (_ success: Result?) -> Void



enum YoloV4 {
  static let modelInfo: FileInfo = (name: "tyre-char-rec-yolov4-tiny_v.10", extension: "tflite")
  static let labelsInfo: FileInfo = (name: "labelmap", extension: "txt")
}

enum Effici {
  static let modelInfo: FileInfo = (name: "eff-net-tyre-char-classifier_v1.7", extension: "tflite")
  static let labelsInfo: FileInfo = (name: "effiLabel", extension: "txt")
}

enum EfficiForDOT {
  static let labelsInfo: FileInfo = (name: "dot-labels", extension: "txt")
}
struct Result {
  let inferences: [Inference]
}

enum ModelType {
    case classificationModel
    case detectionModel
}

struct Inference {
    let confidence: Float
    let className: String
    let rect: CGRect
    let boundingRect:CGRect
    let displayColor: UIColor
    let outputImage : UIImage
    let previewWidth : CGFloat
    let previewHeight : CGFloat
    var decodedValue: String? = nil
}



/**
 This is public struct OutScore holds the confidence level in float
 */
public struct OutScore {
    var confidenceLevel: Float
}

/**
 This is public struct DetectedBox holds its count
 */
public struct DetectedBox {
    var count: Float
}


extension Array {
  /// Creates a new array from the bytes of the given unsafe data.
  ///
  /// - Warning: The array's `Element` type must be trivial in that it can be copied bit for bit
  ///     with no indirection or reference-counting operations; otherwise, copying the raw bytes in
  ///     the `unsafeData`'s buffer to a new array returns an unsafe copy.
  /// - Note: Returns `nil` if `unsafeData.count` is not a multiple of
  ///     `MemoryLayout<Element>.stride`.
  /// - Parameter unsafeData: The data containing the bytes to turn into an array.
  init?(unsafeData: Data) {
    guard unsafeData.count % MemoryLayout<Element>.stride == 0 else { return nil }
    #if swift(>=5.0)
    self = unsafeData.withUnsafeBytes { .init($0.bindMemory(to: Element.self)) }
    #else
    self = unsafeData.withUnsafeBytes {
      .init(UnsafeBufferPointer<Element>(
        start: $0,
        count: unsafeData.count / MemoryLayout<Element>.stride
      ))
    }
    #endif  // swift(>=5.0)
  }
}

extension Data {
  /// Creates a new buffer by copying the buffer pointer of the given array.
  ///
  /// - Warning: The given array's element type `T` must be trivial in that it can be copied bit
  ///     for bit with no indirection or reference-counting operations; otherwise, reinterpreting
  ///     data from the resulting buffer has undefined behavior.
  /// - Parameter array: An array with elements of type `T`.
  init<T>(copyingBufferOf array: [T]) {
    self = array.withUnsafeBufferPointer(Data.init)
  }
}


extension UIImage {
    
    func toPixelBuffer() -> CVPixelBuffer {
        let cgimage = self.cgImage
        let frameSize = CGSize(width: self.size.width, height: self.size.height)
        var pixelBuffer:CVPixelBuffer? = nil
        let _ = CVPixelBufferCreate(kCFAllocatorDefault, Int(cgimage?.width ?? 0), Int(cgimage?.height ?? 0), kCVPixelFormatType_32BGRA , nil, &pixelBuffer)
        
        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags.init(rawValue: 0))
        let data = CVPixelBufferGetBaseAddress(pixelBuffer!)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
        let context = CGContext(data: data, width: Int(frameSize.width), height: Int(frameSize.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: bitmapInfo.rawValue)
        
        
        context?.draw(cgimage!, in: CGRect(x: 0, y: 0, width: cgimage?.width ?? 0, height: cgimage?.height ?? 0))
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        return pixelBuffer!
        
    }
    

}

extension UIImage{
    func cropImage(frame:CGRect) -> UIImage{
        guard let cgImage = self.cgImage else { return UIImage() }
        let croppedCGImage = cgImage.cropping(to: frame)
        return UIImage(cgImage: croppedCGImage!)
    }
}
