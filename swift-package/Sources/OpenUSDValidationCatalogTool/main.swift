import CxxStdlib
import Foundation
import _OpenUSD_SwiftBindingHelpers

struct UsdValidationFixerDescriptor: Codable {
    let name: String
    let description: String
    let errorName: String
    let keywords: [String]
}

struct UsdValidationRuleCandidateDescriptor: Codable {
    let validatorName: String
    let pluginName: String?
    let documentation: String
    let keywords: [String]
    let schemaTypes: [String]
    let candidateRuleIdentifiers: [String]
    let fixers: [UsdValidationFixerDescriptor]
}

struct ValidationCatalogPayload: Codable {
    let generatedFrom: String
    let baseline: [String: String]
    let summary: Summary
    let entries: [Entry]

    struct Summary: Codable {
        let validatorCount: Int
        let fixerBackedValidatorCount: Int
        let candidateRuleIdentifierCount: Int
    }

    struct Entry: Codable {
        let validatorName: String
        let pluginName: String?
        let documentation: String
        let keywords: [String]
        let schemaTypes: [String]
        let candidateRuleIdentifiers: [String]
        let fixers: [UsdValidationFixerDescriptor]
    }
}

let json = Overlay.UsdValidationWrapper.GetAllValidatorRuleCandidatesJSON()
let data = Data(String(json).utf8)
let rawEntries = try JSONDecoder().decode([UsdValidationRuleCandidateDescriptor].self, from: data)
let entries = rawEntries.map {
    ValidationCatalogPayload.Entry(
        validatorName: $0.validatorName,
        pluginName: $0.pluginName,
        documentation: $0.documentation,
        keywords: $0.keywords,
        schemaTypes: $0.schemaTypes,
        candidateRuleIdentifiers: $0.candidateRuleIdentifiers,
        fixers: $0.fixers
    )
}

// Hoisted sub-expressions: the single literal form exceeds the Swift 6.4
// type-checker's expression budget ("unable to type-check in reasonable time").
let baseline: [String: String] = [
    "openUSD": "26.03",
    "swiftUsd": "6.0.0",
]
let fixerBackedValidatorCount: Int = entries.filter { !$0.fixers.isEmpty }.count
let candidateRuleIdentifierCount: Int = entries.reduce(0) { $0 + $1.candidateRuleIdentifiers.count }
let summary = ValidationCatalogPayload.Summary(
    validatorCount: entries.count,
    fixerBackedValidatorCount: fixerBackedValidatorCount,
    candidateRuleIdentifierCount: candidateRuleIdentifierCount
)
let sortedEntries: [ValidationCatalogPayload.Entry] = entries.sorted { $0.validatorName < $1.validatorName }
let payload = ValidationCatalogPayload(
    generatedFrom: "SwiftUsd usdValidation registry and validator fixers",
    baseline: baseline,
    summary: summary,
    entries: sortedEntries
)

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let output = try encoder.encode(payload)
FileHandle.standardOutput.write(output)
FileHandle.standardOutput.write(Data("\n".utf8))
