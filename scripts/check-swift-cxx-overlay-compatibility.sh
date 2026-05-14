#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python_bin="/usr/bin/python3"
if [[ ! -x "$python_bin" ]]; then
  python_bin="python3"
fi

"$python_bin" - "$repo_root" <<'PY'
import pathlib
import re
import subprocess
import sys

repo_root = pathlib.Path(sys.argv[1])
sequence = repo_root / "source/SwiftOverlay/Sequence.swift"
vt_array_protocol = repo_root / "source/SwiftOverlay/VtArrayProtocol.swift"
usd_prim_range = repo_root / "source/SwiftOverlay/UsdPrimRange.swift"
sdf_proxy_types_iterator = repo_root / "source/Wrappers/SdfProxyTypesIteratorWrapper.swift"
vt_header = repo_root / "source/SwiftOverlay/VtDictionary.h"
vt_impl = repo_root / "source/SwiftOverlay/VtDictionary.cpp"
generated_modulemap = repo_root / "swift-package/Sources/_OpenUSD_SwiftBindingHelpers/include/module.modulemap"
modulemap_generator = repo_root / "scripts/make-swift-package/Sources/SwiftPackage.swift"
package_manifest = repo_root / "Package.swift"
package_template = repo_root / "source/Package.swift.in"


def fail(message: str) -> None:
    print(f"Swift/C++ overlay compatibility check failed: {message}", file=sys.stderr)
    sys.exit(1)


