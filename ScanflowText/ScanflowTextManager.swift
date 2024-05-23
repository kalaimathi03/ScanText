//
//  ScanflowTextManager.swift
//  ScanflowText
//
//  Created by Mac-OBS-46 on 22/12/22.
//

import Foundation
import ScanflowCore
import UIKit
import CoreVideo
import CoreMedia
import Accelerate
import opencv2

struct BoundingBox {
    var xPosition: Float
    var yPosition: Float
    var width: Float
    var height: Float
}

@objc public enum TireScanningMode: Int {
    case tireSerialNumberScanning
    case tireDotScanning
}

@objc public enum ContainerScanningMode: Int {
    case verticle
    case horizontal
}


@objc(ScanflowTextManager)
public class ScanflowTextManager: ScanflowCameraManager {
    
    var interpreter: Interpreter?
    internal var effiInterpreter: Interpreter?
    var threadCount = 1
    var resizedBufferImage: UIImage?
    var originalBufferImage: UIImage?
    internal var labels: [String] = []
    
    internal let batchSize = 1
    internal let inputChannels = 3
    internal let inputWidth = 416.0
    internal let inputHeight = 416.0
    
    internal let edgeOffset: CGFloat = 2.0
    internal let labelOffset: CGFloat = 10.0
    internal let animationDuration = 0.5
    internal let collapseTransitionThreshold: CGFloat = -30.0
    internal let expandTransitionThreshold: CGFloat = 30.0
    internal let delayBetweenInferencesMs: Double = 200
    
    
    internal let efficientInputWidth = 224.0
    internal let efficientInputHeight = 224.0
    var timer = Timer()

    // image mean and std for floating model, should be consistent with parameters used in model training
    private let imageMean: Float = 127.5
    private let imageStd:  Float = 127.5
    @objc public var startCapture: Bool = false
    private var resultArray: [String] = []
     var finalResult: String = ""
    internal var dectectionModelPath: String?
    internal var classificationModelPath: String?
    private var modelType: ModelType?
    internal var containerResult:[String: Float] = [:]
    var tireResult: [String]? = []
     var currentConfidenceLevel: Float?
     var sortedTireResult: UIImage?
    var inProgress: Bool = false
    var predictionArray = ["D0T", "D01", "0T", "001", "00T", "DDT", "DD1", "N01", "OOT", "0O1", "O0T", "DO7", "D07", "DD7", "N07"]
    @objc(init:::::::::)
    public override init(previewView: UIView, scannerMode: ScannerMode, overlayApperance: OverlayViewApperance, overCropNeed: Bool = false, leftTopArc: UIColor = .topLeftArrowColor, leftDownArc: UIColor = .bottomLeftArrowColor, rightTopArc: UIColor = .topRightArrowColor, rightDownArc: UIColor = .bottomRightArrowColor, locationNeed: Bool = false) {
        super.init(previewView: previewView, scannerMode: scannerMode, overlayApperance: overlayApperance, overCropNeed: overCropNeed, leftTopArc: leftTopArc, leftDownArc: leftDownArc, rightTopArc: rightTopArc, rightDownArc: rightDownArc, locationNeed: locationNeed)
        captureDelegate = self
        toBeSendInDelegate = false
        if scannerType == .tire {
            setupModelFiles(modelType: .classificationModel)
            setupModelFiles(modelType: .detectionModel)
            initializeYolo()
            initializeEffi()
        } else if scannerType == .dotTire {
            initializeYoloForDot()
            initializeEffiForDOT()
        } else {
            initContainerModel()
        }
    }

    @objc(changeScanner:)
    public func changeScanner(mode: TireScanningMode) {
        switch mode {
            case .tireDotScanning:
                self.scannerType = .dotTire
                initializeYoloForDot()
                initializeEffiForDOT()

            case .tireSerialNumberScanning:
                self.scannerType = .tire

                setupModelFiles(modelType: .classificationModel)
                setupModelFiles(modelType: .detectionModel)
                initializeYolo()
                initializeEffi()
        }
    }

    public func changeScan(mode: ContainerScanningMode) {
        switch mode {
            case .verticle:
            self.scannerType = .containerHorizontal

            initContainerModel()
               

            case .horizontal:
                self.scannerType = .containerHorizontal

            initContainerModel()
        }
    }
    
