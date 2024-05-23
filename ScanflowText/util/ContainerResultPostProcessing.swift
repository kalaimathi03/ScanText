//
//  ContainerResultPostProcessing.swift
//  ScanflowText
//
//  Created by Mac-OBS-46 on 02/03/23.
//

import Foundation


class ContainerResultPostProcessing : NSObject {
    
    static public let shared = ContainerResultPostProcessing()

    
    var regex_pattern_full = try! NSRegularExpression(pattern: "^[A-Z]{3}[U,J,Z][0-9]{6}[0-9]{1}(2|4|L|M)(2|5)(G|V|P|S|R|U|K|H|W|N|A|B)\\d$", options: [])
    var regex_pattern_half = try! NSRegularExpression(pattern: "^[A-Z]{3}[U,J,Z][0-9]{7}$", options: [])
    var regex_pattern_company = "[A-Z]{4}[0-9]{2}"
    var regex_pattern_weight = "(2|4|L|M)(2|5)(G|V|P|S|R|U|K|H|W|N|A|B)\\d"
    var regex_pattern_serial = try! NSRegularExpression(pattern: "^[0-9]{7}$", options: [])
    var pattern_full = try! NSRegularExpression(pattern: "[A-Z]{3}[U,J,Z][0-9]{6}[0-9]{1}(2|4|L|M)(2|5)(G|V|P|S|R|U|K|H|W|N|A|B)\\d", options: [])
    var pattern_half = try! NSRegularExpression(pattern: "[A-Z]{4}[0-9]{7}", options: [])
    
    
        
   
    func postProcessingResult(containerResult: String) -> String {
        debugPrint("👉🏼Regex started")
        if let result = regex_pattern_full.firstMatch(in: containerResult, range: NSRange(containerResult.startIndex..., in: containerResult)){
            debugPrint("👉🏼Return \(result)")
            let a = Range(result.range(at: 0), in: containerResult)
            return String(containerResult[Range(result.range(at: 0), in: containerResult)!])
        } else if let result = regex_pattern_half.firstMatch(in: containerResult, range: NSRange(containerResult.startIndex..., in: containerResult)) {
            if containerResult.count < 12 {
                debugPrint("👉🏼Return \(containerResult)")
                return String(containerResult[Range(result.range(at: 0), in: containerResult)!])
            } else {
                debugPrint("👉🏼nearestValueMatch \(containerResult)")
                return nearestValueMatch(containerResult: containerResult)
            }
        } else if containerResult.count == 11 || containerResult.count == 15 {
            let result = nearestValueMatch_full_half_pattern(containerResult: containerResult)
            return finalProcessOutput(result: result)
        } else {
            let nearMatch = nearestValueMatch(containerResult: containerResult)
            return finalProcessOutput(result: nearMatch)
        }
    }
    
    func refineContainerArray(containerValues: [String]) -> [String] {
        let pattern_company = try! NSRegularExpression(pattern: regex_pattern_company, options: [])
        let pattern_weight = try! NSRegularExpression(pattern: regex_pattern_weight, options: [])
        var companyMatch:String = ""
        var weightMatch:String = ""
        var refinedcontainerValues = [String]()
        for containerValue in containerValues {
            if containerValue.count > 3 {
                
                let matcher_company = pattern_company.firstMatch(in: containerValue, range: NSRange(containerValue.startIndex..., in: containerValue))
                let matcher_weight = pattern_weight.firstMatch(in: containerValue, range: NSRange(containerValue.startIndex..., in: containerValue))
                                         
                if let matcher_weight = pattern_weight.firstMatch(in: containerValue, range: NSRange(containerValue.startIndex..., in: containerValue)){
                    weightMatch = String(containerValue[Range(matcher_weight.range(at: 0), in: containerValue)!])
                }
                if let matcher_company = pattern_company.firstMatch(in: containerValue, range: NSRange(containerValue.startIndex..., in: containerValue)) {
                    companyMatch = String(containerValue[Range(matcher_company.range(at: 0), in: containerValue)!])
                }

                if containerValue.count > 7 && companyMatch.isEmpty == false && weightMatch.isEmpty == false {
                    refinedcontainerValues.append(String(containerValue[companyMatch.startIndex..<weightMatch.endIndex]))
                } else if containerValue.count > 7 && companyMatch.isEmpty == false {
                    refinedcontainerValues.append(String(containerValue[companyMatch.startIndex...]))
                } else if containerValue.count < 7 && weightMatch.isEmpty == false {
                    refinedcontainerValues.append(String(containerValue[weightMatch.startIndex..<weightMatch.endIndex]))
                } else {
                    refinedcontainerValues.append(containerValue)
                }
            }
        }
        return refinedcontainerValues
    }
    
