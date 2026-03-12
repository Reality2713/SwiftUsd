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

#include "swiftUsd/Wrappers/UsdValidationWrapper.h"

#include <algorithm>
#include <cctype>
#include <sstream>
#include <string_view>
#include <vector>

#include <TargetConditionals.h>

#if TARGET_OS_OSX && __has_include("pxr/usdValidation/usdValidation/context.h")
#define SWIFTUSD_HAS_USDVALIDATION_REGISTRY 1
#include "pxr/base/plug/registry.h"
#include "pxr/base/tf/errorMark.h"
#include "pxr/usdValidation/usdValidation/context.h"
#include "pxr/usdValidation/usdValidation/error.h"
#include "pxr/usdValidation/usdValidation/fixer.h"
#include "pxr/usdValidation/usdValidation/registry.h"
#include "pxr/usdValidation/usdValidation/validator.h"
#else
#define SWIFTUSD_HAS_USDVALIDATION_REGISTRY 0
#endif

namespace {
    std::string _EscapeJSONString(std::string_view value) {
        std::string result;
        result.reserve(value.size() + 8);
        for (const char ch : value) {
            switch (ch) {
                case '\\': result += "\\\\"; break;
                case '"': result += "\\\""; break;
                case '\b': result += "\\b"; break;
                case '\f': result += "\\f"; break;
                case '\n': result += "\\n"; break;
                case '\r': result += "\\r"; break;
                case '\t': result += "\\t"; break;
                default:
                    if (static_cast<unsigned char>(ch) < 0x20) {
                        constexpr char hex[] = "0123456789abcdef";
                        result += "\\u00";
                        result += hex[(ch >> 4) & 0x0f];
                        result += hex[ch & 0x0f];
                    } else {
                        result += ch;
                    }
            }
        }
        return result;
    }

    void _AppendJSONString(std::ostringstream &stream, std::string_view value) {
        stream << '"' << _EscapeJSONString(value) << '"';
    }

    std::string _SerializeBridgeIssue(std::string_view message) {
        std::ostringstream stream;
        stream << '[';
        stream << '{';
        stream << "\"name\":\"BridgeError\",";
        stream << "\"identifier\":\"swiftUsd:ValidationBridge.BridgeError\",";
        stream << "\"severity\":\"error\",";
        stream << "\"message\":";
        _AppendJSONString(stream, message);
        stream << ",\"validatorName\":\"swiftUsd:ValidationBridge\",";
        stream << "\"validatorDocumentation\":\"SwiftUsd validation bridge failure\",";
        stream << "\"sites\":[],\"fixers\":[]";
        stream << '}';
        stream << ']';
        return stream.str();
    }

#if SWIFTUSD_HAS_USDVALIDATION_REGISTRY
    pxr::TfTokenVector _ToTfTokenVector(const Overlay::String_Vector &strings) {
        pxr::TfTokenVector result;
        result.reserve(strings.size());
        for (const auto &entry : strings) {
            result.emplace_back(entry);
        }
        return result;
    }

    std::string _ErrorSeverityString(pxr::UsdValidationErrorType severity) {
        switch (severity) {
            case pxr::UsdValidationErrorType::Error: return "error";
            case pxr::UsdValidationErrorType::Warn: return "warning";
            case pxr::UsdValidationErrorType::Info: return "info";
            case pxr::UsdValidationErrorType::None: return "none";
        }
    }

    void _EnsureValidationRegistryLoaded() {
        pxr::PlugRegistry::GetInstance().GetAllPlugins();
        pxr::UsdValidationRegistry::GetInstance().GetOrLoadAllValidators();
    }

    std::string _SiteKind(const pxr::UsdValidationErrorSite &site) {
        if (site.IsPrim()) {
            return "prim";
        }
        if (site.IsProperty()) {
            return "property";
        }
        if (site.IsValidSpecInLayer()) {
            return "layerSpec";
        }
        return "unknown";
    }

    std::string _SiteObjectPath(const pxr::UsdValidationErrorSite &site) {
        if (site.IsPrim()) {
            return site.GetPrim().GetPath().GetAsString();
        }
        if (site.IsProperty()) {
            return site.GetProperty().GetPath().GetAsString();
        }
        if (const auto primSpec = site.GetPrimSpec()) {
            return primSpec->GetPath().GetAsString();
        }
        if (const auto propertySpec = site.GetPropertySpec()) {
            return propertySpec->GetPath().GetAsString();
        }
        return {};
    }

    std::string _Lowercased(std::string value) {
        std::transform(
            value.begin(),
            value.end(),
            value.begin(),
            [](unsigned char character) {
                return static_cast<char>(std::tolower(character));
            }
        );
        return value;
    }

