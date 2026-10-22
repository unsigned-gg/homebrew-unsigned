class Herdr < Formula
  desc "Runtime your coding agents live on (unsigned-gg build)"
  homepage "https://github.com/unsigned-gg/herdr"
  version "0.9.5.1"
  license "Apache-2.0"

  depends_on :linux

  on_linux do
    on_intel do
      url "https://github.com/unsigned-gg/herdr/releases/download/ug-v0.9.5.1/herdr-linux-x86_64"
      sha256 "14d9e8bc8b4a9e0118d77c32266f76d461f09b40342eb23752960bd89f59929d"
    end
    on_arm do
      url "https://github.com/unsigned-gg/herdr/releases/download/ug-v0.9.5.1/herdr-linux-aarch64"
      sha256 "17d7536f2da50859523680ef279dffcac8e4a235f4e46fe8da6c2ec44141897c"
    end
  end

  def install
    bin.install Dir["herdr-linux-*"].first => "herdr"
  end

  test do
    # Release ug-v<upstream>.<n> carries upstream's version string.
    assert_match "herdr #{version.major_minor_patch}", shell_output("#{bin}/herdr --version")
  end
end
