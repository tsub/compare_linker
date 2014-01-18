require_relative "lib/compare_linker"
require_relative "lib/compare_linker/webhook_payload"

payload = CompareLinker::WebhookPayload.new(ENV["payload"])
exit if payload.action != "opened"

compare_linker = CompareLinker.new(payload.repo_full_name, payload.pr_number)
compare_links = compare_linker.make_compare_link.join("\n")
puts compare_linker.add_comment(repo_full_name, pr_number, compare_links)