    func finalProcessOutput(result: String) -> String{
        let removeSmallAlphabets = removeSmallAlphabets(fromString: result)
        let charRange: NSRange = NSRange(removeSmallAlphabets.startIndex..., in: removeSmallAlphabets)
        if let result = regex_pattern_full.firstMatch(in: removeSmallAlphabets, range: charRange) {
            return String(removeSmallAlphabets[Range(result.range(at: 0), in: removeSmallAlphabets)!])
        } else if let result = regex_pattern_half.firstMatch(in: removeSmallAlphabets, range: charRange) {
            return String(removeSmallAlphabets[Range(result.range(at: 0), in: removeSmallAlphabets)!])
        } else {
            return ""
        }
    }
    
    func nearestValueMatch(containerResult: String) -> String {
        var pattern_company = try! NSRegularExpression(pattern: regex_pattern_company, options: [])
        var pattern_weight = try! NSRegularExpression(pattern: regex_pattern_weight, options: [])
        
        let matcher_full = pattern_full.firstMatch(in: containerResult, range: NSRange(containerResult.startIndex..., in: containerResult))
        let matcher_half = pattern_half.firstMatch(in: containerResult, range: NSRange(containerResult.startIndex..., in: containerResult))
        let matcher_company = pattern_company.firstMatch(in: containerResult, range: NSRange(containerResult.startIndex..., in: containerResult))
        let matcher_weight = pattern_weight.firstMatch(in: containerResult, range: NSRange(containerResult.startIndex..., in: containerResult))

        
        debugPrint("👉🏼matcher_full \(matcher_full)")
        debugPrint("👉🏼matcher_half \(matcher_half)")
        debugPrint("👉🏼matcher_company \(matcher_company)")
        
        if let fullRange = matcher_full?.range {
            return String(containerResult[Range(fullRange, in: containerResult)!])
        } else if let halfRange = matcher_half?.range {
            return String(containerResult[Range(halfRange, in: containerResult)!])
        } else if let companyRange = matcher_company?.range {
            let companyName = String(containerResult[Range(companyRange, in: containerResult)!])
            var weightData = ""
            var expectedData = containerResult
            expectedData = expectedData.count > 15 ? String(expectedData.prefix(15)) : (expectedData.count > 11 && expectedData.count < 15 ? String(expectedData.prefix(11)) : expectedData)
            
            if let weightRange = matcher_weight?.range {
                weightData = String(containerResult[Range(weightRange, in: containerResult)!])
                expectedData = String(containerResult[Range(companyRange, in: containerResult)!.lowerBound..<Range(weightRange, in: containerResult)!.upperBound])
            }
            
            if expectedData.count == 11 || expectedData.count == 15 {
                return nearestValueMatch_full_half_pattern(containerResult: expectedData)
            } else {
                var serialNumber = String(expectedData[expectedData.index(after: expectedData.index(after: Range(companyRange, in: containerResult)!.upperBound))..<expectedData.endIndex]).replacingOccurrences(of: weightData, with: "")
                serialNumber = serialNumber
                    .replacingOccurrences(of: "O", with: "0")
                    .replacingOccurrences(of: "i", with: "1")
                    .replacingOccurrences(of: "I", with: "1")
                    .replacingOccurrences(of: "K", with: "5")
                    .replacingOccurrences(of: "G", with: "6")
                    .replacingOccurrences(of: "C", with: "5")
                    .replacingOccurrences(of: "L", with: "1")
                    .replacingOccurrences(of: "B", with: "8")
                    .replacingOccurrences(of: "g", with: "9")
                debugPrint("👉🏼serialNumber \(serialNumber)")
                debugPrint("👉🏼companyName + serialNumber \(companyName + serialNumber)")
                return companyName + serialNumber
            }
            
        } else {
            return containerResult
        }
        
    }

