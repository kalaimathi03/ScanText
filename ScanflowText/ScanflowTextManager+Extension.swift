//
//  ScanflowTextManager+Extension.swift
//  ScanflowText
//
//  Created by Mac-OBS-46 on 23/12/22.
//

import Foundation
import ScanflowCore
import UIKit
import CoreVideo
import CoreMedia
import Accelerate
import opencv2

enum ContainerEffici {
  static let modelInfo: FileInfo = (name: "Container-effnet-06-03-2023", extension: "tflite")
  static let labelsInfo: FileInfo = (name: "Container-effnet-06-03-2023", extension: "txt")
}

struct ContainerBoundingBox {
    var batch_id: Float
    var xPosition: Float
    var yPosition: Float
    var width: Float
    var height: Float
    var cls_id: Float
    var score: Float
    
}

extension ScanflowTextManager {
    
    func initContainerModel() {
        debugPrint("model initiated")
        setupContainerModelFiles(modelType: .classificationModel)
        setupContainerModelFiles(modelType: .detectionModel)
        initializeContainerYolo()
        initContainerEffiModel()
    }
    
    func initContainerEffiModel() {
        self.threadCount = 1

        // Specify the options for the `Interpreter`.
        var options = Interpreter.Options()
        options.threadCount = threadCount
        do {
            // Create the `Interpreter`.
            effiInterpreter = try Interpreter(modelPath: classificationModelPath!, options: options)
            // Allocate memory for the model's input `Tensor`s.
            try effiInterpreter?.allocateTensors()
        } catch let error {
            print(error)
            return
        }
        loadLabels(fileInfo: ContainerEffici.labelsInfo)
    }
    
   
    
    func initializeContainerYolo() {
        self.threadCount = 1
        
        // Specify the options for the `Interpreter`.
        var options = Interpreter.Options()
        options.threadCount = threadCount
        do {
            // Create the `Interpreter`.
            interpreter = try Interpreter(modelPath: dectectionModelPath!, options: options)
            // Allocate memory for the model's input `Tensor`s.
            try interpreter?.allocateTensors()
            print("model loaded")
        } catch let error {
            print(error)
            return
        }
    }
    
    
    #warning("have to check and change this")
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
    
    func resizeImage(image: UIImage, targetSize: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resizedImage
    }

    
    func convertMatToUIImage(mat: Mat) -> UIImage {
        return UIImage(cgImage: mat.toCGImage())
    }

