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

#include "swiftUsd/Wrappers/UsdShadeMaterialBindingWrapper.h"

#include <exception>
#include <sstream>
#include <string_view>

#include "pxr/base/tf/token.h"
#include "pxr/usd/sdf/path.h"
#include "pxr/usd/usd/relationship.h"
#include "pxr/usd/usdShade/material.h"
#include "pxr/usd/usdShade/materialBindingAPI.h"

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

    void _AppendJSONField(std::ostringstream &stream, std::string_view name, std::string_view value) {
        stream << '"' << name << "\":";
        _AppendJSONString(stream, value);
    }

    std::string _ErrorJSON(std::string_view message) {
        std::ostringstream stream;
        stream << '{';
        stream << "\"ok\":false,";
        _AppendJSONField(stream, "error", message);
        stream << '}';
        return stream.str();
    }

    std::string _FirstTargetPath(const pxr::UsdRelationship &relationship) {
        if (!relationship.IsValid()) {
            return "";
        }
        pxr::SdfPathVector targets;
        if (!relationship.GetTargets(&targets) || targets.empty()) {
            return "";
        }
        return targets.front().GetAsString();
    }

    std::string _BindingStrength(const pxr::UsdRelationship &relationship) {
        if (!relationship.IsValid()) {
            return "";
        }
        return pxr::UsdShadeMaterialBindingAPI::GetMaterialBindingStrength(relationship).GetString();
    }
}

std::string Overlay::UsdShadeMaterialBindingWrapper::BindingInfoJSON(
    const pxr::UsdStageRefPtr &stage,
    const std::string &primPath
) {
    try {
        if (!stage) {
            return _ErrorJSON("UsdStage pointer was null.");
        }
        pxr::UsdPrim prim = stage->GetPrimAtPath(pxr::SdfPath(primPath));
        if (!prim.IsValid()) {
            return _ErrorJSON("UsdPrim was invalid.");
        }

        const std::string selectedPath = prim.GetPath().GetAsString();
        const std::string primTypeName = prim.GetTypeName().GetString();

        std::ostringstream stream;
        stream << '{';
        stream << "\"ok\":true,";
        _AppendJSONField(stream, "selectedPrimPath", selectedPath);

        if (primTypeName == "Material") {
            stream << ',';
            _AppendJSONField(stream, "effectiveMaterialPath", selectedPath);
            stream << ',';
            _AppendJSONField(stream, "authoredMaterialPath", selectedPath);
            stream << ',';
            _AppendJSONField(stream, "bindingSourcePrimPath", selectedPath);
            stream << ',';
            _AppendJSONField(stream, "bindingStrength", "");
            stream << '}';
            return stream.str();
        }

        std::string effectiveMaterialPath;
        pxr::UsdShadeMaterialBindingAPI bindingAPI(prim);
        pxr::UsdShadeMaterial material = bindingAPI.ComputeBoundMaterial();
        if (material.GetPrim().IsValid()) {
            effectiveMaterialPath = material.GetPath().GetAsString();
        }

        std::string authoredMaterialPath;
        std::string bindingSourcePrimPath;
        std::string bindingStrength;
        pxr::UsdPrim currentPrim = prim;
        while (currentPrim.IsValid()) {
            pxr::UsdShadeMaterialBindingAPI currentBindingAPI(currentPrim);
            pxr::UsdRelationship directRel = currentBindingAPI.GetDirectBindingRel(pxr::TfToken());
            const std::string targetPath = _FirstTargetPath(directRel);
            if (!targetPath.empty()) {
                authoredMaterialPath = targetPath;
                bindingSourcePrimPath = currentPrim.GetPath().GetAsString();
                bindingStrength = _BindingStrength(directRel);
                break;
            }
            currentPrim = currentPrim.GetParent();
        }

        stream << ',';
        _AppendJSONField(stream, "effectiveMaterialPath", effectiveMaterialPath);
        stream << ',';
        _AppendJSONField(stream, "authoredMaterialPath", authoredMaterialPath);
        stream << ',';
        _AppendJSONField(stream, "bindingSourcePrimPath", bindingSourcePrimPath);
        stream << ',';
        _AppendJSONField(stream, "bindingStrength", bindingStrength);
        stream << '}';
        return stream.str();
    } catch (const std::exception &exception) {
        return _ErrorJSON(exception.what());
    } catch (...) {
        return _ErrorJSON("UsdShade material binding query threw an unknown C++ exception.");
    }
}
