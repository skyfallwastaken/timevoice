# Benchmarks Inertia page loads as the seeded bench user (run script/perf/seed.rb first).
# Usage: bin/rails runner script/perf/bench.rb [label] [runs]
# Prints median/p90 ms, SQL query counts, repeated query shapes (N+1 hints) and JSON payload
# sizes per page, and writes tmp/perf-<label>.json.
require "zlib"
require "json"

label = ARGV[0] || "run"
runs = (ARGV[1] || 15).to_i
abort "runs must be positive" unless runs.positive?
Rails.logger.level = :warn
ActiveRecord::Base.logger = nil
# Inertia's devtools record and redact every response in development only.
InertiaRails.configuration.devtools.enabled = false

ws = Workspace.find_by!(name: "Acme Studio")
invoice = ws.invoices.joins(:invoice_lines).group(:id).order(Arel.sql("count(invoice_lines.id) desc")).first

ApplicationController.prepend(Module.new do
  define_method(:current_user) { @current_user ||= User.find_by(email: "bench@example.com") }
end)

h = ws.hashid
pages = {
  "timer (list, this_week)" => "/#{h}/timer?view=list",
  "timer (list, all)" => "/#{h}/timer?view=list&range=all",
  "timer (calendar)" => "/#{h}/timer?view=calendar",
  "clients" => "/#{h}/clients",
  "projects" => "/#{h}/projects",
  "tags" => "/#{h}/tags",
  "reports (week)" => "/#{h}/reports",
  "reports (year)" => "/#{h}/reports?start_date=#{1.year.ago.to_date}&end_date=#{Date.current}",
  "invoices" => "/#{h}/invoices",
  "invoice show" => "/#{h}/invoices/#{invoice.hashid}",
  "settings workspace" => "/#{h}/settings/workspace"
}

headers = {
  "X-Inertia" => "true",
  "X-Inertia-Version" => InertiaRails.configuration.version.to_s,
  "User-Agent" => "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0 Safari/537.36"
}

session = ActionDispatch::Integration::Session.new(Rails.application)
session.host! "localhost"

queries = []
ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
  next if payload[:name] == "SCHEMA" || payload[:sql].start_with?("PRAGMA")
  queries << [ payload[:sql], payload[:cached] ]
end

results = pages.to_h do |name, path|
  2.times { session.get(path, headers: headers) }
  raise "#{name}: HTTP #{session.response.status}" unless session.response.status == 200

  times = Array.new(runs) do
    queries.clear
    t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    session.get(path, headers: headers)
    (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t) * 1000
  end.sort
  body = session.response.body
  File.write(File.join(ENV["DUMP"], "#{name.parameterize}.json"), body) if ENV["DUMP"]
  sql = queries.reject(&:last).map(&:first)
  repeated = sql.map { |q| q.gsub(/\b\d+\b/, "?").gsub(/'[^']*'/, "?") }.tally.select { |_, c| c > 2 }
  [ name, {
    median_ms: times[times.size / 2].round(1),
    p90_ms: times[(times.size * 0.9).floor.clamp(0, times.size - 1)].round(1),
    queries: sql.size,
    bytes: body.bytesize,
    gzip_bytes: Zlib.gzip(body).bytesize,
    prop_bytes: JSON.parse(body)["props"].transform_values { |v| v.to_json.bytesize }.select { |_, b| b > 2000 },
    repeated: repeated.map { |q, c| "#{c}x #{q[0, 140]}" }
  } ]
end

File.write(Rails.root.join("tmp/perf-#{label}.json"), JSON.pretty_generate(results))
printf("%-26s %9s %9s %8s %10s %10s\n", "page", "median ms", "p90 ms", "queries", "bytes", "gzip")
results.each { |name, r| printf("%-26s %9.1f %9.1f %8d %10d %10d\n", name, r[:median_ms], r[:p90_ms], r[:queries], r[:bytes], r[:gzip_bytes]) }
results.each do |name, r|
  puts "#{name}: props>2KB #{r[:prop_bytes]}" if r[:prop_bytes].any?
  r[:repeated].each { |l| puts "   #{l}" }
end
