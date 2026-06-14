#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Contract-integrity check for the intent-engineering plugin.
#
# Asserts the cross-file invariants that keep the plugin installable and internally
# consistent — the things a single edit can silently break. Deterministic and
# structural (no flaky heuristics). Exits non-zero on any failure.
#
# Run from anywhere:  ruby scripts/check-contracts.rb
# Checks:
#   1. All shipped JSON parses; all shipped YAML parses.
#   2. Lens identity agrees 4 ways: findings-schema `lens` enum == agents/ basenames
#      == lens-catalog rows == scoring-rubric rows.
#   3. Agent frontmatter: name == filename stem, name in the lens enum, tools + model present.
#   4. Every ${CLAUDE_PLUGIN_ROOT}/... path (and backticked references/resources/config
#      paths in the index/catalog) resolves on disk; placeholders skipped.
#   5. Pattern catalog: each entry has id/name/intent/recognition/good_use/misuse; ids
#      unique snake_case.
#   6. principle: values the lenses declare they emit are all in the schema principle enum.
#   7. The five lens agents are git-tracked (the agents/ gitignore trap).
#   8. Cross-references: every threshold metric cited in rails-architecture.md is defined in
#      thresholds.yaml; every pattern id in policy/README exists in the catalog; defined-but-
#      unreferenced metrics are flagged (warning).
#   9. Resource docs: each principle/framework/agnostic doc has a detection (smells) section
#      and a Sources section with >=2 links; every resource doc is cited (no orphans) in
#      principle-index.md or lens-catalog.md.

require "json"
require "yaml"
require "shellwords"

PLUGIN = File.expand_path("../plugins/intent-engineering", __dir__)
LENSES = %w[predictability convention simplicity experience architecture].freeze

$failures = 0
$warnings = 0
$checks = 0

def ok(msg)
  $checks += 1
  puts "  ok   #{msg}"
end

def bad(msg)
  $checks += 1
  $failures += 1
  puts "  FAIL #{msg}"
end

# Soft signal — surfaced but does not fail the suite (e.g. a defined-but-unused threshold,
# which may be intentional spare capacity rather than a broken contract).
def note(msg)
  $warnings += 1
  puts "  warn #{msg}"
end

def section(name)
  puts "\n#{name}"
end

def read(rel)
  File.read(File.join(PLUGIN, rel))
end

# Extract the frontmatter scalar fields (name/description/model/tools/color) from a
# markdown file. Line-based on purpose: Claude Code reads agent/skill frontmatter
# leniently (a description may contain a `: ` that strict YAML would reject), so this
# models the real contract rather than imposing stricter-than-the-harness YAML rules.
def frontmatter(text)
  return {} unless text.start_with?("---")

  _, fm, = text.split(/^---\s*$/, 3)
  out = {}
  (fm || "").each_line do |line|
    m = line.match(/^([A-Za-z][\w-]*):\s*(.*?)\s*$/)
    out[m[1]] = m[2] if m
  end
  out
end

# ---------------------------------------------------------------------------
section "1. JSON / YAML parse"

json_files = ["references/findings-schema.json", ".claude-plugin/plugin.json"]
json_files.each do |rel|
  JSON.parse(read(rel))
  ok "#{rel} parses"
rescue StandardError => e
  bad "#{rel} does not parse: #{e.message}"
end

# marketplace.json lives at the repo root, not under the plugin.
begin
  JSON.parse(File.read(File.expand_path("../.claude-plugin/marketplace.json", __dir__)))
  ok ".claude-plugin/marketplace.json parses"
rescue StandardError => e
  bad "marketplace.json does not parse: #{e.message}"
end

yaml_files = Dir[File.join(PLUGIN, "config/defaults/*.yaml")] +
             Dir[File.join(PLUGIN, "resources/patterns/*.yaml")]
yaml_files.each do |abs|
  YAML.safe_load(File.read(abs))
  ok "#{abs.sub(PLUGIN + '/', '')} parses"
rescue StandardError => e
  bad "#{abs.sub(PLUGIN + '/', '')} does not parse: #{e.message}"
end

# ---------------------------------------------------------------------------
section "2. Lens identity (4-way agreement)"

schema = JSON.parse(read("references/findings-schema.json"))
schema_lenses = schema.dig("properties", "lens", "enum") || []
if schema_lenses.sort == LENSES.sort
  ok "findings-schema lens enum == expected 5 lenses"