    func containerRunModelForTire(onFrame pixelBuffer: CVPixelBuffer, previewSize: CGSize) {
        debugPrint("Pre processing impage initiated \(SFManager.shared.getCurrentMillis())")
        resizedBufferImage = pixelBuffer.toImage()
        var processedImage:UIImage = UIImage()
            let matImage = Mat(uiImage: resizedBufferImage ?? UIImage())
            let preProcessedMat = ContainerPreProcessing.shared.imagePreProcessing(matImage)
            let preProcessedImage = convertMatToUIImage(mat: preProcessedMat)
            let imgView = UIImageView(image: preProcessedImage)
            let viewDataa = UIView(frame: CGRect(origin: .zero, size: CGSize(width: 416, height: 416)))
            viewDataa.backgroundColor = UIColor(red: 114 / 255.0, green: 114 / 255.0, blue: 114 / 255.0, alpha: 1.0)
            imgView.center = viewDataa.center
            viewDataa.addSubview(imgView)
            processedImage = UIImage(view: viewDataa)
        debugPrint("Pre processing impage completed \(SFManager.shared.getCurrentMillis())")
        debugPrint("container model initiated \(SFManager.shared.getCurrentMillis())")
        var infer: [Inference] = []

        let imageChannels = 4
        assert(imageChannels >= inputChannels)

        do {

            //DKManager.shared.print(message: "MODEL STARTED", function: .runModel)
            let inputTensor = try interpreter?.input(at: 0)

            //DKManager.shared.print(message: "BEFORE RGB RESIZE", function: .runModel)
            // Remove the alpha component from the image buffer to get the RGB data.
            debugPrint("rgbDataFromBuffer initaiated \(SFManager.shared.getCurrentMillis())")
            guard let rgbData = containerRgbDataFromBuffer(
                (processedImage.toPixelBuffer()),
                byteCount: 1 * Int(416) * Int(416) * 3,
                isModelQuantized: inputTensor?.dataType == .uInt8
            ) else {
                //DKManager.shared.print(message: "Failed to convert the image buffer to RGB data.", function: .runModel)
                debugPrint("rgbDataFromBuffer issue")
                return
            }
            debugPrint("rgbDataFromBuffer completed \(SFManager.shared.getCurrentMillis())")
           // DKManager.shared.print(message: "AFTER RGB SIZE", function: .runModel)

            // Copy the RGB data to the input `Tensor`.
            try interpreter?.copy(rgbData, toInputAt: 0)
            // Run inference by invoking the `Interpreter`.
            try interpreter?.invoke()

            let outputResult = try interpreter?.output(at: 0)

            let outputs = ([Float](unsafeData: outputResult?.data ?? Data()) ?? []) as [NSNumber]
            let nmsPredictions = PrePostProcessor.outputsToNMSPredictions(outputs: outputs, imageWidth: processedImage.size.width, imageHeight: processedImage.size.height)
            var objectOverlays: [ObjectOverlay] = []
            var boudingRectData:[CGRect] = []
            var restultValues : [Float] = []
            var tempResultSort: [String]  = []

            let widthRatio:Double = 1
            let heightRatio:Double = processedImage.size.height / imgView.frame.height // cropframe * viewon screen


            var maxHeight: CGFloat = 0
            var maxWidth: CGFloat = 0
            var calculatedBounds: [CGRect] = []
            for prediction in nmsPredictions {
                let pred = Inference(confidence: prediction.score, className: "", rect: prediction.rect, boundingRect: prediction.rect, displayColor: .red, outputImage: processedImage.cropImage(frame: prediction.rect), previewWidth: previewSize.width, previewHeight: previewSize.height)

                let boudingRect = pred.boundingRect

                let temp = CGRect(x: (boudingRect.minX / widthRatio), y: (boudingRect.minY / heightRatio), width: (boudingRect.width), height: (boudingRect.height))
                print("temp=>\(temp)")
                let dWidthRatio = outterWhiteRectView.frame.width / preProcessedImage.size.width
                let dHeightRatio = outterWhiteRectView.frame.height / preProcessedImage.size.height

                let previewRect = CGRect(x: (temp.minX * dWidthRatio), y: (temp.minY * dHeightRatio), width: (temp.width), height: (temp.height))
                print("previewRect=>\(previewRect)")
                let finalTouch = CGRect(x: (previewRect.minX + outterWhiteRectView.frame.minX), y: (previewRect.minY + outterWhiteRectView.frame.minY - 10), width: previewRect.width, height: previewRect.height)
                print("finalTouch=>\(finalTouch)")
                let objectOverlay = ObjectOverlay(name: "",
                                                  borderRect: finalTouch,
                                                  nameStringSize: .zero,
                                                  color: .bottomLeftArrowColor,
                                                  font: .systemFont(ofSize: 10))
                objectOverlays.append(objectOverlay)
                if maxHeight < objectOverlay.borderRect.height {
                    maxHeight = objectOverlay.borderRect.height
                }
                infer.append(pred)

            }
            print("processModelResult(data: Result(inferences: infer))")
            processModelResult(data: Result(inferences: infer))

            DispatchQueue.main.async {
                if self.startCapture == true {
                    self.draw(objectOverlays: objectOverlays)
                    self.inProgress = false
                }
            }
        } catch let error {
            //DKManager.shared.print(message: "Failed to invoke the interpreter with error: \(error.localizedDescription)", function: .runModel)
            print(error.localizedDescription)
            debugPrint("resut error: \(error.localizedDescription)")
        }

        var result = horizantalGroupingForTire(infer: infer)
        for prediction in predictionArray {

            if let range = result.range(of: prediction) {
                let testString2 = result.replacingCharacters(in: range,
                                                                 with: "DOT")
                print("Changed result - \(testString2) => \(result)")
                result = testString2

                break
            }

        }

        if let rangeOpenCurl = result.range(of: "DOT") {
            result.removeSubrange(result.startIndex..<rangeOpenCurl.lowerBound)
        }

        if let currentConfi = Float(result.split(separator: ",").last?.trimmingCharacters(in: .whitespaces) ?? "0"), let preConfi = currentConfidenceLevel {
            if currentConfi > preConfi {
                self.sortedTireResult = pixelBuffer.toImage()
            }
        }

        self.currentConfidenceLevel = Float(result.split(separator: ",").last?.trimmingCharacters(in: .whitespaces) ?? "0")
print("tireResult: \(result)")
        tireResult?.append(result)

    }

