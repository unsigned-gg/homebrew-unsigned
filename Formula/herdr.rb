class Herdr < Formula
  desc "Runtime your coding agents live on (unsigned-gg build)"
  homepage "https://github.com/unsigned-gg/herdr"
  license "Apache-2.0"

  depends_on :linux

  # The release's musl archives (herdr at the archive root), static, so they run on glibc and
  # musl hosts alike. Each sha256 equals the release's own <archive>.sha256.
  on_linux do
    on_intel do
      url "https://github.com/unsigned-gg/herdr/releases/download/ug-v0.9.5.2/herdr-ug-v0.9.5.2-x86_64-unknown-linux-musl.tar.gz"
      sha256 "326bce30cb5aee06143ab2f7133e565a3743d00b9e2025b1b9676e21add15c1c"
    end
    on_arm do
      url "https://github.com/unsigned-gg/herdr/releases/download/ug-v0.9.5.2/herdr-ug-v0.9.5.2-aarch64-unknown-linux-musl.tar.gz"
      sha256 "c4a26df50093da3045d6cfdfefc798e42d6cb7bd5bce5043363353e108c55b12"
    end
  end

  def install
    bin.install "herdr"
  end

  test do
    # Release ug-v<upstream>.<n> carries upstream's version string.
    assert_match "herdr #{version.major_minor_patch}", shell_output("#{bin}/herdr --version")
  end
end