def read(path: pathlib.Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError:
        fail(f"missing expected file: {path}")


def run(args: list[str]) -> str:
    completed = subprocess.run(
        args,
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    return completed.stdout.strip()


sequence_text = read(sequence)
vt_array_protocol_text = read(vt_array_protocol)
usd_prim_range_text = read(usd_prim_range)
sdf_proxy_types_iterator_text = read(sdf_proxy_types_iterator)
header_text = read(vt_header)
impl_text = read(vt_impl)
modulemap_text = read(generated_modulemap)
modulemap_generator_text = read(modulemap_generator)
package_manifest_text = read(package_manifest)
package_template_text = read(package_template)

swiftc = run(["xcrun", "--find", "swiftc"])
toolchain_root = pathlib.Path(swiftc).parents[2]
cxx_interface = (
    toolchain_root
    / "usr/lib/swift/macosx/Cxx.swiftmodule/arm64-apple-macos.swiftinterface"
)
if not cxx_interface.is_file():
    fail(f"could not find active Cxx.swiftinterface at {cxx_interface}")

cxx_text = read(cxx_interface)

if "public protocol CxxDictionary" not in cxx_text:
    fail("active toolchain Cxx module does not expose CxxDictionary")

if "module _OpenUSD_SwiftBindingHelpers {\n    requires cplusplus" not in modulemap_text:
    fail("_OpenUSD_SwiftBindingHelpers module map must require cplusplus for Xcode explicit module scanning")
if '"    requires cplusplus"' not in modulemap_generator_text:
    fail("make-swift-package must preserve requires cplusplus in regenerated module maps")
if '.unsafeFlags(["-Xcc", "-fcxx-modules"])' not in package_manifest_text:
    fail("Package.swift must pass -fcxx-modules through Swift settings for Xcode explicit module scanning")
if '.unsafeFlags(["-Xcc", "-fcxx-modules"])' not in package_template_text:
    fail("Package.swift.in must preserve -fcxx-modules when Package.swift is regenerated")
if 'cxxSettings: [\n                    .unsafeFlags(["-fcxx-modules"])' not in package_manifest_text:
    fail("_OpenUSD_SwiftBindingHelpers target must pass -fcxx-modules through C++ settings")
if 'cxxSettings: [\n                    .unsafeFlags(["-fcxx-modules"])' not in package_template_text:
    fail("Package.swift.in must preserve _OpenUSD_SwiftBindingHelpers -fcxx-modules C++ settings")
if '"-Xswiftc", "-Xcc", "-Xswiftc", "-fcxx-modules"' not in modulemap_generator_text:
    fail("make-swift-package extraArgs must preserve -fcxx-modules for regenerated CLI package settings")

dictionary_protocol = re.search(
    r"public protocol CxxDictionary\b(?P<body>.*?)(?=\nextension Cxx\.CxxDictionary\b)",
    cxx_text,
    re.S,
)
if not dictionary_protocol:
    fail("could not parse CxxDictionary requirements from active toolchain")

dictionary_body = dictionary_protocol.group("body")

required_markers = [
    "func __findUnsafe",
    "mutating func __findMutatingUnsafe",
    "mutating func __insertUnsafe",
    "mutating func erase",
    "mutating func __eraseUnsafe",
    "func __beginUnsafe",
    "func __endUnsafe",
    "mutating func __endMutatingUnsafe",
]
missing_protocol_markers = [
    marker for marker in required_markers if marker not in dictionary_body
]
if missing_protocol_markers:
    fail(
        "active toolchain CxxDictionary shape changed; missing expected markers: "
        + ", ".join(missing_protocol_markers)
    )

extension_start = re.search(
    r"extension pxr\.VtDictionary(?:\s*:\s*(?P<conformances>[^{]+))?\s*\{",
    sequence_text,
)
if not extension_start:
    fail("could not find pxr.VtDictionary overlay extension")
extension_end = sequence_text.find("extension pxr.VtDictionary.const_iterator", extension_start.end())
if extension_end == -1:
    fail("could not find end of pxr.VtDictionary overlay extension")

conformances = {
    conformance.strip()
    for conformance in (extension_start.group("conformances") or "").split(",")
    if conformance.strip()
}
body = sequence_text[extension_start.end():extension_end]

if "CxxDictionary" in conformances or "CxxSequence" in conformances:
    fail(
        "pxr.VtDictionary must not declare CxxDictionary or CxxSequence; Swift "
        "6.3 imports VtDictionary.value_type in a shape that cannot satisfy "
        "CxxDictionary's Element/Key equality requirements"
    )

if "public protocol OpenUSD_Sequence: Sequence" in sequence_text:
    fail("OpenUSD_Sequence must not inherit Swift Sequence under Swift 6.3.2 C++ interop")
if "public struct OpenUSDSequence<S: __Overlay.OpenUSD_Sequence>: Sequence" not in sequence_text:
    fail("OpenUSD ranges must expose explicit Swift wrapper sequences")
if "extension pxr.SdfZipFile: Sequence" in read(repo_root / "source/Wrappers/SdfZipFileIteratorWrapper.swift"):
    fail("SdfZipFile must expose explicit swiftSequence instead of direct Swift Sequence conformance")
if "public protocol VtArray_CustomStringConvertible: CustomStringConvertible, Sequence" in vt_array_protocol_text:
    fail("VtArray description must not require broad Swift Sequence conformance")
if "public protocol VtArray_Sequence: Sequence" in vt_array_protocol_text:
    fail("VtArray_Sequence must not inherit Swift Sequence under Swift 6.3.2 C++ interop")
if "for x in self" in read(repo_root / "source/SwiftOverlay/Codable.swift"):
    fail("VtArray Codable implementations must use indexed access, not Sequence iteration")
if "extension pxr.UsdPrimRange: Sequence" in usd_prim_range_text:
    fail("UsdPrimRange must expose explicit swiftSequence instead of direct Swift Sequence conformance")
if "public protocol SdfProxyTypesSequenceProtocol: Sequence" in sdf_proxy_types_iterator_text:
    fail("Sdf proxy helper protocols must not force imported C++ proxy types through Swift Sequence")

required_witnesses = [
    "public func __beginUnsafe() -> Self.RawIterator",
    "public func __endUnsafe() -> Self.RawIterator",
    "public mutating func __insertUnsafe",
    "public func __findUnsafe",
    "public mutating func __findMutatingUnsafe",
    "public mutating func erase(_ key: Self.Key) -> Self.Size",
    "public mutating func __eraseUnsafe",
    "public mutating func __endMutatingUnsafe",
]
missing_witnesses = [witness for witness in required_witnesses if witness not in body]
if missing_witnesses:
    fail("pxr.VtDictionary is missing concrete helpers: " + ", ".join(missing_witnesses))

required_shims = [
    (
        "pxr::VtDictionary::const_iterator begin(const pxr::VtDictionary& d)",
        r"pxr::VtDictionary::const_iterator\s+__Overlay::begin\s*\(",
    ),
    (
        "pxr::VtDictionary::const_iterator end(const pxr::VtDictionary& d)",
        r"pxr::VtDictionary::const_iterator\s+__Overlay::end\s*\(",
    ),
    (
        "pxr::VtDictionary::iterator endMutating(pxr::VtDictionary* d)",
        r"pxr::VtDictionary::iterator\s+__Overlay::endMutating\s*\(",
    ),
    (
        "pxr::VtDictionary::size_type erase(pxr::VtDictionary* d, const std::string& key)",
        r"pxr::VtDictionary::size_type\s+__Overlay::erase\s*\(",
    ),
    (
        "void setValue(pxr::VtDictionary* d, const std::string& key, const pxr::VtValue& value)",
        r"void\s+__Overlay::setValue\s*\(",
    ),
]
missing_header_shims = [
    declaration for declaration, _ in required_shims if declaration not in header_text
]
missing_impl_shims = [
    declaration
    for declaration, implementation_pattern in required_shims
    if not re.search(implementation_pattern, impl_text)
]
if missing_header_shims:
    fail("VtDictionary.h is missing shims: " + ", ".join(missing_header_shims))
if missing_impl_shims:
    fail("VtDictionary.cpp is missing implementations for required shims")

print("Swift/C++ overlay compatibility check passed")
PY