    func initializeYoloForDot() {
        self.threadCount = 1

        let bundle = Bundle(for: type(of: self))

        // Specify the options for the `Interpreter`.
        var options = Interpreter.Options()
        options.threadCount = threadCount
        do {
             let litePath = bundle.path(forResource: "DOT-det-yolov5s-v1.3", ofType: "tflite")
            // Create the `Interpreter`.
            interpreter = try Interpreter(modelPath: litePath!, options: options)
            // Allocate memory for the model's input `Tensor`s.
            try interpreter?.allocateTensors()
        } catch let error {
            print(error)
            return
        }
    }


    func scaleBbox(_ bbox: [Int], originalWidth: Int, originalHeight: Int, targetWidth: Int, targetHeight: Int) -> [Int] {
        // Extract the coordinates of the original bounding box
        let xmin = bbox[0]
        let ymin = bbox[1]
        let xmax = bbox[2]
        let ymax = bbox[3]

        let xScale = Float(targetWidth) / Float(originalWidth)
        let yScale = Float(targetHeight) / Float(originalHeight)

        let new_xmin = Int(round(Float(xmin) * xScale))
        let new_ymin = Int(round(Float(ymin) * yScale))
        let new_xmax = Int(round(Float(xmax) * xScale))
        let new_ymax = Int(round(Float(ymax) * yScale))

        return [new_xmin, new_ymin, new_xmax, new_ymax]
    }

    func rescaleBbox(_ scaledBbox: [Int], originalWidth: Int, originalHeight: Int, targetWidth: Int, targetHeight: Int) -> [Int] {
        // Extract the coordinates of the scaled bounding box
        let xmin = scaledBbox[0]
        let ymin = scaledBbox[1]
        let xmax = scaledBbox[2]
        let ymax = scaledBbox[3]

        // Calculate the scaling factors for both width and height
        let scale_x = Float(originalWidth) / Float(targetWidth)
        let scale_y = Float(originalHeight) / Float(targetHeight)

        // Rescale the coordinates to the original image size
        let original_xmin = Int(Float(xmin) * scale_x)
        let original_ymin = Int(Float(ymin) * scale_y)
        let original_xmax = Int(Float(xmax) * scale_x)
        let original_ymax = Int(Float(ymax) * scale_y)

        return [original_xmin, original_ymin, original_xmax, original_ymax]
    }


    func initializeEffiForDOT() {
        self.threadCount = 1
        let bundle = Bundle(for: type(of: self))

        // Specify the options for the `Interpreter`.
        var options = Interpreter.Options()
        options.threadCount = threadCount
        do {
            let litePath = bundle.path(forResource: "eff-net-dot-char-cls_v1.0", ofType: "tflite")

            // Create the `Interpreter`.
            effiInterpreter = try Interpreter(modelPath: litePath!, options: options)
            // Allocate memory for the model's input `Tensor`s.
            try effiInterpreter?.allocateTensors()
        } catch let error {
            print(error)
            return
        }
        loadLabels(fileInfo: EfficiForDOT.labelsInfo)
    }

    
    //MARK: YOLO INITIALIZER
    func initializeYolo() {
        self.threadCount = 1
   
        let bundle = Bundle(for: type(of: self))

        // Specify the options for the `Interpreter`.
        var options = Interpreter.Options()
        options.threadCount = threadCount
        do {
             let litePath = bundle.path(forResource: "det", ofType: "tflite")
            // Create the `Interpreter`.
            interpreter = try Interpreter(modelPath: litePath!, options: options)
            // Allocate memory for the model's input `Tensor`s.
            try interpreter?.allocateTensors()
        } catch let error {
            print(error)
            return
        }
    }
    
    private func setupModelFiles(modelType: ModelType)  {
        var fullData = Data()
        for modelId in 1...12 {
            let bundle = Bundle(for: type(of: self))
            guard let litePath = bundle.path(forResource: "\(modelType == .classificationModel  ? "cls" : "det")", ofType: "tflite") else {
                print("Failed to load the model file with name:")
                return
            }
            #warning("below code commneted for testing purpose")
//            if let splitedData = try? Data(contentsOf: URL(fileURLWithPath: litePath)) {
//                if modelId != 12 {
//                    fullData.append(splitedData)
//                } else {
//
//                    if modelType == .classificationModel {
//                        if let lastData = decryptFile(key: "d5a423f64b607ea7c65b311d855dc48f36114b227bd0c7a3d403f6158a9e4412", nonce: "131348c0987c7eece60fc0bc", data: splitedData) {
//                            fullData.append(lastData)
//                        }
//                    } else {
//                        if let lastData = decryptFile(key: "d5a423f64b607ea7c65b311d855dc48f36114b227bd0c7a3d403f6158a9e4412", nonce: "131348c0987c7eece60fc0bc", data: splitedData) {
//                            fullData.append(lastData)
//                        }
//                    }
//
//                }
//            }
            
        }
        
        createPath(fileName: "\(modelType == .classificationModel ? "cls" : "det")", splitedData: fullData, modeltype: modelType)
    }

