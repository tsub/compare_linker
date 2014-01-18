require "sinatra/base"
require "compare_linker"
require "compare_linker/webhook_payload"

class CompareLinker
  class RackApp < Sinatra::Base
    get "/" do
      ENV["URL"]
    end

    post "/webhook" do
      payload = CompareLinker::WebhookPayload.new(params["payload"])
      if payload.action == "opened"
        compare_linker = CompareLinker.new(payload.repo_full_name, payload.pr_number)
        compare_links = compare_linker.make_compare_link.join("\n")
        comment_url = compare_linker.add_comment(payload.repo_full_name, payload.pr_number, compare_links)
        comment_url
      end
    end
  end
end
