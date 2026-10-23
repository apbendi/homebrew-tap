# Homebrew's qemu formula, plus two unofficial changes to QEMU's Cocoa display
# for HiDPI (Retina) Macs. The changes are not part of upstream QEMU; see the
# README for what they do and why they can't be submitted upstream.
class QemuHidpi < Formula
  desc "Generic machine emulator with HiDPI fixes for the Cocoa display"
  homepage "https://github.com/apbendi/homebrew-tap"
  url "https://download.qemu.org/qemu-11.1.2.tar.xz"
  sha256 "731b5681e4bb18be313231579b8efd0296c5b015fa36dc533874b639ba838016"
  license "GPL-2.0-only"

  livecheck do
    url "https://www.qemu.org/download/"
    regex(/href=.*?qemu[._-]v?(\d+(?:\.\d+)+)\.t/i)
  end

  keg_only "it installs the same commands as Homebrew's qemu"

  depends_on "bison" => :build # >= 3.0
  depends_on "libtool" => :build
  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkgconf" => :build
  depends_on "python-setuptools" => :build
  depends_on "python@3.15" => :build # keep aligned with meson
  depends_on "spice-protocol" => :build

  depends_on "capstone"
  depends_on "dtc"
  depends_on "glib"
  depends_on "gnutls"
  depends_on "jpeg-turbo"
  depends_on "libpng"
  depends_on "libslirp"
  depends_on "libssh"
  depends_on "libusb"
  depends_on "lzo"
  depends_on :macos
  depends_on "ncurses"
  depends_on "pixman"
  depends_on "snappy"
  depends_on "vde"
  depends_on "zstd"

  uses_from_macos "flex" => :build
  uses_from_macos "bzip2"

  # Fix stretched redraws when the Cocoa display is zoomed to a non-integer size
  patch do
    url "https://github.com/apbendi/qemu/commit/1fdc2138947e06d39fdd8d0700a782a4a1970ef3.patch?full_index=1"
    sha256 "d8e05038d849e69afe6344aa30e833a1f1a9640be163cda9b0ef878ee27d30d1"
  end

  # Add -display cocoa,scale=N and exact Zoom In/Zoom Out/Reset Zoom menu items
  patch do
    url "https://github.com/apbendi/qemu/commit/a8d76c76e94dfaba0cbedbb0f1ee8a7a3c569a66.patch?full_index=1"
    sha256 "c243e38e4b0fdacea79f6f606367c577fdbc7c627485634c3527aac9eff30661"
  end

  deny_network_access!

  def install
    ENV["LIBTOOL"] = "glibtool"

    # Remove wheels unless explicitly permitted. Currently this:
    # * removes `meson` so that brew `meson` is always used
    # * keeps `pycotap` and `qemu_qmp` which are pure-python "none-any" wheels
    rm(Dir["python/wheels/*"] - Dir["python/wheels/{pycotap,qemu_qmp}-*-none-any.whl"])

    # Python 3.15 no longer bundles `wheel` and setuptools builds wheels without it
    inreplace "pythondeps.toml", /^"wheel" = .*\n/, ""

    args = %W[
      --prefix=#{prefix}
      --cc=#{ENV.cc}
      --host-cc=#{ENV.cc}
      --disable-bsd-user
      --disable-download
      --disable-guest-agent
      --enable-slirp
      --enable-capstone
      --enable-curses
      --enable-fdt=system
      --enable-libssh
      --enable-vde
      --enable-virtfs
      --enable-zstd
      --extra-cflags=-DNCURSES_WIDECHAR=1
      --disable-sdl
      --disable-gtk
      --enable-cocoa
    ]

    # Sharing Samba directories in QEMU requires the samba.org smbd which is
    # incompatible with the macOS-provided version. This will lead to
    # silent runtime failures, so we set it to a Homebrew path in order to
    # obtain sensible runtime errors. This will also be compatible with
    # Samba installations from external taps.
    args << "--smbd=#{HOMEBREW_PREFIX}/sbin/samba-dot-org-smbd"

    # The arm64 HVF backend needs the macOS 15 SDK for its EL2 sysregs and vGIC
    args << "--disable-hvf" if Hardware::CPU.arm? && MacOS.version <= :sonoma

    # Starting in Golden Gate, ParavirtualizedGraphics.framework is present but
    # largely unusable. Remove once QEMU configure script is able to correctly
    # handle this.
    #
    # See https://patchew.org/QEMU/20260826203700.39057-1-dude@angrygoose.dev/.
    args << "--disable-pvg" if MacOS.version >= :golden_gate

    system "./configure", *args
    system "make", "V=1", "install"
  end

  def caveats
    <<~EOS
      This is an unofficial build of QEMU. On a Retina display, this gives a
      window at the size QEMU used before 11.0, with each guest pixel shown as
      exactly 2x2 screen pixels:
        -display cocoa,scale=1

      Before reporting a bug to the QEMU project, check that it also happens
      with Homebrew's regular qemu.
    EOS
  end

  test do
    archs = %w[
      aarch64 alpha arm avr hppa i386 loongarch64 m68k microblaze mips
      mips64 mips64el mipsel or1k ppc ppc64 riscv32 riscv64 rx
      s390x sh4 sh4eb sparc sparc64 tricore x86_64 xtensa xtensaeb
    ]
    archs.each do |guest_arch|
      assert_match version.to_s, shell_output("#{bin}/qemu-system-#{guest_arch} --version")
    end

    # The patched Cocoa display accepts the scale option
    assert_match "[,scale=<number>]", shell_output("#{bin}/qemu-system-x86_64 -h")

    system bin/"qemu-img", "create", "-f", "qcow2", "test.qcow2", "1440k"
    assert_match "file format: qcow2", shell_output("#{bin}/qemu-img info test.qcow2")

    system bin/"qemu-img", "convert", "-O", "raw", "test.qcow2", "test.img"
    assert_match "file format: raw", shell_output("#{bin}/qemu-img info test.img")

    # Verify that we haven't clobbered the signature on the qemu-system-x86_64 binary
    output = shell_output("codesign --verify --verbose #{bin}/qemu-system-x86_64 2>&1")
    assert_match "valid on disk", output
    assert_match "satisfies its Designated Requirement", output
  end
end
