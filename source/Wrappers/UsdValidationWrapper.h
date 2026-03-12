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

#ifndef SWIFTUSD_WRAPPERS_USDVALIDATIONWRAPPER_H
#define SWIFTUSD_WRAPPERS_USDVALIDATIONWRAPPER_H

#include <string>
#include "swiftUsd/SwiftOverlay/Typedefs.h"
#include "pxr/usd/usd/stage.h"

namespace Overlay {
    /// Narrow bridge around OpenUSD's usdValidation framework.
    ///
    /// SwiftUsd treats the OpenUSD validators as the canonical executable
    /// validity engine, but keeps the full usdValidation C++ API private.
    /// The wrapper returns JSON so Swift can consume structured validation
    /// results without importing the raw validator types directly.
    class UsdValidationWrapper {
    public:
        static bool IsRegistryExecutionAvailable();

        static std::string GetAllValidatorMetadataJSON();

        static std::string GetValidatorMetadataForKeywordsJSON(
            const Overlay::String_Vector &keywords);

        static std::string ValidateStageJSON(
            const pxr::UsdStageRefPtr &stage,
            const Overlay::String_Vector &keywords);

        static std::string ValidateStageWithUsdCoreValidatorsJSON(
            const pxr::UsdStageRefPtr &stage);
    };
}

#endif /* SWIFTUSD_WRAPPERS_USDVALIDATIONWRAPPER_H */
