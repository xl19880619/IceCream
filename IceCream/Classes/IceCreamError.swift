//
//  IceCreamError.swift
//  IceCream
//
//  Created by Peter Livesey on 9/20/19.
//  Copyright © 2019 蔡越. All rights reserved.
//

import Foundation

public struct IceCreamError: LocalizedError {
    public let message: String

    public var localizedDescription: String {
        return message
    }
}
