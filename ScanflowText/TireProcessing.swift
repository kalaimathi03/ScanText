//
//  TireProcessing.swift
//  ScanflowText
//
//  Created by Mac-OBS-46 on 28/09/23.
//

import Foundation

class TireProcessing : NSObject {

    static public let shared = TireProcessing()

       let pattern_date = try! NSRegularExpression(pattern: "[0-9]{4}$")
       let pattern_dot_date_regex = try! NSRegularExpression(pattern: "([0-5]{1}[0-9]{1}[0-2]{1}[0-9]{1})$", options: [])
       let pattern_date_regex = try! NSRegularExpression(pattern: "[0-9]{4}$")
       let dateStartLetterList = ["0", "1", "2", "3", "4", "5"]
       let dateThirdLetterList = ["0", "1", "2"]

      // 3, 4, 4
       let pattern_dot_11_1 = try! NSRegularExpression(pattern: "DOT [A-FHJ-NPRT-Y0-9]{4} [0-5][0-9][0-2][0-9]{1}", options: [])
      // 3, 4, 7
       let pattern_dot_14_1 = try! NSRegularExpression(pattern: "DOT [A-FHJ-NPRT-Y0-9]{4} [A-FHJ-NPRT-Y0-9]{3}[0-5][0-9][0-2][0-9]{1}")
      // 3, 2, 2, 3, 4
       let pattern_dot_14_2 = try! NSRegularExpression(pattern: "DOT [A-FHJ-NPRT-Y0-9]{2} [A-FHJ-NPRT-Y0-9]{2} [A-FHJ-NPRT-Y0-9]{3} [0-5][0-9][0-2][0-9]{1}")
      // 3, 4, 3, 4
   let pattern_dot_14_3 = try! NSRegularExpression(pattern: "DOT [A-FHJ-NPRT-Y0-9]{4} [A-FHJ-NPRT-Y0-9]{3} [0-5][0-9][0-2][0-9]{1}")
      // 3, 4, 4, 4
       let pattern_dot_15_1 = try! NSRegularExpression(pattern: "DOT [A-FHJ-NPRT-Y0-9]{4} [A-FHJ-NPRT-Y0-9]{4} [0-5][0-9][0-2][0-9]{1}")
      // 3, 2, 2, 4, 4
       let pattern_dot_15_2 = try! NSRegularExpression(pattern: "DOT [A-FHJ-NPRT-Y0-9]{2} [A-FHJ-NPRT-Y0-9]{2} [A-FHJ-NPRT-Y0-9]{4} [0-5][0-9][0-2][0-9]{1}")
      // 3, 4, 8
       let pattern_dot_15_3 = try! NSRegularExpression(pattern: "DOT [A-FHJ-NPRT-Y0-9]{4} [A-FHJ-NPRT-Y0-9]{4}[0-5][0-9][0-2][0-9]{1}")
      // 3, 3, 6, 4
       let pattern_dot_16_1 = try! NSRegularExpression(pattern: "DOT [A-FHJ-NPRT-Y0-9]{3} [A-FHJ-NPRT-Y0-9]{6} [0-5][0-9][0-2][0-9]{1}")
      // 3, 5, 4, 4
       let pattern_dot_16_2 = try! NSRegularExpression(pattern: "DOT [A-FHJ-NPRT-Y0-9]{5} [A-FHJ-NPRT-Y0-9]{4} [0-5][0-9][0-2][0-9]{1}")



    func dotPostProcessing(tyreDataOrginal: String, tryCount: Int = 0) -> String? {
        print(tyreDataOrginal)
       if tyreDataOrginal.hasPrefix("DOT") && tyreDataOrginal.count > 9 && tryCount < 2 {
           var tyreDataUpdated = tyreDataOrginal.dropFirst(3)

          var newTyreDataUpdated = tyreDataUpdated.replacingOccurrences(of: "G", with: "6")
               .replacingOccurrences(of: "g", with: "9")
               .replacingOccurrences(of: "I", with: "1")
               .replacingOccurrences(of: "i", with: "1")
               .replacingOccurrences(of: "O", with: "0")
               .replacingOccurrences(of: "o", with: "8")
               .replacingOccurrences(of: "Q", with: "R")
               .replacingOccurrences(of: "q", with: "9")
               .replacingOccurrences(of: "S", with: "5")
               .replacingOccurrences(of: "s", with: "5")
               .replacingOccurrences(of: "Z", with: "2")
               .replacingOccurrences(of: "z", with: "3")

           var tyreData = "DOT" + newTyreDataUpdated

           if tyreData.replacingOccurrences(of: " ", with: "").count == 11 {
               if let dotMatch1 = pattern_dot_11_1.firstMatch(in: tyreData, range: NSRange(tyreData.startIndex..., in: tyreData)) {
                   return String(tyreData[Range(dotMatch1.range(at: 0), in: tyreData)!])

               } else {
                   return tireProcessingMatchfailed(tyreData: tyreData, tryCount: tryCount)
               }

           } else if tyreData.replacingOccurrences(of: " ", with: "").count == 14 {
               if let dotMatch1 = pattern_dot_14_1.firstMatch(in: tyreData, range: NSRange(tyreData.startIndex..., in: tyreData)),
                  let dotMatch2 = pattern_dot_14_2.firstMatch(in: tyreData, range: NSRange(tyreData.startIndex..., in: tyreData)),
                  let dotMatch3 = pattern_dot_14_3.firstMatch(in: tyreData, range: NSRange(tyreData.startIndex..., in: tyreData)) {
                   return String(tyreData[Range(dotMatch1.range, in: tyreData)!])
               } else {
                   return tireProcessingMatchfailed(tyreData: tyreData, tryCount: tryCount)
               }
           } else if tyreData.replacingOccurrences(of: " ", with: "").count == 15 {
               if let dotMatch1 = pattern_dot_15_1.firstMatch(in: tyreData, range: NSRange(tyreData.startIndex..., in: tyreData)),
                  let dotMatch2 = pattern_dot_15_2.firstMatch(in: tyreData, range: NSRange(tyreData.startIndex..., in: tyreData)),
                  let dotMatch3 = pattern_dot_15_3.firstMatch(in: tyreData, range: NSRange(tyreData.startIndex..., in: tyreData)) {
                   return String(tyreData[Range(dotMatch1.range, in: tyreData)!])
               } else {
                   return tireProcessingMatchfailed(tyreData: tyreData, tryCount: tryCount)
               }
           } else if tyreData.replacingOccurrences(of: " ", with: "").count == 16 {
               if let dotMatch1 = pattern_dot_16_1.firstMatch(in: tyreData, range: NSRange(tyreData.startIndex..., in: tyreData)),
                  let dotMatch2 = pattern_dot_16_2.firstMatch(in: tyreData, range: NSRange(tyreData.startIndex..., in: tyreData)) {
                   return String(tyreData[Range(dotMatch1.range, in: tyreData)!])
               } else {
                   return tireProcessingMatchfailed(tyreData: tyreData, tryCount: tryCount)
               }
           } else {
               return nil
           }
       } else {
           return nil
       }
   }