    std::string _TrimAngleBrackets(std::string value) {
        if (!value.empty() && value.front() == '<') {
            value.erase(value.begin());
        }
        if (!value.empty() && value.back() == '>') {
            value.pop_back();
        }
        return value;
    }

    bool _ExtractBetween(
        const std::string &message,
        const std::string_view prefix,
        const std::string_view suffix,
        std::string *captured
    ) {
        const auto prefixPosition = message.find(prefix);
        if (prefixPosition == std::string::npos) {
            return false;
        }
        const auto valueStart = prefixPosition + prefix.size();
        const auto suffixPosition = message.find(suffix, valueStart);
        if (suffixPosition == std::string::npos) {
            return false;
        }
        *captured = message.substr(valueStart, suffixPosition - valueStart);
        return true;
    }

    std::string _PropertyPathFromSites(const pxr::UsdValidationErrorSites &sites) {
        for (const auto &site : sites) {
            if (site.IsProperty()) {
                return site.GetProperty().GetPath().GetAsString();
            }
        }
        for (const auto &site : sites) {
            if (const auto propertySpec = site.GetPropertySpec()) {
                return propertySpec->GetPath().GetAsString();
            }
        }
        for (const auto &site : sites) {
            const auto objectPath = _SiteObjectPath(site);
            if (objectPath.find('.') != std::string::npos) {
                return objectPath;
            }
        }
        return {};
    }

    void _ExtractStructuredTypeMismatchFields(
        const pxr::UsdValidationError &error,
        std::string *propertyPath,
        std::string *expectedType,
        std::string *actualType
    ) {
        *propertyPath = _PropertyPathFromSites(error.GetSites());
        *expectedType = {};
        *actualType = {};

        const std::string message = error.GetMessage();

        std::string extractedPath;
        if (_ExtractBetween(
                message,
                "Incorrect type for ",
                ". Expected",
                &extractedPath
            )) {
            *propertyPath = _TrimAngleBrackets(extractedPath);
            _ExtractBetween(message, "Expected '", "'; got '", expectedType);
            _ExtractBetween(message, "'; got '", "'.", actualType);
            *expectedType = _Lowercased(*expectedType);
            *actualType = _Lowercased(*actualType);
            return;
        }

        if (_ExtractBetween(
                message,
                "Type mismatch for attribute ",
                ". Expected attribute type is ",
                &extractedPath
            )) {
            *propertyPath = _TrimAngleBrackets(extractedPath);
            _ExtractBetween(
                message,
                "Expected attribute type is '",
                "' but defined as '",
                expectedType
            );
            _ExtractBetween(
                message,
                "' but defined as '",
                "' in layer ",
                actualType
            );
            *expectedType = _Lowercased(*expectedType);
            *actualType = _Lowercased(*actualType);
        }
    }

    void _AppendKeywordArray(
        std::ostringstream &stream,
        const pxr::TfTokenVector &keywords
    ) {
        stream << '[';
        bool isFirst = true;
        for (const auto &keyword : keywords) {
            if (!isFirst) {
                stream << ',';
            }
            isFirst = false;
            _AppendJSONString(stream, keyword.GetString());
        }
        stream << ']';
    }

    void _AppendFixers(
        std::ostringstream &stream,
        const std::vector<const pxr::UsdValidationFixer *> &fixers
    ) {
        stream << '[';
        bool isFirst = true;
        for (const auto *fixer : fixers) {
            if (!fixer) {
                continue;
            }
            if (!isFirst) {
                stream << ',';
            }
            isFirst = false;
            stream << '{';
            stream << "\"name\":";
            _AppendJSONString(stream, fixer->GetName().GetString());
            stream << ",\"description\":";
            _AppendJSONString(stream, fixer->GetDescription());
            stream << ",\"errorName\":";
            _AppendJSONString(stream, fixer->GetErrorName().GetString());
            stream << ",\"keywords\":";
            _AppendKeywordArray(stream, fixer->GetKeywords());
            stream << '}';
        }
        stream << ']';
    }

    void _AppendSites(
        std::ostringstream &stream,
        const pxr::UsdValidationErrorSites &sites
    ) {
        stream << '[';
        bool isFirst = true;
        for (const auto &site : sites) {
            if (!isFirst) {
                stream << ',';
            }
            isFirst = false;
            stream << '{';
            stream << "\"kind\":";
            _AppendJSONString(stream, _SiteKind(site));
            stream << ",\"objectPath\":";
            _AppendJSONString(stream, _SiteObjectPath(site));
            stream << ",\"layerIdentifier\":";
            if (const auto &layer = site.GetLayer()) {
                _AppendJSONString(stream, layer->GetIdentifier());
            } else {
                stream << "null";
            }
            stream << '}';
        }
        stream << ']';
    }

