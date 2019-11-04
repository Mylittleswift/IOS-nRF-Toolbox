//
//  BGMRecordAccess.swift
//  nRF Toolbox
//
//  Created by Mostafa Berg on 18/05/16.
//  Copyright © 2016 Nordic Semiconductor. All rights reserved.
//


enum BGMOpCode : UInt8 {
    case reserved                 = 0
    case reportStoredRecords      = 1
    case deleteStoredRecords      = 2
    case abort                    = 3
    case reportStoredRecordsCount = 4
    case numberOfStoredRecords    = 5
    case response                 = 6
    // Values outside this range are reserved
}

enum BGMOperator : UInt8 {
    case null                 = 0
    case allRecords           = 1
    case lessThanOrEqual      = 2
    case greaterThanOrEqual   = 3
    case withinRangeInclusive = 4
    case first                = 5
    case last                 = 6
    // Values outside this range are reserved
}

enum BGMFilterType : UInt8 {
    case reserved       = 0
    case sequenceNumber = 1
    case userFacingTime = 2
}

enum BGMResponseCode : UInt8 {
    case reserved              = 0
    case success               = 1
    case opCodeNotSupported    = 2
    case invalidOperator       = 3
    case operatorNotSupported  = 4
    case invalidOperand        = 5
    case noRecordsFound        = 6
    case abortUnsuccessful     = 7
    case procedureNotCompleted = 8
    case operandNotSupported   = 9
    // Values outside this range are reserved
}
