//===----------------------------------------------------------------------===//
// This source file is part of github.com/apple/SwiftUsd
//
// Copyright © 2025 Apple Inc. and the SwiftUsd project authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//  https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// SPDX-License-Identifier: Apache-2.0
//===----------------------------------------------------------------------===//

#if canImport(SwiftUsd_PXR_ENABLE_USD_VALIDATION_SUPPORT)
import Foundation
import CxxStdlib

public enum UsdValidationSeverity: String, Codable, Sendable {
    case none
    case error
    case warning
    case info
}

public struct UsdValidationFixerDescriptor: Codable, Sendable, Hashable {
    public let name: String
    public let description: String
    public let errorName: String
    public let keywords: [String]
}

public struct UsdValidationSiteDescriptor: Codable, Sendable, Hashable {
    public let kind: String
    public let objectPath: String
    public let layerIdentifier: String?
}

public struct UsdValidationValidatorDescriptor: Codable, Sendable, Hashable {
    public let name: String
    public let pluginName: String?
    public let documentation: String
    public let keywords: [String]
    public let schemaTypes: [String]
    public let isSuite: Bool
    public let isTimeDependent: Bool
}

public struct UsdValidationRuleCandidateDescriptor: Codable, Sendable, Hashable {
    public let validatorName: String
    public let pluginName: String?
    public let documentation: String
    public let keywords: [String]
    public let schemaTypes: [String]
    public let candidateRuleIdentifiers: [String]
    public let fixers: [UsdValidationFixerDescriptor]
}

public struct UsdValidationIssueDescriptor: Codable, Sendable, Hashable {
    public let name: String
    public let identifier: String
    public let severity: UsdValidationSeverity
    public let message: String
    public let validatorName: String?
    public let validatorDocumentation: String?
    public let propertyPath: String?
    public let expectedType: String?
    public let actualType: String?
    public let sites: [UsdValidationSiteDescriptor]
    public let fixers: [UsdValidationFixerDescriptor]
}

extension Overlay.String_Vector {
    public init<S: Sequence>(_ strings: S) where S.Element == String {
        self.init()
        for string in strings {
            self.push_back(std.string(string))
        }
    }
}

private enum _UsdValidationJSON {
    static let decoder = JSONDecoder()

    static func decode<T: Decodable>(_ json: std.string) throws -> T {
        try decoder.decode(T.self, from: Data(String(json).utf8))
    }
}

extension Overlay.UsdValidationWrapper {
    public static let usdCoreValidatorsKeyword = "UsdCoreValidators"

    public static var isRegistryExecutionAvailable: Bool {
        IsRegistryExecutionAvailable()
    }

    public static func allValidatorMetadata() throws -> [UsdValidationValidatorDescriptor] {
        try _UsdValidationJSON.decode(GetAllValidatorMetadataJSON())
    }

    public static func validatorMetadata<S: Sequence>(
        forKeywords keywords: S
    ) throws -> [UsdValidationValidatorDescriptor] where S.Element == String {
        try _UsdValidationJSON.decode(
            GetValidatorMetadataForKeywordsJSON(.init(keywords))
        )
    }

    public static func allValidatorRuleCandidates() throws -> [UsdValidationRuleCandidateDescriptor] {
        try _UsdValidationJSON.decode(GetAllValidatorRuleCandidatesJSON())
    }

    public static func validateStage<S: Sequence>(
        _ stage: pxr.UsdStageRefPtr,
        keywords: S
    ) throws -> [UsdValidationIssueDescriptor] where S.Element == String {
        try _UsdValidationJSON.decode(ValidateStageJSON(stage, .init(keywords)))
    }

    public static func validateStageWithUsdCoreValidators(
        _ stage: pxr.UsdStageRefPtr
    ) throws -> [UsdValidationIssueDescriptor] {
        try _UsdValidationJSON.decode(ValidateStageWithUsdCoreValidatorsJSON(stage))
    }
}
#endif