    func containerRunModel(onFrame pixelBuffer: CVPixelBuffer, previewSize: CGSize) {
        debugPrint("Pre processing impage initiated \(SFManager.shared.getCurrentMillis())")
        resizedBufferImage = pixelBuffer.toImage()
        var processedImage:UIImage = UIImage()
            let matImage = Mat(uiImage: resizedBufferImage ?? UIImage())
            let preProcessedMat = ContainerPreProcessing.shared.imagePreProcessing(matImage)
            let preProcessedImage = convertMatToUIImage(mat: preProcessedMat)
            let imgView = UIImageView(image: preProcessedImage)
            let viewDataa = UIView(frame: CGRect(origin: .zero, size: CGSize(width: 416, height: 416)))
            viewDataa.backgroundColor = UIColor(red: 114 / 255.0, green: 114 / 255.0, blue: 114 / 255.0, alpha: 1.0)
            imgView.center = viewDataa.center
            viewDataa.addSubview(imgView)
            processedImage = UIImage(view: viewDataa)
        debugPrint("Pre processing impage completed \(SFManager.shared.getCurrentMillis())")
        debugPrint("container model initiated \(SFManager.shared.getCurrentMillis())")
        var infer: [Inference] = []

        let imageChannels = 4
        assert(imageChannels >= inputChannels)
        
        do {
            
            //DKManager.shared.print(message: "MODEL STARTED", function: .runModel)
            let inputTensor = try interpreter?.input(at: 0)
            
            //DKManager.shared.print(message: "BEFORE RGB RESIZE", function: .runModel)
            // Remove the alpha component from the image buffer to get the RGB data.
            debugPrint("rgbDataFromBuffer initaiated \(SFManager.shared.getCurrentMillis())")
            guard let rgbData = containerRgbDataFromBuffer(
                (processedImage.toPixelBuffer()),
                byteCount: 1 * Int(416) * Int(416) * 3,
                isModelQuantized: inputTensor?.dataType == .uInt8
            ) else {
                //DKManager.shared.print(message: "Failed to convert the image buffer to RGB data.", function: .runModel)
                debugPrint("rgbDataFromBuffer issue")
                return
            }
            debugPrint("rgbDataFromBuffer completed \(SFManager.shared.getCurrentMillis())")
           // DKManager.shared.print(message: "AFTER RGB SIZE", function: .runModel)
            
            // Copy the RGB data to the input `Tensor`.
            try interpreter?.copy(rgbData, toInputAt: 0)
            // Run inference by invoking the `Interpreter`.
            try interpreter?.invoke()
            
            let outputResult = try interpreter?.output(at: 0)
            
            let outputs = ([Float](unsafeData: outputResult?.data ?? Data()) ?? []) as [NSNumber]
            let nmsPredictions = PrePostProcessor.outputsToNMSPredictions(outputs: outputs, imageWidth: processedImage.size.width, imageHeight: processedImage.size.height)
            
            for prediction in nmsPredictions {
                let pred = Inference(confidence: prediction.score, className: "", rect: prediction.rect, boundingRect: prediction.rect, displayColor: .red, outputImage: processedImage.cropImage(frame: prediction.rect), previewWidth: previewSize.width, previewHeight: previewSize.height)
                infer.append(pred)

            }
            
            
        } catch let error {
            //DKManager.shared.print(message: "Failed to invoke the interpreter with error: \(error.localizedDescription)", function: .runModel)
            print(error.localizedDescription)
            debugPrint("resut error: \(error.localizedDescription)")
        }
        
        debugPrint("container model completed: \(SFManager.shared.getCurrentMillis())")
        if scannerType == .containerHorizontal {
            horizantalGrouping(infer: infer)
        } else {
            verticalGrouping(infer: infer)
        }
        
        let resultCount = containerResult.keys.map( { $0.description.count } )
        
        let finalResult = containerResult.filter({$0.key.description.count == resultCount.max()})
        inProgress = false
        containerResult = finalResult
        
    }
    
