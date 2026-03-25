//
//  VersionUtils.swift
//  NetRatio
//
//  Created by Ihor Manzii on 25.03.2026.
//

import Foundation

enum VersionUtils {

    static func getAppVersion(bundle: Bundle = .main) -> String {
        let shortVersion =
            bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString")
            as? String ?? "undefined"

        return "\(shortVersion)"
    }
}
