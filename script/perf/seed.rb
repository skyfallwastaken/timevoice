# Seeds a heavy, realistic workspace for benchmarks. Wipes the current env's data.
# Usage: bin/rails runner script/perf/seed.rb
# Bench user bench@example.com: ~3.1k entries over 2 years; 9 users, ~30k entries in total.
require "securerandom"

abort "refusing to seed production" if Rails.env.production?
srand(42)

ActiveRecord::Base.transaction do
  [ InvoiceLine, Invoice, TimeEntryTag, TimeEntry, Tag, Project, Client, InvoiceSetting,
    Invite, Membership, Workspace, User ].each(&:delete_all)
end

now = Time.current
users = [ { name: "Bench User", email: "bench@example.com", google_uid: "bench" } ] +
  8.times.map { |i| { name: "Teammate #{i}", email: "mate#{i}@example.com", google_uid: "mate#{i}" } }
User.insert_all(users.map { |u| u.merge(timezone: "Europe/London", theme: "daydream-dark", created_at: now, updated_at: now) })
user_ids = User.order(:id).pluck(:id)
bench = User.find_by!(email: "bench@example.com")

ws = Workspace.create!(name: "Acme Studio", owner: bench)
other_ws = Workspace.create!(name: "Side Projects", owner: bench)
extra_ws = 4.times.map { |i| Workspace.create!(name: "Workspace #{i}", owner: bench) }
Membership.insert_all(user_ids.each_with_index.map { |uid, i| { user_id: uid, workspace_id: ws.id, role: i.zero? ? "owner" : "member", created_at: now, updated_at: now } })
Membership.insert_all(([ other_ws ] + extra_ws).map { |w| { user_id: bench.id, workspace_id: w.id, role: "owner", created_at: now, updated_at: now } })
bench.update_columns(last_used_workspace_id: ws.id)
InvoiceSetting.create!(workspace: ws, sender_name: "Acme Studio Ltd", sender_address: "1 High St\nLondon", billable_rate_cents: 12_500, notes: "Payment due in **30 days**. Thanks!")

Client.insert_all(15.times.map { |i| { workspace_id: ws.id, name: "Client #{i}", email: "billing#{i}@client.test", billing_address: "#{i} Client Road\nManchester", created_at: now, updated_at: now } })
client_ids = Client.where(workspace_id: ws.id).pluck(:id)
Project.insert_all(40.times.map { |i| { workspace_id: ws.id, name: "Project #{i}", client_id: i < 34 ? client_ids[i % client_ids.size] : nil, color: Project::GRUVBOX_COLORS.sample, billable_default: i.even?, created_at: now, updated_at: now } })
project_ids = Project.where(workspace_id: ws.id).pluck(:id)
Tag.insert_all(60.times.map { |i| { workspace_id: ws.id, name: "tag-#{i}", created_at: now, updated_at: now } })
tag_ids = Tag.where(workspace_id: ws.id).pluck(:id)

words = %w[review fix implement design meeting call refactor deploy debug write docs plan research test sync onboarding invoice support]
user_ids.each do |uid|
  rows = []
  (0...730).each do |d|
    day = (now - d.days).beginning_of_day
    next if day.saturday? || day.sunday?
    cursor = day + 8.hours + rand(60).minutes
    rand(4..8).times do
      dur = rand(10..150).minutes
      rows << { user_id: uid, workspace_id: ws.id, project_id: rand < 0.9 ? project_ids.sample : nil,
                description: "#{words.sample.capitalize} #{words.sample} #{SecureRandom.hex(3)}",
                start_at: cursor, end_at: cursor + dur, duration_seconds: dur.to_i, billable: rand < 0.6,
                created_at: cursor, updated_at: cursor }
      cursor += dur + rand(0..30).minutes
    end
  end
  rows.each_slice(5000) { |s| TimeEntry.insert_all(s) }
end
TimeEntry.insert_all(2000.times.map { |i| s = now - i.hours; { user_id: bench.id, workspace_id: other_ws.id, description: "Side #{i}", start_at: s, end_at: s + 30.minutes, duration_seconds: 1800, billable: false, created_at: s, updated_at: s } })

entry_ids = TimeEntry.where(workspace_id: ws.id).pluck(:id)
entry_ids.flat_map { |eid| tag_ids.sample(rand(0..3)).map { |tid| { time_entry_id: eid, tag_id: tid, created_at: now, updated_at: now } } }
  .each_slice(10_000) { |s| TimeEntryTag.insert_all(s) }

# Invoice the bench user's billable entries older than 90 days, one invoice per client per month.
TimeEntry.where(user_id: bench.id, workspace_id: ws.id, billable: true).where(start_at: ...(now - 90.days)).includes(:project).to_a
  .group_by { |e| [ e.project&.client_id, e.start_at.beginning_of_month.to_date ] }.each do |(cid, month), entries|
  next unless cid
  inv = Invoice.create!(workspace: ws, client_id: cid, period_start: month, period_end: month.end_of_month, issued_on: month.end_of_month, status: Invoice::STATUSES.sample, total_cents: 0)
  lines = entries.map { |e| h = e.duration_seconds / 3600.0; { invoice_id: inv.id, time_entry_id: e.id, description: e.description, qty_hours: h.round(2), rate_cents: 12_500, amount_cents: (h * 12_500).round, created_at: now, updated_at: now } }
  InvoiceLine.insert_all(lines)
  inv.update_columns(total_cents: lines.sum { |l| l[:amount_cents] })
end

TimeEntry.create!(user: bench, workspace: ws, description: "Running", start_at: now - 20.minutes, project_id: project_ids.first)

puts({ entries: TimeEntry.count, bench_entries: bench.time_entries.where(workspace: ws).count, time_entry_tags: TimeEntryTag.count,
       invoices: Invoice.count, invoice_lines: InvoiceLine.count, bench_unbilled: bench.time_entries.where(workspace: ws).unbilled.count,
       workspace_hashid: ws.hashid }.inspect)