    func createPath(fileName: String, splitedData: Data, modeltype: ModelType) {
        let documentDirectoryUrl = try! FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        
        let fileUrl = documentDirectoryUrl.appendingPathComponent(fileName).appendingPathExtension("tflite")
        do {
            try splitedData.write(to: fileUrl)
            if modeltype == .classificationModel {
                classificationModelPath = fileUrl.absoluteString.split(separator: ":").last!.description
            } else {
                dectectionModelPath = fileUrl.absoluteString.split(separator: ":").last!.description
            }
        } catch let error as NSError {
            print (error)
        }
    }
    
    
    //MARK: RUN YOLO MODEL
    func runModel(onFrame pixelBuffer: CVPixelBuffer, previewSize: CGSize) -> Result? {
        
        //DKManager.shared.print(message: "Start Runmodel", function: .runModel)
        let imageWidth = CVPixelBufferGetWidth(pixelBuffer)
        let imageHeight = CVPixelBufferGetHeight(pixelBuffer)
        
        let imageChannels = 4
        assert(imageChannels >= inputChannels)
        
        let scaledSize = CGSize(width: inputWidth, height: inputHeight)
        guard let scaledPixelBuffer = pixelBuffer.resized(to: scaledSize) else {
            return nil
        }
        
        let outputBoundingBox: Tensor
        let outputClasses: Tensor
        do {
            
            //DKManager.shared.print(message: "MODEL STARTED", function: .runModel)
            let inputTensor = try interpreter?.input(at: 0)
            
            //DKManager.shared.print(message: "BEFORE RGB RESIZE", function: .runModel)
            // Remove the alpha component from the image buffer to get the RGB data.
            
            guard let rgbData = rgbDataFromBuffer(
                scaledPixelBuffer,
                byteCount: batchSize * Int(inputWidth) * Int(inputHeight) * inputChannels,
                isModelQuantized: inputTensor?.dataType == .uInt8
            ) else {
                //DKManager.shared.print(message: "Failed to convert the image buffer to RGB data.", function: .runModel)
                return nil
            }
            
            
           // DKManager.shared.print(message: "AFTER RGB SIZE", function: .runModel)
            
            // Copy the RGB data to the input `Tensor`.
            try interpreter?.copy(rgbData, toInputAt: 0)
            // Run inference by invoking the `Interpreter`.
            try interpreter?.invoke()
            
            outputBoundingBox = try interpreter?.output(at: 0) as! Tensor
            outputClasses = try interpreter?.output(at: 1) as! Tensor
            //DKManager.shared.print(message: "MODEL COMPLETED", function: .runModel)
            
            
        } catch let error {
            //DKManager.shared.print(message: "Failed to invoke the interpreter with error: \(error.localizedDescription)", function: .runModel)
            print(error.localizedDescription)
            return nil
        }
        
        let outputcount: Int = outputBoundingBox.shape.dimensions[1]
        
        let boundingBox = [BoundingBox](unsafeData: outputBoundingBox.data)!
        
        let OutScore = [OutScore](unsafeData: outputClasses.data)!
        
           
        let resultArray = formatResults(
            boundingBox: boundingBox,
            outputClasses: OutScore,
            outputCount: outputcount,
            width: CGFloat(imageWidth),
            height: CGFloat(imageHeight), previewSize: previewSize
        )
        
        let result = Result(inferences: resultArray)
        return result
        
    }
    
    public func rgbDataFromBuffer(
        _ buffer: CVPixelBuffer,
        byteCount: Int,
        isModelQuantized: Bool
    ) -> Data? {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
        }
        guard let sourceData = CVPixelBufferGetBaseAddress(buffer) else {
            return nil
        }
        
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let sourceBytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let destinationChannelCount = 3
        let destinationBytesPerRow = destinationChannelCount * width
        