    func nearestValueMatch_full_half_pattern(containerResult: String) -> String {
        let pattern_company = try! NSRegularExpression(pattern: regex_pattern_company, options: [])
        let pattern_weight = try! NSRegularExpression(pattern: regex_pattern_weight, options: [])
        
        var companyName:String = String(containerResult.prefix(4))
        var serialNumber:String = String(containerResult.dropFirst(4).prefix(7))
        
        var weightCapacity:String = ""
        let matcher_weight: NSTextCheckingResult? = pattern_weight.firstMatch(in: containerResult, range: NSRange(containerResult.startIndex..., in: containerResult))

        if let match = matcher_weight {
            weightCapacity = String(containerResult[Range(match.range, in: containerResult)!])
            serialNumber = serialNumber.replacingOccurrences(of: weightCapacity, with: "")
        } else {
            weightCapacity = containerResult.count >= 15 ? String(containerResult.suffix(from: containerResult.index(containerResult.startIndex, offsetBy: 11))) : ""
        }
        debugPrint("👉🏼\(serialNumber)")
        debugPrint("👉🏼\(companyName)")
        debugPrint("👉🏼\(weightCapacity)")
        serialNumber = serialNumber
            .replacingOccurrences(of: "O", with: "0")
            .replacingOccurrences(of: "i", with: "1")
            .replacingOccurrences(of: "I", with: "1")
            .replacingOccurrences(of: "K", with: "5")
            .replacingOccurrences(of: "G", with: "6")
            .replacingOccurrences(of: "C", with: "5")
            .replacingOccurrences(of: "L", with: "1")
            .replacingOccurrences(of: "B", with: "8")
            .replacingOccurrences(of: "g", with: "9")
            .replacingOccurrences(of: "E", with: "5")
        debugPrint("👉🏼\(serialNumber)")

        if weightCapacity.count > 0 {
            if let match_weight = pattern_weight.firstMatch(in: containerResult, options: [], range: NSRange(containerResult.startIndex..., in: containerResult))?.range {
                
                let range = Range(match_weight, in: containerResult)!
                weightCapacity = String(containerResult[range])
                debugPrint("👉🏼).description weightCapacity\(weightCapacity)")
            } else {
                debugPrint("👉🏼se {weightCapacity\(weightCapacity)")
                weightCapacity = weightCapacity.replacingOccurrences(of: "Z", with: "2")
                    .replacingOccurrences(of: "D", with: "5")
                    .replacingOccurrences(of: "Z", with: "2")
                    .replacingOccurrences(of: "E", with: "5") //E → 5 or 3 based on the confidence score
                debugPrint("👉🏼5)) weightCapacity\(weightCapacity)")
                if let match_weight = pattern_weight.firstMatch(in: weightCapacity, range: NSRange(weightCapacity.startIndex..., in: weightCapacity)) {
                    debugPrint("👉🏼weightCapacity))weightCapacity\(weightCapacity)")
                    weightCapacity = String(weightCapacity[Range(match_weight.range, in: weightCapacity)!])
                    debugPrint("👉🏼 ty)!]) 4weightCapacity\(weightCapacity)")
                } else if weightCapacity.count > 4 {
                    debugPrint("👉🏼 > 4weightCapacity\(weightCapacity)")
                    weightCapacity = String(weightCapacity.prefix(4))
                    debugPrint("👉🏼x(4))weightCapacity\(weightCapacity)")
                }
            }
        }
        debugPrint("👉🏼\(companyName)\(serialNumber)\(weightCapacity)")
        return "\(companyName)\(serialNumber)\(weightCapacity)"
    }
    

    func nearestStringMatch(target: String, candidates: [String]) -> String {
        var bestMatch = target
        var bestDistance = Int.max
        
        for candidate in candidates {
            let distance = levenshteinDistance(s1: target, s2: candidate)
            if distance < bestDistance {
                bestDistance = distance
                bestMatch = candidate
            }
        }
        
        return bestMatch
    }
    
    func removeSmallAlphabets(fromString: String) -> String {
        return String(fromString.filter { !"abcdefghijklmnopqrstuvwxyz".contains($0) })
    }
    
    func levenshteinDistance(s1: String, s2: String) -> Int {
        let m = s1.count
        let n = s2.count
        var dp = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)

        for i in 0...m {
            dp[i][0] = i
        }

        for j in 0...n {
            dp[0][j] = j
        }

