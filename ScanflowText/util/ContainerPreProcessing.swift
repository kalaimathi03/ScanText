//
//  ContainerPreProcessing.swift
//  ScanflowText
//
//  Created by Mac-OBS-46 on 09/03/23.
//

import Foundation
import ScanflowCore
import opencv2

class ContainerPreProcessing: NSObject {
    
    static public let shared = ContainerPreProcessing()

    func imagePreProcessing(_ img: Mat) -> Mat {
         var new_shape = [416, 416]
         var color = [114, 114, 114]
         var auto = true
         var scaleFill = false
         var scaleup = true
         let stride = 32
         
         // Resize and pad image while meeting stride-multiple constraints
        var shape = [img.rows(), img.cols()]
         if new_shape.count == 1 {
             
             new_shape = [new_shape[0], new_shape[1]]
         }
        
         // Scale ratio (new / old)
        var r = min(Double(new_shape[0]) / Double(shape[0]), Double(new_shape[1]) / Double(shape[1]))
        
         if !scaleup { // only scale down, do not scale up (for better test mAP)
             r = min(r, 1.0)
         }
         
         // Compute padding
         var ratio = [r, r] // width, height ratios
        
        var new_unpad = [Int(round(Double(shape[1]) * r)), Int(round(Double(shape[0]) * r))]
         var dw = new_shape[1] - new_unpad[0]
         var dh = new_shape[0] - new_unpad[1] // wh padding
         
         if auto { // minimum rectangle
             dw = dw % stride
             dh = dh % stride
         } else if scaleFill { // stretch
             dw = 0
             dh = 0
             new_unpad = [new_shape[1], new_shape[0]]
             ratio = [Double(new_shape[1]) / Double(shape[1]), Double(new_shape[0]) / Double(shape[0])] // width, height ratios
         }
         
         dw /= 2 // divide padding into 2 sides
         dh /= 2
         
        if shape[1] != new_unpad[0] || shape[0] != new_unpad[1] { // resize
            Imgproc.resize(src: img, dst: img, dsize: Size(width: Int32(new_unpad[0]), height: Int32(new_unpad[1])), fx: 0, fy: 0, interpolation: InterpolationFlags.INTER_LINEAR.rawValue)
        }
         
         let top = Int(round(Double(dh) - 0.1))
         let bottom = Int(round(Double(dh) + 0.1))
         let left = Int(round(Double(dw) - 0.1))
         let right = Int(round(Double(dw) + 0.1))
         
        Core.copyMakeBorder(src: img, dst: img, top: Int32(top), bottom: Int32(bottom), left: Int32(left), right: Int32(right), borderType: .BORDER_ISOLATED, value: Scalar(Double(color[0]), Double(color[1]), Double(color[2]), 1.0)) // add border

         return img
     }
}