    func tireProcessingMatchfailed(tyreData: String, tryCount: Int) -> String? {
        if tyreData.count > 5 {
            var dateRegexList:[String] = []
            if let dateRegexMatches = pattern_dot_date_regex.firstMatch(in: tyreData, range: NSRange(tyreData.startIndex..., in: tyreData)) {
                dateRegexList.append(String(tyreData[Range(dateRegexMatches.range, in: tyreData)!]))
            }

            if dateRegexList.isEmpty {
                if let dateRegexMatches = pattern_date_regex.firstMatch(in: tyreData, range: NSRange(tyreData.startIndex..., in: tyreData)) {

                    dateRegexList.append(String(tyreData[Range(dateRegexMatches.range, in: tyreData)!]))
                }
            }

            if dateRegexList.count > 0 {
                var tyreDataLast = dateRegexList.last!
                var tyreLastFirstChar = String(tyreDataLast[tyreDataLast.index(tyreDataLast.startIndex, offsetBy: 0)])
                var tyreLastThridChar = String(tyreDataLast[tyreDataLast.index(tyreDataLast.startIndex, offsetBy: 2)])

                if !dateStartLetterList.contains(tyreLastFirstChar) {
                    tyreLastFirstChar = tyreLastFirstChar.replacingOccurrences(of: "6", with: "5")
                        .replacingOccurrences(of: "7", with: "1")
                        .replacingOccurrences(of: "8", with: "3")
                        .replacingOccurrences(of: "9", with: "1")
                }

                if !dateThirdLetterList.contains(tyreLastThridChar) {
                    tyreLastThridChar = tyreLastThridChar.replacingOccurrences(of: "3", with: "2")
                        .replacingOccurrences(of: "7", with: "1")
                        .replacingOccurrences(of: "8", with: "0")
                        .replacingOccurrences(of: "9", with: "1")
                }

                if let tyreDataLastIndex = tyreData.range(of: tyreDataLast)?.lowerBound {
                    tyreDataLast = "\(tyreLastFirstChar)\(tyreDataLast[tyreDataLast.index(tyreDataLast.startIndex, offsetBy: 1)])\(tyreLastThridChar)\(tyreDataLast[tyreDataLast.index(tyreDataLast.startIndex, offsetBy: 3)])"
                    let tyreDataFirst = String(tyreData[..<tyreDataLastIndex])
                    let finalTryeData = "\(tyreDataFirst)\(tyreDataLast)"

                    if pattern_date.firstMatch(in: finalTryeData, range: NSRange(finalTryeData.startIndex..., in: finalTryeData)) != nil {
                        return dotPostProcessing(tyreDataOrginal: finalTryeData, tryCount: tryCount + 1)
                    } else {
                        return nil
                    }
                }
            } else {
                var tyreDataFirst = String(tyreData[..<tyreData.index(tyreData.endIndex, offsetBy: -4)])
                var tyreDataLast = String(tyreData[tyreData.index(tyreData.endIndex, offsetBy: -4)...])
                tyreDataLast = tyreDataLast.replacingOccurrences(of: "O", with: "0")
                    .replacingOccurrences(of: "i", with: "1")
                    .replacingOccurrences(of: "I", with: "1")
                    .replacingOccurrences(of: "K", with: "5")
                    .replacingOccurrences(of: "G", with: "6")
                    .replacingOccurrences(of: "C", with: "5")
                    .replacingOccurrences(of: "L", with: "1")
                    .replacingOccurrences(of: "B", with: "8")
                    .replacingOccurrences(of: "g", with: "9")
                    .replacingOccurrences(of: "E", with: "5")
                    .replacingOccurrences(of: "A", with: "4")
                    .replacingOccurrences(of: "T", with: "1")
                    .replacingOccurrences(of: "Z", with: "2")

                let tyreDataUpdated = "\(tyreDataFirst)\(tyreDataLast)"

                if pattern_date.firstMatch(in: tyreDataUpdated, range: NSRange(tyreDataUpdated.startIndex..., in: tyreDataUpdated)) != nil {
                    return dotPostProcessing(tyreDataOrginal: tyreDataUpdated, tryCount: tryCount + 1)
                } else {
                    return nil
                }
            }
        } else {
            return nil
        }

        return nil
    }
}