        for i in 1...m {
            for j in 1...n {
                dp[i][j] = s1[s1.index(s1.startIndex, offsetBy: i - 1)] == s2[s2.index(s2.startIndex, offsetBy: j - 1)] ?
                    dp[i - 1][j - 1] :
                    1 + min(dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1])
            }
        }

        return dp[m][n]
    }
    
    //verticalGrouper method used in verticalSortMultiline for Grouping
    func verticalGrouper(iterable: [(list: [Int], string: String)], interval: Int = 2) -> [[(list: [Int], string: String)]] {
        var prev: [(list: [Int], string: String)] = []
        var group: [(list: [Int], string: String)] = []
        var result: [[(list: [Int], string: String)]] = []
        for item in iterable {
            if prev.isEmpty || abs(item.list[0] - prev[0].list[0]) <= interval {
                group.append(item)
            } else {
                result.append(group)
                group = [item]
            }
            prev = [item]
        }
        if !group.isEmpty {
            result.append(group)
        }
        return result
    }
    
    
    //      * verticalSortMultiline method used for Vertical Container Result processing

    func verticalSortMultiline(bboxWithValue: [(list: [Int], string: String)]) -> String {
        var bboxesList = [[Int]]()
        var widths = [Int]()
        for (bbox, _) in bboxWithValue {
            let (xmin, ymin, xmax, ymax) = (bbox[0], bbox[1], bbox[2], bbox[3])
            let w = xmax - xmin
            bboxesList.append([xmin, ymin, xmax, ymax])
            widths.append(w)
        }
        widths.sort()
        let medianWidth = widths[widths.count / 2] / 2
        
        let sortedBboxesList = bboxWithValue.sorted(by: { $0.list[0] < $1.list[0] })
        let combinedBboxes = verticalGrouper(iterable: sortedBboxesList, interval: medianWidth)
        
        var finalColumns = [String]()
        for group in combinedBboxes {
            let sortedColumn = group.sorted(by: { $0.list[1] < $1.list[1] })
            let sortedColumnChars = sortedColumn.map({ $0.string }).joined()
            finalColumns.append(sortedColumnChars)
        }
        
        return finalOutput(refinedcontainerValues: refineContainerArray(containerValues: finalColumns))
    }
    
    func horizontalGrouper(iterable: [(bbox: [Int], value: String)], interval: Int = 2) -> [[(bbox: [Int], value: String)]] {
        var prev: [(bbox: [Int], value: String)] = []
        var group: [(bbox: [Int], value: String)] = []
        var result: [[(bbox: [Int], value: String)]] = []
        for item in iterable {
            if prev.isEmpty || abs(item.bbox[1] - prev[0].bbox[1]) <= interval {
                group.append(item)
            } else {
                result.append(group)
                group = [item]
            }
            prev = [item]
        }
        if !group.isEmpty {
            result.append(group)
        }
        return result
    }

    func horizontalSortMultiline(bboxWithValue: [(bbox: [Int], value: String)]) -> String {
        var bboxesList = [[Int]]()
        var heights = [Int]()
        for (bbox, _) in bboxWithValue {
            let (xmin, ymin, xmax, ymax) = (bbox[0], bbox[1], bbox[2], bbox[3])
            let h = ymax - ymin
            bboxesList.append([xmin, ymin, xmax, ymax])
            heights.append(h)
        }
        heights.sort()
        let medianWidth = heights[heights.count / 2] / 2
        
        let sortedBboxesList = bboxWithValue.sorted(by: { $0.bbox[1] < $1.bbox[1] })
        let combinedBboxes = horizontalGrouper(iterable: sortedBboxesList, interval: medianWidth)
        
        var finalRows = [String]()
        for group in combinedBboxes {
            let sortedColumn = group.sorted(by: { $0.bbox[0] < $1.bbox[0] })
            let sortedColumnChars = sortedColumn.map({ $0.value }).joined()
            finalRows.append(sortedColumnChars)
        }
        
        return finalOutput(refinedcontainerValues: refineContainerArray(containerValues: finalRows))
    }

    func finalOutput(refinedcontainerValues: [String]) -> String {
        var output = ""
        for refinedcontainerValue in refinedcontainerValues {
            output += refinedcontainerValue
        }
        return postProcessingResult(containerResult:output)
    }
    
    
    func validate(text: String, with regex: String) -> Bool {
            // Create the regex
            guard let gRegex = try? NSRegularExpression(pattern: regex) else {
                return false
            }
            
            // Create the range
            let range = NSRange(location: 0, length: text.utf16.count)
            
            // Perform the test
            if gRegex.firstMatch(in: text, options: [], range: range) != nil {
                return true
            }
            
            return false
    }
    
}