    func horizantalGrouping(infer: [Inference]) {
        let temp1 = infer.sorted(by: { $0.rect.origin.y < $1.rect.origin.y })
        var ref:Int = 0
        let refThreshold: CGFloat = temp1.first?.boundingRect.maxY ?? 0
        var firstGroup: [Inference] = temp1.filter({ $0.boundingRect.minY < refThreshold })
        var secondGroup: [Inference] = temp1.filter({ $0.boundingRect.minY > refThreshold })
        
        var temp:[Inference] = firstGroup
        var confidentScore:Float = 0
        var resultData:String = ""
        firstGroup = temp.sorted(by: { $0.rect.origin.x < $1.rect.origin.x } )
        debugPrint("grouping completed: \(SFManager.shared.getCurrentMillis())")
        for process in firstGroup {
            let temp = runContainerEffientedModel(onFrame: process.outputImage.toPixelBuffer(), previewSize: previewViewSize, infernce: process)
            resultData += temp.first!.key
            print(temp.first!.key)
            confidentScore = confidentScore + temp.first!.value
        }
        temp = secondGroup
        secondGroup = temp.sorted(by: { $0.rect.origin.x < $1.rect.origin.x } )
        for process in secondGroup {
            let temp = runContainerEffientedModel(onFrame: process.outputImage.toPixelBuffer(), previewSize: previewViewSize, infernce: process)
            resultData += temp.first!.key
            print(temp.first!.key)
            confidentScore = confidentScore + temp.first!.value
        }
        print("\(resultData) => \(confidentScore)")
        let postProcessResult = ContainerResultPostProcessing.shared.postProcessingResult(containerResult: resultData)
        
        print("\(postProcessResult) => \(confidentScore)")
        if postProcessResult != "" {
            containerResult[postProcessResult] = confidentScore
        }
        print(containerResult)

    }
    func horizantalGroupingForTire(infer: [Inference]) -> String {
        let temp1 = infer.sorted(by: { $0.rect.origin.y < $1.rect.origin.y })
        var ref:Int = 0

        let refThreshold: CGFloat = temp1.first?.boundingRect.maxY ?? 0

        var firstGroup: [Inference] = temp1.filter({ $0.boundingRect.minY < refThreshold })
        var secondGroup: [Inference] = temp1.filter({ $0.boundingRect.minY > refThreshold })

        var temp:[Inference] = firstGroup
        var confidentScore:Float = 0
        var resultData:String = ""
        firstGroup = temp.sorted(by: { $0.rect.origin.x < $1.rect.origin.x } )
        debugPrint("grouping completed: \(SFManager.shared.getCurrentMillis())")
        for process in firstGroup {
            let temp = runContainerEffientedModel(onFrame: process.outputImage.toPixelBuffer(), previewSize: previewViewSize, infernce: process)
            if temp.first!.key != "-" && temp.first!.key != "Boundary" && temp.first!.key != "COLON" {
                resultData += temp.first!.key
                print(temp.first!.key)
                confidentScore = confidentScore + temp.first!.value
            }
        }
        temp = secondGroup
        secondGroup = temp.sorted(by: { $0.rect.origin.x < $1.rect.origin.x } )
        for process in secondGroup {
            let temp = runContainerEffientedModel(onFrame: process.outputImage.toPixelBuffer(), previewSize: previewViewSize, infernce: process)
            if temp.first!.key != "-" && temp.first!.key != "Boundary" && temp.first!.key != "COLON" {
                resultData += temp.first!.key
                print(temp.first!.key)
                confidentScore = confidentScore + temp.first!.value
            }
        }

        return ("\(resultData), \(confidentScore)")

    }
    
