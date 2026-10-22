# typed: false
# frozen_string_literal: true

require "download_strategy"
require "json"
require "tempfile"

# Downloads a release asset of a private GitHub repository through the
# release-asset API, authenticated by HOMEBREW_GITHUB_API_TOKEN.
#
# The token reaches curl only through a header file (`--header @file`, mode
# 0600, deleted after use). It is never on curl's argv, so it never shows in a
# process list or in the command line Homebrew prints when curl fails, and it is
# never part of a URL. curl does not resend the header after the cross-host
# redirect to the signed asset URL.
#
# A formula names the asset by its browser URL and selects this strategy:
#   url "https://github.com/<owner>/<repo>/releases/download/<tag>/<asset>",
#       using: GitHubPrivateReleaseDownloadStrategy
class GitHubPrivateReleaseDownloadStrategy < CurlDownloadStrategy
  URL_PATTERN = %r{\Ahttps://github\.com/([^/]+)/([^/]+)/releases/download/([^/]+)/([^/]+)\z}

  def initialize(url, name, version, **meta)
    super
    @owner, @repo, @tag, @asset = URL_PATTERN.match(url)&.captures
    raise CurlDownloadStrategyError, "not a GitHub release-asset URL: #{url}" unless @asset
  end

  # The browser URL of a private asset is not readable without auth, so nothing
  # is probed before the download: no unauthenticated HEAD request.
  def resolve_url_basename_time_file_size(url, timeout: nil)
    [url, @asset, nil, nil, nil, false]
  end

  private

  def _fetch(url:, resolved_url:, timeout:)
    with_auth_header do
      curl_download "https://api.github.com/repos/#{@owner}/#{@repo}/releases/assets/#{asset_id}",
                    "--header", "Accept: application/octet-stream",
                    to: temporary_path, timeout:
    end
  end

  def asset_id
    release = JSON.parse(curl_output("--header", "Accept: application/vnd.github+json",
                                     "https://api.github.com/repos/#{@owner}/#{@repo}/releases/tags/#{@tag}").stdout)
    asset = release["assets"]&.find { |a| a["name"] == @asset }
    return asset["id"] if asset

    reason = release["message"] || "no asset named #{@asset}"
    raise CurlDownloadStrategyError, "#{@owner}/#{@repo} release #{@tag}: #{reason}"
  end

  def with_auth_header
    token = Homebrew::EnvConfig.github_api_token
    if token.blank?
      raise CurlDownloadStrategyError,
            "#{@owner}/#{@repo} is private: set HOMEBREW_GITHUB_API_TOKEN to a read-only token"
    end
    # curl's --verbose, and options a user curlrc can add, print request headers.
    if Homebrew::EnvConfig.curl_verbose? || Homebrew::EnvConfig.curlrc
      raise CurlDownloadStrategyError,
            "#{@owner}/#{@repo}: unset HOMEBREW_CURL_VERBOSE and HOMEBREW_CURLRC; they would print the token"
    end

    Tempfile.create("brew-github-auth") do |file|
      file.write("Authorization: Bearer #{token}\n")
      file.flush
      @auth_header_file = file.path
      yield
    ensure
      @auth_header_file = nil
    end
  end

  def _curl_args
    args = super
    args += ["--header", "@#{@auth_header_file}"] if @auth_header_file
    args
  end
end
