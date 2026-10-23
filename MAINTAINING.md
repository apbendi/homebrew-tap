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

Until the first bottles are published, `brew install` builds from source,
which works but takes longer.

## Updating to a new QEMU release

When autobump opens a pull request, or by hand:

1. Rebase the `cocoa-zoom-strips` branch of apbendi/qemu onto the new release
   tag, resolving any conflicts in `ui/cocoa.m`, `qapi/ui.json` and
   `qemu-options.hx`. Build it and check the window sizes and View menu items
   before pushing.
2. Point the two `patch` blocks at the rebased commits. Download each
   `https://github.com/apbendi/qemu/commit/<sha>.patch?full_index=1` and use
   `shasum -a 256` on it for the new `sha256`.
3. Copy any changes to dependencies, `install` or `test` from Homebrew's qemu
   formula for the same version.
4. Check it locally, then open the pull request:

   ```sh
   brew style apbendi/tap
   brew audit --strict --formula apbendi/tap/qemu-hidpi
   brew install --build-from-source apbendi/tap/qemu-hidpi
   brew test apbendi/tap/qemu-hidpi
   ```

5. Update the version and patch links in README.md.

If the QEMU project fixes these problems itself, remove the corresponding
patch, and retire the tap once both are fixed upstream.