        var sourceBuffer = vImage_Buffer(data: sourceData,
                                         height: vImagePixelCount(height),
                                         width: vImagePixelCount(width),
                                         rowBytes: sourceBytesPerRow)
        
        guard let destinationData = malloc(height * destinationBytesPerRow) else {
            SFManager.shared.print(message: "Error: out of memory", function: .rgbDataFromBuffer)
            return nil
        }
        
        defer {
            free(destinationData)
        }
        
        var destinationBuffer = vImage_Buffer(data: destinationData,
                                              height: vImagePixelCount(height),
                                              width: vImagePixelCount(width),
                                              rowBytes: destinationBytesPerRow)
        
        if (CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_32BGRA){
            vImageConvert_BGRA8888toRGB888(&sourceBuffer, &destinationBuffer, UInt32(kvImageNoFlags))
        } else if (CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_32ARGB) {
            vImageConvert_ARGB8888toRGB888(&sourceBuffer, &destinationBuffer, UInt32(kvImageNoFlags))
        }
        
        let byteData = Data(bytes: destinationBuffer.data, count: destinationBuffer.rowBytes * height)
        if isModelQuantized {
            return byteData
        }
        
        // Not quantized, convert to floats
        let bytes = Array<UInt8>(unsafeData: byteData)!
        var floats = [Float]()
        for byte in 0..<bytes.count {
            floats.append((Float(bytes[byte]) - imageMean) / imageStd)
        }
        return Data(copyingBufferOf: floats)
    }
    
    func formatResults(boundingBox: [BoundingBox], outputClasses: [OutScore],
                       outputCount: Int, width: CGFloat,
                       height: CGFloat, previewSize: CGSize) -> [Inference] {
        
        
        var resultsArray: [Inference] = []
        if (outputCount == 0) {
            return resultsArray
        }
        var floatVec: [Float] = []

        let filteredBoundingBox = outputClasses.enumerated().filter({
            if ($0.element.confidenceLevel > 0.5) {
                floatVec.append($0.element.confidenceLevel)
                return true
            } else {
                return false
            }
            
        }).map({boundingBox[$0.offset]})
        var process:[Rect2d] = []
        var temo = 0
        var countd:[Int32] = []
        for fil in filteredBoundingBox {
            process.append(Rect2d(x: Double(fil.xPosition), y: Double(fil.yPosition), width: Double(fil.width), height: Double(fil.height)))
            temo = temo + 1
            
        }
        var thinker : IntVector = IntVector(countd)
        opencv2.Dnn.NMSBoxes(bboxes: process, scores: FloatVector(floatVec), score_threshold: 0.5, nms_threshold: 0.45, indices: thinker)
        
        var tempFilteredResults:[BoundingBox] = []
        var tempConfidenceArray:[Float] = []
        for thin in thinker.array {
            tempFilteredResults.append(filteredBoundingBox[Int(thin)])
            tempConfidenceArray.append(floatVec[Int(thin)])
        }
        var tempCount = 0
        for boundingBox in tempFilteredResults {
            let boundingBoxRect = self.calculateBoundBoxRect(boundingBox: boundingBox, previewHeight: previewSize.height, previewWidth: previewSize.width)
            let cropRect = self.calculateCropingRect(boundingBox: boundingBox, previewHeight: previewSize.height, previewWidth: previewSize.width)
            let croppedBar = self.resizedBufferImage?.cropImage(frame: cropRect) ?? UIImage()
            let inference = Inference(confidence: tempConfidenceArray[tempCount],
                                      className: "tire",
                                      rect: cropRect, boundingRect: boundingBoxRect,
                                      displayColor: UIColor.red, outputImage: croppedBar,previewWidth: width,previewHeight: height)
            tempCount += 1
            resultsArray.append(inference)
        }

        return resultsArray
    }

    
     func calculateCropingRect(boundingBox: BoundingBox,  previewHeight: CGFloat, previewWidth: CGFloat) -> CGRect {
        
        var rect: CGRect = CGRect.zero
        rect.origin.x = CGFloat(boundingBox.xPosition)
        rect.origin.y = CGFloat(boundingBox.yPosition)
        rect.size.width = CGFloat(boundingBox.width)
        rect.size.height = CGFloat(boundingBox.height)

        let x = rect.origin.x/inputWidth
        let y = rect.origin.y/inputHeight
        let w = rect.size.width/inputWidth
        let h = rect.size.height/inputHeight

        let img = resizedBufferImage

        let image_h = previewHeight
        let image_w = previewWidth

        let orig_x       = x * image_w
        let orig_y       = y * image_h
        let orig_width   = w * image_w
        let orig_height  = h * image_h

        let x1 = orig_x + orig_width / 2
        let y1 = orig_y + orig_height / 2
        let x2 = orig_x - orig_width / 2
        let y2 = orig_y - orig_height / 2


        //        let finalRect = CGRect(x: (rec.origin.x * ratioWidth) - 25 , y: (rec.origin.y * ratioHeight) - 25, width: (rec.size.width * ratioWidth) + 50  , height: (rec.size.height * ratioHeight) + 50)


        var xMinValue = CGFloat(min(x1, x2))
        var yMinValue = CGFloat(min(y1, y2))

       
        let finalRect = CGRect(
            x: xMinValue,
            y: yMinValue,
            width: CGFloat(abs(x1 - x2)),
            height: CGFloat(abs(y1 - y2)))
        

        return finalRect
//        return .zero
    }

    
    private func calculateBoundBoxRect(boundingBox: BoundingBox, previewHeight: CGFloat, previewWidth: CGFloat) -> CGRect {
        
        var rect: CGRect = CGRect.zero
        rect.origin.x = CGFloat(boundingBox.xPosition)
        rect.origin.y = CGFloat(boundingBox.yPosition)
        rect.size.width = CGFloat(boundingBox.width)
        rect.size.height = CGFloat(boundingBox.height)

        let x = rect.origin.x/inputWidth
        let y = rect.origin.y/inputHeight
        let w = rect.size.width/inputWidth
        let h = rect.size.height/inputHeight

        //let img = resizedBufferImage

        let image_h = previewHeight
        let image_w = previewWidth

        let orig_x       = x * image_w
        let orig_y       = y * image_h
        let orig_width   = w * image_w
        let orig_height  = h * image_h

        let x1 = orig_x + orig_width / 2
        let y1 = orig_y + orig_height / 2
        let x2 = orig_x - orig_width / 2
        let y2 = orig_y - orig_height / 2


        let finalRec = CGRect(
            x: CGFloat(min(x1, x2)),
            y: CGFloat(min(y1, y2)),
            width: CGFloat(abs(x1 - x2)),
            height: CGFloat(abs(y1 - y2)))

        return finalRec
    }

    
    //MARK: EFFICIENT RELATED FUNCTIONS
    func initializeEffi() {
        self.threadCount = 1
        let bundle = Bundle(for: type(of: self))

        // Specify the options for the `Interpreter`.
        var options = Interpreter.Options()
        options.threadCount = threadCount
        do {
            let litePath = bundle.path(forResource: "cls", ofType: "tflite")

            // Create the `Interpreter`.
            effiInterpreter = try Interpreter(modelPath: litePath!, options: options)
            // Allocate memory for the model's input `Tensor`s.
            try effiInterpreter?.allocateTensors()
        } catch let error {
            print(error)
            return
        }
        loadLabels(fileInfo: Effici.labelsInfo)
    }
    
    @objc(startCaptureData)
    public func startCaptureData() {
        inProgress = false
        if scannerType == .tire {
            tireResult?.removeAll()
            self.startCapture = true

            DispatchQueue.global().asyncAfter(deadline: .now() + 5, execute: {
                self.startCapture = false
                DispatchQueue.main.async {
                    self.draw(objectOverlays: [])
                }
                self.stopCaptureData()
            })

        } else if scannerType == .dotTire {
            self.startCapture = true
            tireResult?.removeAll()

            DispatchQueue.global().asyncAfter(deadline: .now() + 5, execute: {
                self.startCapture = false
                DispatchQueue.main.async {
                    self.draw(objectOverlays: [])
                }
                self.stopCaptureData()
            })
        } else{
            containerResult = [:]
            self.startCapture = true
            DispatchQueue.global().asyncAfter(deadline: .now() + 5, execute: {
                self.stopCaptureData()
            })
        }
    }
    
    private func stopCaptureData() {
        self.startCapture = false
        if scannerType == .tire  || scannerType == .dotTire {
            processTireResult()
            isFrameProcessing = false
        } else  {
            let sortresult = containerResult.sorted(by: { $0.value < $1.value })

            delegate?.capturedOutput(result: sortresult.last?.key ?? "", codeType: scannerType, results: nil, processedImage: resizedBufferImage ?? UIImage(), location: currentCoordinates)
            isFrameProcessing = false
        }
    }
    
    private func loadLabels(fileInfo: FileInfo) {
      let filename = fileInfo.name
      let fileExtension = fileInfo.extension
      let bundle = Bundle(for: type(of: self))

      guard let fileURL = bundle.url(forResource: filename, withExtension: fileExtension) else {
        fatalError("Labels file not found in bundle. Please add a labels file with name " +
                       "\(filename).\(fileExtension) and try again.")
      }
      do {
        let contents = try String(contentsOf: fileURL)
          labels = contents.components(separatedBy: "\n")
      } catch {
        fatalError("Labels file named \(filename).\(fileExtension) cannot be read. Please add a " +
                     "valid labels file and try again.")
      }
    }
    
    
    func runEffientedModel(onFrame pixelBuffer: CVPixelBuffer,  previewSize: CGSize, infernce: Inference  ) -> [String: Float] {
        
        originalBufferImage = pixelBuffer.toImage()
        //        processingImage.image = pixelBuffer.toImage()
        //UIImageWriteToSavedPhotosAlbum(originalBufferImage!, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
        
        let imageWidth = CVPixelBufferGetWidth(pixelBuffer)
        let imageHeight = CVPixelBufferGetHeight(pixelBuffer)
        let sourcePixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        assert(sourcePixelFormat == kCVPixelFormatType_32ARGB ||
               sourcePixelFormat == kCVPixelFormatType_32BGRA ||
               sourcePixelFormat == kCVPixelFormatType_32RGBA)
        
        
        let imageChannels = 4
        
        assert(imageChannels >= 3)
        
        
        // Crops the image to the biggest square in the center and scales it down to model dimensions.
        
        
        let scaledSize = CGSize(width: efficientInputWidth, height: efficientInputHeight)
        
        guard let scaledPixelBuffer = pixelBuffer.resized(to: scaledSize) else {
            return [:]
        }
        
        ///Test results
        
        
        let detectedBoxPosition: Tensor
        let confidenceLevelOfDetectedBox: Tensor
        do {
            
            
            let inputTensor = try effiInterpreter?.input(at: 0)
            
            
            // Remove the alpha component from the image buffer to get the RGB data.
            guard let rgbData = rgbDataFromBuffer(
                scaledPixelBuffer,
                byteCount: 1 * Int(efficientInputWidth) * Int(efficientInputHeight) * 3,
                isModelQuantized: inputTensor?.dataType == .uInt8
            ) else {
                return [:]
            }
            
            
            // Copy the RGB data to the input `Tensor`.
            try effiInterpreter?.copy(rgbData, toInputAt: 0)
            
            // Run inference by invoking the `Interpreter`.
            try effiInterpreter?.invoke()
            detectedBoxPosition = try effiInterpreter?.output(at: 0) as! Tensor // POSTION OF DETECTEDBOX
            confidenceLevelOfDetectedBox = try effiInterpreter?.output(at: 0) as! Tensor // CONFIDANCELEVEL OF DETECTED BOUNDING
                        
        } catch let error {
            print(error)
            return[:]
        }
        
        let outputcount: Int = detectedBoxPosition.shape.dimensions[1]
        let boundingPositions = [UInt8](unsafeData: detectedBoxPosition.data)!
        let confidenceLevel = [UInt8](unsafeData: confidenceLevelOfDetectedBox.data)!
        let sucess = formatResultsEfficient(boundingBox: infernce.boundingRect, outputClasses: confidenceLevel, outputCount: outputcount, width: CGFloat(imageWidth), height: CGFloat(imageHeight), previewSize: previewSize, processingData:  infernce)
        if let detectedData = sucess.decodedValue {
            if detectedData != "Boundary" && detectedData != "Colon" && detectedData != "f-slash" && detectedData != "hyphen" {
                return [detectedData: sucess.confidence]
            }
        }
        return [:]
    }


    func formatResultsEfficient(boundingBox: CGRect, outputClasses: [UInt8],
                       outputCount: Int, width: CGFloat,
                                height: CGFloat, previewSize: CGSize, processingData: Inference) -> Inference {
        var temp = processingData
        
        let filteredBoundingBox = outputClasses.firstIndex(of: outputClasses.max() ?? 0)
        let anbu = labels[filteredBoundingBox ?? 0]
        temp.decodedValue  = anbu
        return temp
    }

    private func processTireScanning(originalframe: CVPixelBuffer, croppedFrame: CVPixelBuffer) {
        var imagePixelBuffer = croppedFrame
        resizedBufferImage = croppedFrame.toImage()
        originalBufferImage = originalframe.toImage()
        if ((SFManager.shared.currentFrameBrightness ?? 0) < 4) {
            imagePixelBuffer = imagePixelBuffer.setBrightnessContrastAndroidOpencv()
            resizedBufferImage = imagePixelBuffer.toImage()
        }
        if let detectedResult = runModel(onFrame: imagePixelBuffer, previewSize: resizedBufferImage?.size ?? .zero) {
            let inferenceData = detectedResult.inferences
            var tempInfer:[Inference] = []
            let infernceToBeSort = inferenceData.sorted(by: {$0.rect.origin.x < $1.rect.origin.x})

            for inference in infernceToBeSort {
                tempInfer.append(inference)
            }
            resultArray.removeAll()
            var restultValues : [Float] = []
            var tempResultSort: [String]  = []
            for detectedOne in tempInfer {
                let image = detectedOne.outputImage
                let pixBuff = image.toPixelBuffer()

                let result = runEffientedModel(onFrame: pixBuff, previewSize: .zero, infernce: detectedOne)
                if let resultString = result.keys.first, let resultConfidence = result.values.first {
                    tempResultSort.append(resultString)
                    restultValues.append(resultConfidence)
                }
            }
            var overAllConfidence: Float = 0
            _ = restultValues.map({ confi in
                overAllConfidence += confi
            })
            overAllConfidence = overAllConfidence / Float(restultValues.count)
            finalResult = "\(tempResultSort.joined(separator: "")), \(overAllConfidence)"

            tireResult?.append(finalResult)

            if let currentConfi = Float(finalResult.split(separator: ",").last?.trimmingCharacters(in: .whitespaces) ?? "0"), let preConfi = currentConfidenceLevel {
                if currentConfi > preConfi {
                    self.sortedTireResult = croppedFrame.toImage()
                }
            }

            self.currentConfidenceLevel = Float(finalResult.split(separator: ",").last?.trimmingCharacters(in: .whitespaces) ?? "0")
            if sortedTireResult == nil {
                self.sortedTireResult = croppedFrame.toImage()
            }

            let actualFrame = outterWhiteRectView.frame.size

            let croppedFrameThing = croppedFrame.toImage().size



            let widthRatio:Double = croppedFrameThing.width / actualFrame.width // cropframe * viewon screen

            let heightRatio:Double = croppedFrameThing.height / actualFrame.height // cropframe * viewon screen



            var objectOverlays: [ObjectOverlay] = []


            var boudingRectData:[CGRect] = []

            for detectedOne in tempInfer {

                let boudingRect = detectedOne.boundingRect // 1080*1920 _> crop 810 * 220



                let temp = CGRect(x: (boudingRect.minX / widthRatio), y: (boudingRect.minY / heightRatio), width: (boudingRect.width / widthRatio), height: (boudingRect.height / heightRatio))



                boudingRectData.append(temp)



                let previewRect = CGRect(x: (temp.minX + outterWhiteRectView.frame.minX), y: (temp.minY + outterWhiteRectView.frame.minY), width: temp.width, height: temp.height)


                let objectOverlay = ObjectOverlay(name: "",

                                                  borderRect: previewRect,

                                                  nameStringSize: .zero,

                                                  color: .bottomLeftArrowColor,

                                                  font: .systemFont(ofSize: 10))

                objectOverlays.append(objectOverlay)

            }

            DispatchQueue.main.async {
                if self.startCapture == true {
                    self.draw(objectOverlays: objectOverlays)
                    self.inProgress = false
                }

            }

        }
        
    }


     func processModelResult(data: Result?) {

        guard let inferenceData = data?.inferences else { return }
        var tempInfer:[Inference] = []
         print( " before sort\(inferenceData.map({$0.boundingRect.origin.x}))")
        let infernceToBeSort = inferenceData.sorted(by: {$0.rect.origin.x < $1.rect.origin.x})
         print("after sort\(infernceToBeSort.map({$0.boundingRect.origin.x}))")

        //calculate distance thresshold
        var distanceThreshold = 0
        for i in 1...inferenceData.count-1 {
            distanceThreshold += Int(inferenceData[i].rect.minX - inferenceData[i-1].rect.maxX)
        }
        distanceThreshold = distanceThreshold/inferenceData.count

        var groupedValues: [[Inference]] = [[]]

        var tempGroup:[Inference] = []

        for i in 1...inferenceData.count-1  {
             var eachDistance = Int(inferenceData[i-1].rect.maxX - inferenceData[i].rect.minX)
            if eachDistance < distanceThreshold - 2 {
                tempGroup.append(inferenceData[i-1])
            } else {
                tempGroup.append(inferenceData[i-1])
                groupedValues.append(tempGroup)
                tempGroup.removeAll()
            }
        }

        tempGroup.append(inferenceData.last!)
        print(" groupedValues - \(tempGroup)")
        groupedValues.append(tempGroup)
        tempGroup.removeAll()
        var tempResultSort: [String]  = []
        for groups in groupedValues {

            for infer in groups {
                let image = infer.outputImage
                let pixBuff = image.toPixelBuffer()
                let result = runEffientedModel(onFrame: pixBuff, previewSize: .zero, infernce: infer)
                if let resultString = result.keys.first, let resultConfidence = result.values.first {
                    tempResultSort.append(resultString)
                }
            }
            tempResultSort.append(" ")
        }
        let singleString = tempResultSort.joined(separator: "")
        print("singleString - \(singleString)")
        let a = TireProcessing.shared.dotPostProcessing(tyreDataOrginal: singleString)
        
    }

    private func processTireResult() {
        if let result = tireResult?.map({return (($0.description.split(separator: ",").first?.description) ?? "")}), let confident = tireResult?.map({return (($0.description.split(separator: ",").last?.description))}) {
            let resultCounts = result.map({$0.description.count})
            let resultFilterByMaxCount = result.filter({$0.description.count == resultCounts.max()})
            let confi = result.enumerated().filter({$0.element.description.count == resultCounts.max()}).map({return (confident[$0.offset] ?? "0")})
            if resultFilterByMaxCount.count == 1 {
                if resultFilterByMaxCount.first != " nan" {
                    SFManager.shared.uploadFailedImagesToS3(sortedTireResult ?? UIImage(), CodeInfo())
                    delegate?.capturedOutput(result: resultFilterByMaxCount.first ?? "", codeType: scannerType, results: nil, processedImage: sortedTireResult, location: currentCoordinates)
                } else {
                    SFManager.shared.uploadFailedImagesToS3(sortedTireResult ?? UIImage(), CodeInfo())
                    delegate?.capturedOutput(result: "", codeType: scannerType, results: nil, processedImage: nil, location: currentCoordinates)
                }
            }  else {
                if let maxValue = confi.max() {
                    if let resultIndex = confi.firstIndex(of: maxValue)  {
                        let result = resultFilterByMaxCount[resultIndex]
                        if result != " nan" {

                            SFManager.shared.uploadFailedImagesToS3(sortedTireResult ?? UIImage(), CodeInfo())
                            delegate?.capturedOutput(result: result , codeType: scannerType, results: nil, processedImage: sortedTireResult, location: currentCoordinates)

                        } else {
                            SFManager.shared.uploadFailedImagesToS3(sortedTireResult ?? UIImage(), CodeInfo())
                         delegate?.capturedOutput(result: "", codeType: scannerType, results: nil, processedImage: nil, location: currentCoordinates)
                        }
                    }
                }
            }
        }
    }
    
}


extension ScanflowTextManager : CaptureDelegate {
   
    public func readData(originalframe: CVPixelBuffer, croppedFrame: CVPixelBuffer) {

        if startCapture == true {
            sortedTireResult = croppedFrame.toImage()
            if inProgress == false {
                inProgress = true

                if scannerType == .tire {
                    print("frame send - \(self.getCurrentMillis())")
                    processTireScanning(originalframe: originalframe, croppedFrame: croppedFrame)
                    
                } else if scannerType == .dotTire {
                    containerRunModelForTire(onFrame: croppedFrame, previewSize: previewViewSize)
                } else  {
                    containerRunModel(onFrame: croppedFrame, previewSize: previewViewSize)
                }
            }
        }
    }
    
}