    std::string _SerializeMetadata(
        const pxr::UsdValidationValidatorMetadataVector &metadata
    ) {
        auto sortedMetadata = metadata;
        std::sort(
            sortedMetadata.begin(),
            sortedMetadata.end(),
            [](const auto &lhs, const auto &rhs) {
                return lhs.name < rhs.name;
            }
        );

        std::ostringstream stream;
        stream << '[';
        bool isFirst = true;
        for (const auto &entry : sortedMetadata) {
            if (!isFirst) {
                stream << ',';
            }
            isFirst = false;
            stream << '{';
            stream << "\"name\":";
            _AppendJSONString(stream, entry.name.GetString());
            stream << ",\"pluginName\":";
            if (entry.pluginPtr) {
                _AppendJSONString(stream, entry.pluginPtr->GetName());
            } else {
                stream << "null";
            }
            stream << ",\"documentation\":";
            _AppendJSONString(stream, entry.doc);
            stream << ",\"keywords\":";
            _AppendKeywordArray(stream, entry.keywords);
            stream << ",\"schemaTypes\":";
            _AppendKeywordArray(stream, entry.schemaTypes);
            stream << ",\"isSuite\":" << (entry.isSuite ? "true" : "false");
            stream << ",\"isTimeDependent\":"
                   << (entry.isTimeDependent ? "true" : "false");
            stream << '}';
        }
        stream << ']';
        return stream.str();
    }

    std::string _SerializeRuleCandidates(
        const std::vector<const pxr::UsdValidationValidator *> &validators
    ) {
        std::vector<const pxr::UsdValidationValidator *> sortedValidators = validators;
        std::sort(
            sortedValidators.begin(),
            sortedValidators.end(),
            [](const auto *lhs, const auto *rhs) {
                if (lhs == nullptr || rhs == nullptr) {
                    return lhs != nullptr;
                }
                return lhs->GetMetadata().name < rhs->GetMetadata().name;
            }
        );

        std::ostringstream stream;
        stream << '[';
        bool isFirstValidator = true;
        for (const auto *validator : sortedValidators) {
            if (!validator) {
                continue;
            }
            if (!isFirstValidator) {
                stream << ',';
            }
            isFirstValidator = false;

            const auto &metadata = validator->GetMetadata();
            const auto fixers = validator->GetFixers();

            stream << '{';
            stream << "\"validatorName\":";
            _AppendJSONString(stream, metadata.name.GetString());
            stream << ",\"pluginName\":";
            if (metadata.pluginPtr) {
                _AppendJSONString(stream, metadata.pluginPtr->GetName());
            } else {
                stream << "null";
            }
            stream << ",\"documentation\":";
            _AppendJSONString(stream, metadata.doc);
            stream << ",\"keywords\":";
            _AppendKeywordArray(stream, metadata.keywords);
            stream << ",\"schemaTypes\":";
            _AppendKeywordArray(stream, metadata.schemaTypes);
            stream << ",\"candidateRuleIdentifiers\":";
            stream << '[';
            bool isFirstCandidate = true;
            for (const auto *fixer : fixers) {
                if (!fixer) {
                    continue;
                }
                if (!isFirstCandidate) {
                    stream << ',';
                }
                isFirstCandidate = false;
                _AppendJSONString(
                    stream,
                    metadata.name.GetString() + "." + fixer->GetErrorName().GetString()
                );
            }
            stream << ']';
            stream << ",\"fixers\":";
            _AppendFixers(stream, fixers);
            stream << '}';
        }
        stream << ']';
        return stream.str();
    }

