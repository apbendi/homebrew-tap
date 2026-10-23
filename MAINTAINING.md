# Maintaining this tap

## How the pieces fit

- `Formula/qemu-hidpi.rb` is Homebrew's own
  [qemu formula](https://github.com/Homebrew/homebrew-core/blob/HEAD/Formula/q/qemu.rb),
  made keg-only and macOS-only, plus two `patch` blocks that download the
  commits from the
  [`cocoa-zoom-strips`](https://github.com/apbendi/qemu/tree/cocoa-zoom-strips)
  branch of apbendi/qemu.
- `.github/workflows/tests.yml` runs `brew test-bot` on every pull request. It
  builds and tests the formula on macOS 15 and macOS 26 (Apple Silicon) and
  uploads the resulting bottles as workflow artifacts.
- `.github/workflows/publish.yml` ("brew pr-pull") is run by hand. It takes
  the bottles from a green pull request, uploads them to a GitHub release in
  this repository, adds the `bottle do` block to the formula, and pushes the
  result to `main`, which closes the pull request.
- `.github/workflows/autobump.yml` checks daily for a new QEMU release and
  opens a pull request that updates `url` and `sha256`.

## Publishing bottles

Always change the formula through a pull request, so that bottles are built:

1. Push the change to a branch and open a pull request.
2. Wait for the "brew test-bot" checks to pass. Building QEMU on GitHub's
   runners takes much longer than on a local Mac.
3. In the Actions tab, run the "brew pr-pull" workflow with the pull request
   number.

On a Mac with no bottle for its macOS version, Homebrew uses the bottle for
the newest older version. With no older bottle either, `brew install` builds
from source, which works but takes longer.

## New macOS versions

Add each new macOS version to the `os` list in `.github/workflows/tests.yml`
once GitHub offers a runner for it (see the
[runner images list](https://github.com/actions/runner-images#available-images)),
for example `os: [ macos-15, macos-26, macos-27 ]`. `brew test-bot` only
builds formulae that a pull request changes, so the new bottle is built with
the next formula change, usually the next QEMU update.

Until then, the previous version's bottle is used. On macOS 27 that works with
one exception. Apple removed parts of the ParavirtualizedGraphics interface
that `qemu-system-aarch64`'s `apple-gfx-mmio` and `apple-gfx-pci` devices use
([QEMU issue 4486](https://gitlab.com/qemu-project/qemu/-/work_items/4486)).
Built on macOS 27, the formula leaves those devices out with `--disable-pvg`,
like Homebrew's qemu. The macOS 26 bottle still includes them, and they will
probably fail when used on macOS 27. This hasn't been tested on macOS 27.

## Updating to a new QEMU release

When autobump opens a pull request, or by hand:

1. Rebase the `cocoa-zoom-strips` branch of apbendi/qemu onto the new release
   tag, resolving any conflicts in `ui/cocoa.m`, `qapi/ui.json` and
   `qemu-options.hx`. Build it and check the window sizes and View menu items
   before pushing.
2. Tag the rebased branch and push the tag, for example:

   ```sh
   git tag -a v11.2.0-hidpi -m "QEMU 11.2.0 with unofficial HiDPI Cocoa display patches"
   git push origin cocoa-zoom-strips --force-with-lease
   git push origin v11.2.0-hidpi
   ```

   Never delete or move an old tag. The rebase leaves the previous commits on no
   branch, and the tag is what keeps them on GitHub. That keeps older versions'
   patch links working and the source for already published bottles available,
   which the GPL requires. If the patches change without a new QEMU release, use
   a new tag such as `v11.1.2-hidpi2` and add `revision 1` to the formula.
3. Point the two `patch` blocks at the new commits. Download each
   `https://github.com/apbendi/qemu/commit/<sha>.patch?full_index=1` and use
   `shasum -a 256` on it for the new `sha256`.
4. Copy any changes to dependencies, `install` or `test` from Homebrew's qemu
   formula for the same version.
5. Check it locally, then open the pull request:

   ```sh
   brew style apbendi/tap
   brew audit --strict --formula apbendi/tap/qemu-hidpi
   brew install --build-from-source apbendi/tap/qemu-hidpi
   brew test apbendi/tap/qemu-hidpi
   ```

6. Update the version, tag and patch links in README.md.

If the QEMU project fixes these problems itself, remove the corresponding
patch, and retire the tap once both are fixed upstream.