    func verticalGrouping(infer: [Inference]) {
      
        let temp1 = infer.sorted(by: { $0.rect.origin.x < $1.rect.origin.x })
        
        let refThreshold: CGFloat = temp1.first?.boundingRect.maxX ?? 0
        
        var firstGroup: [Inference] = temp1.filter({ $0.boundingRect.minX < refThreshold })
        var secondGroup: [Inference] = temp1.filter({ $0.boundingRect.minX > refThreshold })
        
        var temp:[Inference] = firstGroup
        var confidentScore:Float = 0
        var resultData:String = ""
        firstGroup = temp.sorted(by: { $0.rect.origin.y < $1.rect.origin.y } )
        debugPrint("grouping completed: \(SFManager.shared.getCurrentMillis())")
        debugPrint("efficient initiated: \(SFManager.shared.getCurrentMillis())")
        for process in firstGroup {
            let temp = runContainerEffientedModel(onFrame: process.outputImage.toPixelBuffer(), previewSize: previewViewSize, infernce: process)
            resultData += temp.first!.key
            confidentScore = confidentScore + temp.first!.value
            print("\(temp.first!.key) => \(temp.first!.value) ")
        }
        temp = secondGroup
        secondGroup = temp.sorted(by: { $0.rect.origin.y < $1.rect.origin.y } )
        for process in secondGroup {
            let temp = runContainerEffientedModel(onFrame: process.outputImage.toPixelBuffer(), previewSize: previewViewSize, infernce: process)
            resultData += temp.first!.key
            confidentScore = confidentScore + temp.first!.value
        }
        print("\(resultData) => \(confidentScore)")
        debugPrint("efficient completed: \(SFManager.shared.getCurrentMillis())")

        debugPrint("post processing initiated: \(SFManager.shared.getCurrentMillis())")
        let a = ContainerResultPostProcessing.shared.postProcessingResult(containerResult: resultData)
        debugPrint("post processing completed: \(SFManager.shared.getCurrentMillis())")
        containerResult[a] = confidentScore
        print(containerResult)
    }
    
    func setupContainerModelFiles(modelType: ModelType)  {
        var fullData = Data()
        for modelId in 1...12 {
            let bundle = Bundle(for: type(of: self))
            guard let litePath = bundle.path(forResource: "\(modelType == .classificationModel  ? "ContainerClassificationModel" : "ContainerDetectionModel")\(modelId)", ofType: "tflite") else {
                print("Failed to load the model file with name:")
                return
            }
            if let splitedData = try? Data(contentsOf: URL(fileURLWithPath: litePath)) {
                if modelId != 12 {
                    fullData.append(splitedData)
                } else {
                    
                    if modelType == .classificationModel {
                        if let lastData = decryptFile(key: "d5a423f64b607ea7c65b311d855dc48f36114b227bd0c7a3d403f6158a9e4412", nonce: "131348c0987c7eece60fc0bc", data: splitedData) {
                            fullData.append(lastData)
                        }
                    } else {
                        if let lastData = decryptFile(key: "d5a423f64b607ea7c65b311d855dc48f36114b227bd0c7a3d403f6158a9e4412", nonce: "131348c0987c7eece60fc0bc", data: splitedData) {
                            fullData.append(lastData)
                        }
                    }
                }
            }
            
        }
        createPath(fileName: "\(modelType == .classificationModel ? "Containercls" : "Containerdetec")", splitedData: fullData, modeltype: modelType)
    }
    
