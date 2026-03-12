Private bridge-only OpenUSD headers live under `source/PrivateHeaders`.

These files are not part of SwiftUsd's public C++ surface. They exist so narrow
wrapper code can compile against upstream OpenUSD subsystems that are not yet
exported through the generated include/modulemap surface.

Current use:
- `pxr/usdValidation/usdValidation/*.h`

Source of truth:
- OpenUSD commit `2380a03d09854c6eaca2beed2ec1cfb13ff70963`
- OpenUSD `v26.03`

If SwiftUsd starts exporting `usdValidation` headers directly from the generated
package surface, remove this private copy and point `UsdValidationWrapper` at
the generated headers instead.