else
  bad "findings-schema lens enum #{schema_lenses.inspect} != #{LENSES.inspect}"
end

agent_files = Dir[File.join(PLUGIN, "agents/ie-*-reviewer.md")]
agent_basenames = agent_files.map { |f| File.basename(f, ".md").sub(/^ie-/, "").sub(/-reviewer$/, "") }
if agent_basenames.sort == schema_lenses.sort
  ok "agents/ basenames == lens enum"
else
  bad "agents/ basenames #{agent_basenames.sort.inspect} != lens enum #{schema_lenses.sort.inspect}"
end

catalog = read("references/lens-catalog.md")
catalog_lenses = catalog.scan(/`ie-([a-z-]+)-reviewer`/).flatten.uniq
if (schema_lenses - catalog_lenses).empty? && (catalog_lenses - schema_lenses).empty?
  ok "lens-catalog rows == lens enum"
else
  bad "lens-catalog lenses #{catalog_lenses.sort.inspect} != lens enum #{schema_lenses.sort.inspect}"
end

rubric = read("references/scoring-rubric.md")
# Rows of the "scores JSON keys" table: "| <lens> | `key`, ... |"
rubric_lenses = rubric.scan(/^\|\s*([a-z][a-z-]+)\s*\|\s*`/).flatten.uniq
if rubric_lenses.sort == schema_lenses.sort
  ok "scoring-rubric rows == lens enum"
else
  bad "scoring-rubric lenses #{rubric_lenses.sort.inspect} != lens enum #{schema_lenses.sort.inspect}"
end

# ---------------------------------------------------------------------------
section "3. Agent frontmatter"

agent_files.each do |abs|
  rel = abs.sub(PLUGIN + "/", "")
  fm = frontmatter(File.read(abs))
  stem = File.basename(abs, ".md")
  if fm["name"] == stem
    ok "#{rel}: name == filename stem"
  else
    bad "#{rel}: name #{fm['name'].inspect} != filename stem #{stem.inspect}"
  end

  lens_id = stem.sub(/^ie-/, "").sub(/-reviewer$/, "")
  bad "#{rel}: lens id #{lens_id.inspect} not in enum" unless schema_lenses.include?(lens_id)

  %w[tools model].each do |field|
    bad "#{rel}: frontmatter missing #{field}" if fm[field].to_s.strip.empty?
  end
end

# ---------------------------------------------------------------------------
section "4. Referenced paths resolve"

PLACEHOLDER = /[<>{}*]/.freeze
def strip_trailing(p)
  p.sub(/[.,;:)]+$/, "")
end

cited = {} # path => first source file

# ${CLAUDE_PLUGIN_ROOT}/... anywhere in agents, skills, references
(Dir[File.join(PLUGIN, "agents/*.md")] +
 Dir[File.join(PLUGIN, "skills/*/SKILL.md")] +
 Dir[File.join(PLUGIN, "references/*.md")]).each do |abs|
  rel = abs.sub(PLUGIN + "/", "")
  File.read(abs).scan(%r{\$\{CLAUDE_PLUGIN_ROOT\}/([A-Za-z0-9_/.\-]+)}) do |m|
    path = strip_trailing(m[0])
    next if path.empty? || path =~ PLACEHOLDER

    cited[path] ||= rel
  end
end

# Backticked references/resources/config paths in the index + catalog (documented to exist)
["references/principle-index.md", "references/lens-catalog.md"].each do |rel|
  read(rel).scan(/`((?:references|resources|config)\/[A-Za-z0-9_\/.\-]+)`/) do |m|
    path = strip_trailing(m[0])
    next if path.empty? || path =~ PLACEHOLDER

    cited[path] ||= rel
  end
end

missing = cited.reject { |path, _| File.exist?(File.join(PLUGIN, path)) }
if missing.empty?
  ok "all #{cited.size} cited plugin paths resolve"
else
  missing.each { |path, src| bad "cited path missing: #{path} (in #{src})" }
end

# ---------------------------------------------------------------------------
section "5. Pattern catalog schema"

Dir[File.join(PLUGIN, "resources/patterns/*.yaml")].each do |abs|
  rel = abs.sub(PLUGIN + "/", "")
  doc = YAML.safe_load(File.read(abs))
  patterns = doc["patterns"] || []
  if patterns.empty?
    bad "#{rel}: no patterns"
    next
  end
  required = %w[id name intent recognition good_use misuse]
  ids = []
  clean = true
  patterns.each_with_index do |p, i|
    miss = required.reject { |k| p.is_a?(Hash) && p.key?(k) && !p[k].to_s.strip.empty? }
    unless miss.empty?
      bad "#{rel}: pattern ##{i} (#{p['id'] || '?'}) missing #{miss.join(', ')}"
      clean = false
    end
    ids << p["id"] if p.is_a?(Hash)
  end
  dupes = ids.tally.select { |_, n| n > 1 }.keys
  unless dupes.empty?
    bad "#{rel}: duplicate pattern ids #{dupes.inspect}"
    clean = false
  end
  nonsnake = ids.compact.reject { |id| id =~ /\A[a-z][a-z0-9_]*\z/ }
  unless nonsnake.empty?
    bad "#{rel}: non-snake_case pattern ids #{nonsnake.inspect}"
    clean = false
  end
  ok "#{rel}: #{patterns.size} patterns, all fields present, ids unique snake_case" if clean
end

# ---------------------------------------------------------------------------
section "6. Emitted principle ids in schema enum"

principle_enum = schema.dig("properties", "findings", "items", "properties", "principle", "enum") || []
bad "schema principle enum is empty" if principle_enum.empty?

unknown = []
agent_files.each do |abs|
  rel = abs.sub(PLUGIN + "/", "")
  text = File.read(abs)
  out = text.split(/^## Output\s*$/, 2)[1] || ""
  out = out.tr("\n", " ")
  # For each `principle:` mention, collect only the unbroken run of backticked/quoted
  # kebab tokens that immediately follows (separated by commas / "or"). This stops at the
  # first prose word, so it won't swallow nearby fields like `smell`/`pattern`.
  out.scan(/principle:\s*((?:[`"][a-z0-9-]+[`"]\s*,?\s*(?:or\s+)?)+)/) do |chunk|
    chunk[0].scan(/[`"]([a-z][a-z0-9-]+)[`"]/).flatten.each do |tok|
      unknown << [tok, rel] unless principle_enum.include?(tok)
    end
  end
end
if unknown.empty?
  ok "all principle ids emitted by lenses are in the schema enum"
else
  unknown.uniq.each { |tok, rel| bad "principle id not in enum: #{tok} (#{rel})" }
end

# ---------------------------------------------------------------------------
section "7. Lens agents are git-tracked (the agents/ gitignore trap)"

tracked = `git -C #{PLUGIN.shellescape} ls-files agents/`.lines.map(&:strip).reject(&:empty?)
if tracked.size == LENSES.size
  ok "#{tracked.size} agent files git-tracked"
else
  bad "expected #{LENSES.size} tracked agent files, found #{tracked.size}: #{tracked.inspect}"
end

# ---------------------------------------------------------------------------
section "8. Cross-references (thresholds <-> docs, pattern policy <-> catalog)"

rails_catalog = YAML.safe_load(read("resources/patterns/rails.yaml")) || {}
catalog_ids = (rails_catalog["patterns"] || []).map { |p| p["id"] }.compact
thresholds = YAML.safe_load(read("config/defaults/thresholds.yaml")) || {}
arch_doc = read("resources/frameworks/rails-architecture.md")

# Flatten thresholds to dotted ids: <stack>.<unit>.<metric>
defined_metrics = []
thresholds.each do |stack, units|
  next unless units.is_a?(Hash)

  units.each do |unit, metrics|
    next unless metrics.is_a?(Hash)

    metrics.each_key { |m| defined_metrics << "#{stack}.#{unit}.#{m}" }
  end
end

# (a) every metric id cited in rails-architecture.md is a real defined threshold
cited_metrics = arch_doc.scan(/`(rails\.[a-z_]+\.[a-z_]+)`/).flatten.uniq
undefined = cited_metrics.reject { |k| defined_metrics.include?(k) }
if undefined.empty?
  ok "all #{cited_metrics.size} metric ids cited in rails-architecture.md are defined in thresholds.yaml"
else
  undefined.each { |k| bad "rails-architecture.md cites an undefined threshold: #{k}" }
end

# (b) every defined threshold is referenced (exact id or a `<stack>.<unit>.*` wildcard) by
#     the doc, the lens, or config-resolution. Soft warning — an unused metric may be intentional.
ref_text = arch_doc + read("agents/ie-architecture-reviewer.md") + read("references/config-resolution.md")
orphans = defined_metrics.reject do |k|
  stack, unit, = k.split(".")
  ref_text.include?(k) || ref_text.include?("#{stack}.#{unit}.*")
end
if orphans.empty?
  ok "every defined threshold metric is referenced by the docs/lens"
else
  orphans.each { |k| note "threshold defined but never referenced by id: #{k}" }
end

# (c) every pattern id named in policy (config defaults) and README examples exists in the catalog
policy = YAML.safe_load(read("config/defaults/patterns.yaml")) || {}
policy_ids = (Array(policy["allowed"]) + Array(policy["blocked"])).select { |x| x.is_a?(String) }
# README bracketed examples: `allowed: [interactor, form_object, ...]`, `blocked: [service_object]`
read("resources/patterns/README.md").scan(/(?:allowed|blocked):\s*\[([^\]]*)\]/) do |m|
  m[0].split(",").map(&:strip).each { |id| policy_ids << id unless id.empty? || id == "..." }
end
policy_ids.uniq!
unknown_ids = policy_ids.reject { |id| catalog_ids.include?(id) }
if unknown_ids.empty?
  ok "all #{policy_ids.size} pattern ids named in policy/README exist in the rails catalog"
else
  unknown_ids.each { |id| bad "pattern id named in policy/README not in catalog: #{id}" }
end

# ---------------------------------------------------------------------------
section "9. Resource-doc structure & citations"

# Prose knowledge docs the lenses read. Each must carry a detection ("smells") section
# and a Sources section with real links. (patterns/README.md is meta and *.yaml is data —
# excluded from prose checks; the catalog yaml is schema-checked in section 5.)
DETECTION_EXEMPT = ["principles/software-philosophies.md"].freeze # index/landscape doc, by design

prose_docs = (Dir[File.join(PLUGIN, "resources/principles/*.md")] +
              Dir[File.join(PLUGIN, "resources/frameworks/*.md")] +
              Dir[File.join(PLUGIN, "resources/agnostic/*.md")]).sort

prose_docs.each do |abs|
  rel = abs.sub(PLUGIN + "/resources/", "")
  text = File.read(abs)

  unless DETECTION_EXEMPT.include?(rel)
    if text =~ /^#+.*(smell|detectable)/i
      ok "#{rel}: has a detection (smells) section"
    else
      bad "#{rel}: no detection section (expected a heading naming 'smells'/'detectable')"
    end
  end

  has_sources = text =~ /^#+\s*(sources|references)\b/i
  link_count = text.scan(%r{https?://}).size
  if has_sources && link_count >= 2
    ok "#{rel}: Sources section with #{link_count} links"
  else
    bad "#{rel}: missing Sources section or <2 links (sources_heading=#{!has_sources.nil?}, links=#{link_count})"
  end
end

# Every resource file must be cited (no orphans) in principle-index.md or lens-catalog.md.
index_text = read("references/principle-index.md") + read("references/lens-catalog.md")
resource_files = (Dir[File.join(PLUGIN, "resources/principles/*.md")] +
                  Dir[File.join(PLUGIN, "resources/frameworks/*.md")] +
                  Dir[File.join(PLUGIN, "resources/agnostic/*.md")] +
                  Dir[File.join(PLUGIN, "resources/patterns/*.md")] +
                  Dir[File.join(PLUGIN, "resources/patterns/*.yaml")]).sort

orphans = resource_files.reject { |abs| index_text.include?(File.basename(abs)) }
if orphans.empty?
  ok "all #{resource_files.size} resource docs are cited in principle-index.md / lens-catalog.md"
else
  orphans.each { |abs| bad "orphan resource doc (not in principle-index/lens-catalog): #{abs.sub(PLUGIN + '/', '')}" }
end

# ---------------------------------------------------------------------------
puts "\n#{'-' * 60}"
warn_note = $warnings.zero? ? "" : ", #{$warnings} warning(s)"
if $failures.zero?
  puts "PASS — #{$checks} checks, 0 failures#{warn_note}"
  exit 0
else
  puts "FAIL — #{$checks} checks, #{$failures} failure(s)#{warn_note}"
  exit 1
end
