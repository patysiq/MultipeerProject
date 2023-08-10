//
//  Data.swift
//  MultiPeerImage
//
//  Created by PATRICIA S SIQUEIRA on 10/08/23.
//

import Foundation

public extension Data {
    var fileExtension: String {
        var values = [UInt8](repeating:0, count:1)
        self.copyBytes(to: &values, count: 1)

        switch (values[0]) {
        case 0xFF:
            return ".jpg"
        case 0x89:
            return ".png"
        case 0x47:
            return ".gif"
        case 0x49, 0x4D :
            return ".tiff"
        case 0x52 where self.count >= 12:
                    let subdata = self[0...11]

                    if let dataString = String(data: subdata, encoding: .ascii),
                        dataString.hasPrefix("RIFF"),
                        dataString.hasSuffix("WEBP")
                    {
                        return ".webp"
                    }           

        case 0x00 where self.count >= 12 :
                    let subdata = self[8...11]

                    if let dataString = String(data: subdata, encoding: .ascii),
                        Set(["heic", "heix", "hevc", "hevx"]).contains(dataString)
                    {
                        return ".heic"
                    }
            break
        default:
            return ".png"
        }
        return ""
    }
    
}
