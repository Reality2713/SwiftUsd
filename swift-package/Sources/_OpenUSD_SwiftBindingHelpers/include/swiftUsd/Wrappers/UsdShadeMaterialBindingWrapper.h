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

#ifndef SWIFTUSD_WRAPPERS_USDSHADEMATERIALBINDINGWRAPPER_H
#define SWIFTUSD_WRAPPERS_USDSHADEMATERIALBINDINGWRAPPER_H

#include <string>
#include "pxr/usd/usd/stage.h"
#include "pxr/usd/usd/prim.h"

namespace Overlay {
    /// Exception-safe bridge around UsdShadeMaterialBindingAPI binding queries.
    class UsdShadeMaterialBindingWrapper {
    public:
        static std::string BindingInfoJSON(
            const pxr::UsdStageRefPtr &stage,
            const std::string &primPath);
    };
}

#endif /* SWIFTUSD_WRAPPERS_USDSHADEMATERIALBINDINGWRAPPER_H */