    func runContainerEffientedModel(onFrame pixelBuffer: CVPixelBuffer,  previewSize: CGSize, infernce: Inference  ) -> [String: Float] {
        
        originalBufferImage = pixelBuffer.toImage()
        let imageWidth = CVPixelBufferGetWidth(pixelBuffer)
        let imageHeight = CVPixelBufferGetHeight(pixelBuffer)
        let sourcePixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        assert(sourcePixelFormat == kCVPixelFormatType_32ARGB ||
               sourcePixelFormat == kCVPixelFormatType_32BGRA ||
               sourcePixelFormat == kCVPixelFormatType_32RGBA)
        
        
        let imageChannels = 4
        
        assert(imageChannels >= 3)
        
        let scaledSize = CGSize(width: efficientInputWidth, height: efficientInputHeight)
        
        guard let scaledPixelBuffer = pixelBuffer.resized(to: scaledSize) else {
            return [:]
        }
        
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
        let confidenceLevel = [UInt8](unsafeData: confidenceLevelOfDetectedBox.data)!
        let sucess = formatResultsEfficient(boundingBox: infernce.boundingRect, outputClasses: confidenceLevel, outputCount: outputcount, width: CGFloat(imageWidth), height: CGFloat(imageHeight), previewSize: previewSize, processingData:  infernce)
        if let detectedData = sucess.decodedValue {
            return [detectedData: sucess.confidence]
            
        }
        return [:]
    }
    
    func drawAfterPerformingCalculations(onInferences inferences: [Inference], withImageSize imageSize:CGSize) {

      self.overlayView.objectOverlays = []
      self.overlayView.setNeedsDisplay()

      guard !inferences.isEmpty else {
        return
      }

      var objectOverlays: [ObjectOverlay] = []

      for inference in inferences {

        // Translates bounding box rect to current view.
        var convertedRect = inference.rect.applying(CGAffineTransform(scaleX: self.overlayView.bounds.size.width / imageSize.width, y: self.overlayView.bounds.size.height / imageSize.height))

        if convertedRect.origin.x < 0 {
          convertedRect.origin.x = self.edgeOffset
        }

        if convertedRect.origin.y < 0 {
          convertedRect.origin.y = self.edgeOffset
        }

        if convertedRect.maxY > self.overlayView.bounds.maxY {
          convertedRect.size.height = self.overlayView.bounds.maxY - convertedRect.origin.y - self.edgeOffset
        }

        if convertedRect.maxX > self.overlayView.bounds.maxX {
          convertedRect.size.width = self.overlayView.bounds.maxX - convertedRect.origin.x - self.edgeOffset
        }

        let confidenceValue = Int(inference.confidence * 100.0)
        let string = "\(inference.className)  (\(confidenceValue)%)"

         //  let size = string.size(with: self.displayFont)

          
          let objectOverlay = ObjectOverlay(name: string, borderRect: convertedRect, nameStringSize: .zero, color: inference.displayColor, font: .systemFont(ofSize: 15))
        objectOverlays.append(objectOverlay)
      }

      // Hands off drawing to the OverlayView
      self.draw(objectOverlays: objectOverlays)

    }
    
    private func containerRgbDataFromBuffer(
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
            //SFManager.shared.print(message: "Error: out of memory", function: .rgbDataFromBuffer)
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
            floats.append((Float(bytes[byte])) / 255.0)
        }
        return Data(copyingBufferOf: floats)
    }
    
}
