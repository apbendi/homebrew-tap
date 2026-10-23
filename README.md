# QEMU with HiDPI display fixes for Mac

This [Homebrew](https://brew.sh) tap installs **qemu-hidpi**: QEMU 11.1.2
with two fixes to its Mac display window (the "Cocoa" display) for Retina
and other HiDPI screens.

1. **No more stretched lines when the window is zoomed.** Text and title bars
   near the mouse pointer no longer stretch or squash as the pointer moves.
2. **A sharp window at a sensible size.** A new `scale` setting and new View
   menu items let you pick an exact zoom, such as each guest pixel showing as
   exactly 2x2 screen pixels.

> [!IMPORTANT]
> This is an **unofficial** build. It is not made, reviewed or supported by
> the QEMU project, and the changes were written with an AI assistant, which
> means they can't be contributed to QEMU itself. See
> [Why isn't this in QEMU?](#why-isnt-this-in-qemu)

## Are you affected?

You probably are if all of these are true:

- **You use QEMU 11.0 or newer on a Mac**, with its own window. That's the
  default display on macOS, or `-display cocoa`. Apps that run QEMU inside
  their own window, such as UTM, use their own display code and aren't
  affected.
- **Your screen is HiDPI.** That includes every built-in MacBook and iMac
  screen, Apple's external displays, and most 4K and 5K monitors. To check,
  run this in Terminal:

  ```sh
  system_profiler SPDisplaysDataType | grep -E "Resolution|UI Looks like"
  ```

  If "UI Looks like" is smaller than "Resolution" (for example, Resolution
  5120 x 2880 and UI Looks like 2560 x 1440), the screen is HiDPI.
- **You've seen at least one of these:**
  - The QEMU window is about half the size it was before 11.0. For example, a
    1024x768 guest shows in a window only 512x384 points across.
  - With **View > Zoom To Fit** turned on and the window resized, a band of
    text or a title bar near the mouse pointer gets taller or shorter as the
    pointer moves over it. Resizing the window makes it look normal again,
    until you move the mouse.
  - There's no way to get the window back to an exact 2x size, so zoomed
    pixels look uneven or blurry.

## What it changes

**Stretched lines.** When the guest updates part of its screen, for example
the area around the mouse pointer, QEMU redraws just that part. At an
in-between zoom, it cut that part out of the screen image slightly bigger than
the space it was drawn back into, so it came out squashed. Now every update is
drawn exactly the same way as a full redraw, so nothing stretches at any zoom.

**Exact window size.** Since QEMU 11.0, each guest pixel is one physical
screen pixel, which on a Retina screen makes the window half the size it used
to be. The new `scale` setting chooses how big each guest pixel is:

```sh
qemu-system-x86_64 -display cocoa,scale=1 ...
```

On a Retina screen, `scale=1` shows each guest pixel as exactly 2x2 screen
pixels: the size QEMU used before 11.0, and still perfectly sharp. The View
menu also gets **Zoom In** (⌘=), **Zoom Out** (⌘−) and **Reset Zoom** (⌘0),
which step between sharp sizes only.

If you don't use `scale` or the new menu items, qemu-hidpi behaves exactly
like the official 11.1.2, apart from the redraw fix.

## Install with Homebrew

You need [Homebrew](https://brew.sh). Then run:

```sh
brew install apbendi/tap/qemu-hidpi
```

If a prebuilt version is available for your Mac, this takes a minute or two.
Otherwise Homebrew builds QEMU from source: that took about a minute and a
half on an M4 Max, and takes longer on smaller or older Macs.

qemu-hidpi installs **alongside** Homebrew's regular `qemu` rather than
replacing it, so tools that depend on `qemu`, such as Lima and Colima, keep
working. That means its commands aren't on your PATH by default. To use them
in the current Terminal window:

```sh
export PATH="$(brew --prefix)/opt/qemu-hidpi/bin:$PATH"
```

To use them in every new Terminal window, add that line to your shell profile
instead:

```sh
echo 'export PATH="$(brew --prefix)/opt/qemu-hidpi/bin:$PATH"' >> ~/.zprofile
```

To check that you're running the patched version, look for `scale` in the
Cocoa display options:

```sh
qemu-system-x86_64 -h | grep "scale="
```

To update or remove it later:

```sh
brew upgrade qemu-hidpi
brew uninstall qemu-hidpi
```

## Build it yourself

If you'd rather not use the tap, you can build the same code from source.
Every command here runs in Terminal.

```sh
# Apple's command line developer tools, if you don't have them yet
xcode-select --install

# Build tools and libraries
brew install python ninja pkgconf glib pixman libslirp

# Get the patched source for this release (a shallow copy, so the download
# stays small). Git prints a note about "detached HEAD"; that's expected.
git clone --depth 1 --branch v11.1.2-hidpi https://github.com/apbendi/qemu.git qemu-hidpi
cd qemu-hidpi

# Configure for the machines you want, then build
./configure --target-list=x86_64-softmmu,aarch64-softmmu \
    --enable-cocoa --enable-slirp --disable-docs
make -j"$(sysctl -n hw.ncpu)"
```

Replace the `--target-list` entries with the machines you emulate, for
example `i386-softmmu`, `arm-softmmu`, `ppc-softmmu`, `m68k-softmmu` or
`riscv64-softmmu`. Leave out `--target-list` entirely to build every machine,
which takes longer.

Run QEMU from the `build` folder, which is where it looks for its firmware
files:

```sh
./build/qemu-system-x86_64 -display cocoa,scale=1 ...
```

## Using it

### The `scale` setting

Add `scale=` to the `-display cocoa` option. It sets how many points (macOS's
screen units) each guest pixel takes up while Zoom To Fit is off. Allowed
values are 0.25 to 4.

| Setting | On a Retina screen | On a standard screen |
|---|---|---|
| (not set) | 1x1 screen pixels, the 11.x default | 1x1 screen pixels |
| `scale=0.5` | 1x1 screen pixels | half size, not sharp |
| `scale=1` | 2x2 screen pixels, the pre-11.0 size | 1x1 screen pixels |
| `scale=1.5` | 3x3 screen pixels | 1.5x, not sharp |
| `scale=2` | 4x4 screen pixels | 2x2 screen pixels |

Values that give whole screen pixels per guest pixel are perfectly sharp:
multiples of 0.5 on a Retina screen, and whole numbers on a standard screen.
A large scale can make the window taller than your screen.

The window keeps the same scale when the guest changes resolution, for example
from a text-mode boot menu to a graphical desktop.

### The View menu

- **Zoom In** (⌘=) and **Zoom Out** (⌘−) make each guest pixel one screen
  pixel bigger or smaller, so every size they reach is sharp. Zoom In stops
  before the window would outgrow your screen, and Zoom Out stops at one screen
  pixel per guest pixel. At those limits the item is greyed out.
- **Reset Zoom** (⌘0) goes back to your `scale` setting, or to the default if
  you didn't set one.
- **Zoom To Fit** still lets you resize the window freely, now without
  stretched lines. Any of the zoom items above turns it off and snaps the
  window to an exact size.
- The keyboard shortcuts work while QEMU isn't capturing your mouse and
  keyboard. If it is, press Ctrl+Option+G to release them, or use the menu.

## Why isn't this in QEMU?

The QEMU project [does not accept contributions that include or are derived
from AI-generated
content](https://www.qemu.org/docs/master/devel/code-provenance.html#use-of-ai-generated-content),
because the copyright and licensing of that content are unclear. These changes
were written with an AI assistant (Claude Code), so they can't be submitted to
QEMU, and the commit messages say so. Please don't send them to the QEMU
project.

QEMU [issue #3434](https://gitlab.com/qemu-project/qemu/-/work_items/3434)
tracks the smaller window on Retina screens since 11.0, and [a comment
there](https://gitlab.com/qemu-project/qemu/-/work_items/3434#note_3394678632)
describes the stretching and asks for an exact zoom setting. If the QEMU
developers fix these themselves, this tap won't be needed any more.

**Reporting bugs:** if something goes wrong with qemu-hidpi, check whether it
also happens with Homebrew's regular `qemu` before reporting it to the QEMU
project. If it only happens with qemu-hidpi, please [open an issue
here](https://github.com/apbendi/homebrew-tap/issues) instead.

## Source code and license

QEMU is licensed under the GNU General Public License, version 2. The formula
builds the official QEMU 11.1.2 source from
[download.qemu.org](https://download.qemu.org/) with two patches:

- [ui/cocoa: Fix squashed dirty-rect redraws at non-integer
  zoom](https://github.com/apbendi/qemu/commit/1fdc2138947e06d39fdd8d0700a782a4a1970ef3)
- [ui/cocoa: Add scale option and exact zoom menu
  items](https://github.com/apbendi/qemu/commit/a8d76c76e94dfaba0cbedbb0f1ee8a7a3c569a66)

The full patched source for this release is the
[`v11.1.2-hidpi`](https://github.com/apbendi/qemu/tree/v11.1.2-hidpi) tag of
[apbendi/qemu](https://github.com/apbendi/qemu). The tag for each release is
kept permanently. The patches are developed on the
[`cocoa-zoom-strips`](https://github.com/apbendi/qemu/tree/cocoa-zoom-strips)
branch, which moves to each new QEMU release. Each commit message explains its
change in detail, including how it was tested.

QEMU is a trademark of Fabrice Bellard. This tap is not affiliated with or
endorsed by the QEMU project.

Maintaining this tap? See [MAINTAINING.md](MAINTAINING.md).