    std::string _SerializeErrors(
        const pxr::UsdValidationErrorVector &errors,
        const pxr::TfErrorMark &errorMark
    ) {
        std::ostringstream stream;
        stream << '[';
        bool isFirst = true;
        for (const auto &error : errors) {
            if (!isFirst) {
                stream << ',';
            }
            isFirst = false;

            std::string propertyPath;
            std::string expectedType;
            std::string actualType;
            _ExtractStructuredTypeMismatchFields(
                error,
                &propertyPath,
                &expectedType,
                &actualType
            );

            stream << '{';
            stream << "\"name\":";
            _AppendJSONString(stream, error.GetName().GetString());
            stream << ",\"identifier\":";
            _AppendJSONString(stream, error.GetIdentifier().GetString());
            stream << ",\"severity\":";
            _AppendJSONString(stream, _ErrorSeverityString(error.GetType()));
            stream << ",\"message\":";
            _AppendJSONString(stream, error.GetMessage());
            stream << ",\"validatorName\":";
            if (const auto *validator = error.GetValidator()) {
                _AppendJSONString(stream, validator->GetMetadata().name.GetString());
            } else {
                stream << "null";
            }
            stream << ",\"validatorDocumentation\":";
            if (const auto *validator = error.GetValidator()) {
                _AppendJSONString(stream, validator->GetMetadata().doc);
            } else {
                stream << "null";
            }
            stream << ",\"propertyPath\":";
            if (propertyPath.empty()) {
                stream << "null";
            } else {
                _AppendJSONString(stream, propertyPath);
            }
            stream << ",\"expectedType\":";
            if (expectedType.empty()) {
                stream << "null";
            } else {
                _AppendJSONString(stream, expectedType);
            }
            stream << ",\"actualType\":";
            if (actualType.empty()) {
                stream << "null";
            } else {
                _AppendJSONString(stream, actualType);
            }
            stream << ",\"sites\":";
            _AppendSites(stream, error.GetSites());
            stream << ",\"fixers\":";
            _AppendFixers(stream, error.GetFixers());
            stream << '}';
        }

        for (auto iterator = errorMark.GetBegin(); iterator != errorMark.GetEnd(); ++iterator) {
            if (!isFirst) {
                stream << ',';
            }
            isFirst = false;
            stream << '{';
            stream << "\"name\":\"TfError\",";
            stream << "\"identifier\":\"swiftUsd:ValidationBridge.TfError\",";
            stream << "\"severity\":\"error\",";
            stream << "\"message\":";
            _AppendJSONString(stream, iterator->GetCommentary());
            stream << ",\"validatorName\":\"swiftUsd:ValidationBridge\",";
            stream << "\"validatorDocumentation\":\"OpenUSD reported a TfError while loading validators or executing validation\",";
            stream << "\"propertyPath\":null,";
            stream << "\"expectedType\":null,";
            stream << "\"actualType\":null,";
            stream << "\"sites\":[],\"fixers\":[]";
            stream << '}';
        }

        stream << ']';
        return stream.str();
    }
#endif
}

bool Overlay::UsdValidationWrapper::IsRegistryExecutionAvailable() {
#if SWIFTUSD_HAS_USDVALIDATION_REGISTRY
    return true;
#else
    return false;
#endif
}

std::string Overlay::UsdValidationWrapper::GetAllValidatorMetadataJSON() {
#if SWIFTUSD_HAS_USDVALIDATION_REGISTRY
    pxr::TfErrorMark errorMark;
    _EnsureValidationRegistryLoaded();
    return _SerializeMetadata(
        pxr::UsdValidationRegistry::GetInstance().GetAllValidatorMetadata()
    );
#else
    return "[]";
#endif
}

std::string Overlay::UsdValidationWrapper::GetValidatorMetadataForKeywordsJSON(
    const Overlay::String_Vector &keywords
) {
#if SWIFTUSD_HAS_USDVALIDATION_REGISTRY
    pxr::TfErrorMark errorMark;
    _EnsureValidationRegistryLoaded();
    return _SerializeMetadata(
        pxr::UsdValidationRegistry::GetInstance().GetValidatorMetadataForKeywords(
            _ToTfTokenVector(keywords)
        )
    );
#else
    return "[]";
#endif
}

std::string Overlay::UsdValidationWrapper::GetAllValidatorRuleCandidatesJSON() {
#if SWIFTUSD_HAS_USDVALIDATION_REGISTRY
    pxr::TfErrorMark errorMark;
    _EnsureValidationRegistryLoaded();
    return _SerializeRuleCandidates(
        pxr::UsdValidationRegistry::GetInstance().GetOrLoadAllValidators()
    );
#else
    return "[]";
#endif
}

std::string Overlay::UsdValidationWrapper::ValidateStageJSON(
    const pxr::UsdStageRefPtr &stage,
    const Overlay::String_Vector &keywords
) {
#if SWIFTUSD_HAS_USDVALIDATION_REGISTRY
    if (!stage) {
        return _SerializeBridgeIssue("UsdStage pointer was null.");
    }

    pxr::TfErrorMark errorMark;
    _EnsureValidationRegistryLoaded();
    pxr::UsdValidationContext context(_ToTfTokenVector(keywords));
    return _SerializeErrors(context.Validate(stage), errorMark);
#else
    return _SerializeBridgeIssue(
        "UsdValidationRegistry execution is unavailable in this SwiftUsd build."
    );
#endif
}

std::string Overlay::UsdValidationWrapper::ValidateStageWithUsdCoreValidatorsJSON(
    const pxr::UsdStageRefPtr &stage
) {
    Overlay::String_Vector keywords;
    keywords.push_back("UsdCoreValidators");
    return ValidateStageJSON(stage, keywords);
}
