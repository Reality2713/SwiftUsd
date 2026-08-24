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

import Foundation

/// Combines `.framework` bundles into a `.xcframework` bundle for Apple platforms
struct XCFramework {
    var frameworks: [Framework]
    
    var xcframeworkPath: URL!
    
    var name: String { frameworks.first!.name }
    
    /// Makes an XCFramework from versions of the same framework compiled for different platforms
    init(fsInfo: FileSystemInfo, frameworks: [Framework]) async {
        self.frameworks = frameworks
        
        print("Making XCFramework \(name).xcframework...")
        let xcframeworksDir = fsInfo.swiftUsdPackage.tmpDir.appending(path: "XCFrameworks")
        try! FileManager.default.createDirectory(at: xcframeworksDir, withIntermediateDirectories: true)
        
        xcframeworkPath = xcframeworksDir.appending(component: "\(name).xcframework")
        if FileManager.default.directoryExists(at: xcframeworkPath) {
            print("\(path: xcframeworkPath) already exists, returning early")
            return
        }
        
        var frameworkArguments = [any ShellUtil.Argument]()
        for framework in frameworks {
            let debugSymbolsDir = xcframeworksDir
                .appending(path: "DebugSymbols")
                .appending(path: String(framework.fsInfo.usdInstall.index))
            try! FileManager.default.createDirectory(
                at: debugSymbolsDir,
                withIntermediateDirectories: true
            )
            let debugSymbols = debugSymbolsDir.appending(
                path: "\(framework.name).framework.dSYM"
            )
            if FileManager.default.directoryExists(at: debugSymbols) {
                try! FileManager.default.removeItem(at: debugSymbols)
            }

            // Generate the dSYM after install_name_tool has finalized the
            // framework binary so its UUID exactly matches the shipped slice.
            // The OpenUSD build uses RelWithDebInfo; a Release-only input would
            // produce an empty dSYM and is rejected by the release train gate.
            try! await ShellUtil.runCommandAndWait(
                arguments: ["dsymutil", framework.fsInfo.dylib, "-o", debugSymbols],
                quiet: true
            )
            frameworkArguments.append("-framework")
            frameworkArguments.append(framework.fsInfo.url)
            frameworkArguments.append("-debug-symbols")
            frameworkArguments.append(debugSymbols)
        }
        try! await ShellUtil.runCommandAndWait(arguments: ["xcodebuild", "-create-xcframework"] + frameworkArguments + ["-output", xcframeworkPath],
                                               quiet: true)
    }
}
