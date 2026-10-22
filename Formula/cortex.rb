require_relative "../lib/github_private_release_download_strategy"

class Cortex < Formula
  desc "Cerebral agent mesh CLI"
  homepage "https://github.com/cerebral-work/cortex"
  license :cannot_represent

  on_macos do
    on_intel do
      url "https://github.com/cerebral-work/cortex/releases/download/v1.0.0-rc.46/cortex-v1.0.0-rc.46-x86_64-apple-darwin.tar.gz",
          using: GitHubPrivateReleaseDownloadStrategy
      sha256 "e5f0e606acd742ac1ef1e892f26f10888eb4460bf9a76003deb4bf56f1ff5062"
    end
    on_arm do
      url "https://github.com/cerebral-work/cortex/releases/download/v1.0.0-rc.46/cortex-v1.0.0-rc.46-aarch64-apple-darwin.tar.gz",
          using: GitHubPrivateReleaseDownloadStrategy
      sha256 "899a5f24acb571184042fe985e1e0873c412d084a6a3f7c661b2bcefe0e93a36"
    end
  end

  on_linux do
    on_intel do
      url "https://github.com/cerebral-work/cortex/releases/download/v1.0.0-rc.46/cortex-v1.0.0-rc.46-x86_64-unknown-linux-musl.tar.gz",
          using: GitHubPrivateReleaseDownloadStrategy
      sha256 "541ebf9e36a14d72b87a944afaa60b70a2cf2545be26759518b23fca0d1abed8"
    end
    on_arm do
      url "https://github.com/cerebral-work/cortex/releases/download/v1.0.0-rc.46/cortex-v1.0.0-rc.46-aarch64-unknown-linux-musl.tar.gz",
          using: GitHubPrivateReleaseDownloadStrategy
      sha256 "53d4d0260124f0b65f7077e6051f5093786341afc1963c5a9c35294d388967d0"
    end
  end

  def install
    bin.install "cortex"
  end

  test do
    assert_match "cortex #{version}", shell_output("#{bin}/cortex --version")
  end
end
