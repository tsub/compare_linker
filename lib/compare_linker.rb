require "octokit"
require_relative "compare_linker/formatter/base"
require_relative "compare_linker/formatter/text"
require_relative "compare_linker/formatter/markdown"
require_relative "compare_linker/gem_dictionary"
require_relative "compare_linker/github_link_finder"
require_relative "compare_linker/github_tag_finder"
require_relative "compare_linker/lockfile_comparator"
require_relative "compare_linker/lockfile_fetcher"

class CompareLinker
  attr_reader :repo_full_name, :pr_number, :compare_links
  attr_accessor :formatter

  def initialize(repo_full_name, pr_number)
    @repo_full_name = repo_full_name
    @pr_number = pr_number
    @formatter = Formatter::Text.new
  end

  def make_compare_links
    if requested_repository_octokit.pull_request_files(repo_full_name, pr_number).find { |resource| resource.filename == "Gemfile.lock" }
      pull_request = requested_repository_octokit.pull_request(repo_full_name, pr_number)

      fetcher = LockfileFetcher.new(requested_repository_octokit)
      old_lockfile = fetcher.fetch(repo_full_name, pull_request.base.sha)
      new_lockfile = fetcher.fetch(repo_full_name, pull_request.head.sha)

      make_compare_links_from_lockfiles(old_lockfile, new_lockfile)
    end
  end

  def make_compare_links_from_lockfiles(old_lockfile, new_lockfile)
    comparator = LockfileComparator.new
    comparator.compare(old_lockfile, new_lockfile)
    @compare_links = comparator.updated_gems.map { |gem_name, gem_info|
      if gem_info[:owner].nil?
        finder = GithubLinkFinder.new(octokit, gem_dictionary)
        finder.find(gem_name)
        gem_info[:homepage_uri] = finder.homepage_uri
        if finder.repo_owner.nil?
          formatter.format(gem_info)
        else
          gem_info[:repo_owner] = finder.repo_owner
          gem_info[:repo_name] = finder.repo_name

          tag_finder = GithubTagFinder.new(octokit, gem_name, finder.repo_full_name)
          old_tag = tag_finder.find(gem_info[:old_ver])
          new_tag = tag_finder.find(gem_info[:new_ver])

          if old_tag && new_tag
            gem_info[:old_tag] = old_tag.name
            gem_info[:new_tag] = new_tag.name
            formatter.format(gem_info)
          else
            formatter.format(gem_info)
          end
        end
      else
        formatter.format(gem_info)
      end
    }
    @compare_links
  end

  def add_comment(repo_full_name, pr_number, compare_links)
    res = requested_repository_octokit.add_comment(
      repo_full_name,
      pr_number,
      compare_links
    )
    res[:html_url]
  end

  private

  def requested_repository_octokit
    enterprise_octokit || octokit
  end

  def enterprise_octokit
    @enterprise_octokit ||=
      if ENV["ENTERPRISE_OCTOKIT_ACCESS_TOKEN"] && ENV['ENTERPRISE_OCTOKIT_API_ENDPOINT']
        Octokit::Client.new(access_token: ENV["ENTERPRISE_OCTOKIT_ACCESS_TOKEN"],
                            api_endpoint: ENV["ENTERPRISE_OCTOKIT_API_ENDPOINT"])
      end
  end

  def octokit
    @octokit ||= Octokit::Client.new(access_token: ENV["OCTOKIT_ACCESS_TOKEN"])
  end

  def gem_dictionary
    @gem_dictionary ||= GemDictionary.new
  end
end
