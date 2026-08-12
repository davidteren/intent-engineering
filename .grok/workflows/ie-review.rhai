let meta = #{
    name: "ie-review",
    description: "Review a target through intent-engineering lenses, then adversarially verify each finding. Writes a published report. Does not apply product-code fixes.",
    when_to_use: "Review a diff, branch, or path for surprise. Merge is read-only. A publisher writes docs/intent-engineering/<stamp>-review.md only. Does not apply product-code fixes.",
    phases: [
        #{ title: "Config", detail: "resolve .intense and select lenses" },
        #{ title: "Review", detail: "one read-only lens per selected dimension" },
        #{ title: "Verify", detail: "one skeptic per finding" },
        #{ title: "Report", detail: "read-only merge, then publish" },
    ],
};

let config_schema = #{
    "type": "object",
    "required": ["source"],
    "properties": #{
        "source": #{ "type": "string" },
        "confidence_gate": #{ "type": "integer" },
        "run_predictability": #{ "type": "boolean" },
        "run_convention": #{ "type": "boolean" },
        "run_simplicity": #{ "type": "boolean" },
        "run_experience": #{ "type": "boolean" },
        "run_architecture": #{ "type": "boolean" },
        "standards_paths": #{ "type": "string" },
        "intent": #{ "type": "string" },
        "scope_mode": #{ "type": "string" },
        "notes": #{ "type": "string" },
    },
};

let lens_schema = #{
    "type": "object",
    "required": ["lens", "findings", "observations"],
    "properties": #{
        "lens": #{
            "type": "string",
            "enum": ["predictability", "convention", "simplicity", "experience", "architecture"],
        },
        "findings": #{
            "type": "array",
            "maxItems": 8,
            "items": #{
                "type": "object",
                "required": ["title", "principle", "severity", "confidence", "file", "line", "fix_class", "suggested_fix"],
                "properties": #{
                    "title": #{ "type": "string" },
                    "principle": #{
                        "type": "string",
                        "enum": [
                            "least-astonishment", "dwim", "wysiwyg",
                            "convention-over-configuration", "framework-idiom",
                            "occams-razor", "kiss", "yagni",
                            "human-interface-guidelines", "look-and-feel", "ux-design",
                            "accessibility", "information-architecture", "naming",
                            "error-handling", "api-design", "defaults-and-configuration",
                            "architecture",
                        ],
                    },
                    "severity": #{ "type": "string", "enum": ["P0", "P1", "P2", "P3"] },
                    "confidence": #{ "type": "integer", "enum": [0, 25, 50, 75, 100] },
                    "file": #{ "type": "string" },
                    "line": #{ "type": "integer" },
                    "fix_class": #{ "type": "string", "enum": ["gated_auto", "manual", "advisory"] },
                    "suggested_fix": #{ "type": "string" },
                    "evidence": #{ "type": "string" },
                    "tension": #{ "type": "string" },
                },
            },
        },
        "observations": #{ "type": "array", "items": #{ "type": "string" } },
    },
};

let verdict_schema = #{
    "type": "object",
    "required": ["real", "reason", "evidence"],
    "properties": #{
        "real": #{ "type": "boolean" },
        "reason": #{ "type": "string" },
        "evidence": #{ "type": "string" },
    },
};

let report_schema = #{
    "type": "object",
    "required": ["summary", "verdict", "report"],
    "properties": #{
        "summary": #{ "type": "string" },
        "verdict": #{ "type": "string" },
        "report": #{ "type": "string" },
    },
};

let publish_schema = #{
    "type": "object",
    "required": ["wrote"],
    "properties": #{
        "wrote": #{ "type": "boolean" },
        "path": #{ "type": "string" },
    },
};

const MAX_FINDINGS = 16;

fn trimmed(s) {
    if type_of(s) == "string" {
        s.trim();
        s
    } else {
        ""
    }
}

fn norm(s) {
    let t = trimmed(s);
    if type_of(t) == "string" {
        t.to_lower();
        t
    } else {
        ""
    }
}

fn severity_rank(s) {
    if s == "P0" { 0 } else if s == "P1" { 1 } else if s == "P2" { 2 } else { 3 }
}

fn comes_first(a, b) {
    let ra = severity_rank(a.severity);
    let rb = severity_rank(b.severity);
    if ra != rb { ra < rb } else { a.confidence > b.confidence }
}

fn passes_gate_at(f, gate) {
    if f.confidence >= gate { true } else if f.severity == "P0" && f.confidence >= 50 { true } else { false }
}

fn result_map(summary, verdict, path, scratch, confirmed, reviewed, statuses, observations, rejected, config_source) {
    #{
        summary: summary,
        verdict: verdict,
        path: path,
        scratch: scratch,
        confirmed: confirmed,
        confirmed_count: confirmed.len(),
        reviewed: reviewed,
        statuses: statuses,
        observations: observations,
        rejected_count: rejected.len(),
        config_source: config_source,
    }
}

fn lens_prompt(target, plugin_root, lens_id, agent_file, docs, hunts, base_ref, intent_text, scope_mode, standards_paths) {
    let p = "";
    p += "You are the ";
    p += lens_id;
    p += " lens. Read your agent definition for identity and calibration.\n";
    p += "Read ";
    p += plugin_root;
    p += "/agents/";
    p += agent_file;
    p += " and ";
    p += plugin_root;
    p += "/references/findings-schema.json and ";
    p += plugin_root;
    p += "/references/subagent-template.md before you judge. Use read_file and grep. Do not answer from memory.\n";
    p += "Context: review\n";
    p += "<knowledge>\nRead these docs under ";
    p += plugin_root;
    p += "/ before reviewing. They hold your detection heuristics (Violation smells):\n";
    p += docs;
    p += "\n";
    if standards_paths != () && standards_paths != "" {
        p += "ALSO read repo standards at these paths FIRST. They override community defaults:\n";
        p += standards_paths;
        p += "\n";
    }
    p += "</knowledge>\n";
    p += "<intent>\n";
    p += intent_text;
    p += "\n</intent>\n";
    p += "<scope>\nMode: ";
    p += scope_mode;
    p += "\nTarget: ";
    p += target;
    p += "\n";
    if base_ref != () && base_ref != "" {
        p += "Run git diff against this base yourself: ";
        p += base_ref;
        p += "\n";
    }
    p += "Hunt for: ";
    p += hunts;
    p += "\n</scope>\n";
    p += "<output-contract>\n";
    p += "Return compact JSON that matches the harness schema. Include evidence on each finding.\n";
    p += "Do not write project files. The orchestrator writes Layer A scratch from your return.\n";
    p += "An empty findings list is valid only after you have read the target.\n";
    p += "At most 8 findings. Name the broken expectation. Concrete suggested_fix.\n";
    p += "Skip formatter/linter nits. Flag principle tensions instead of picking a side.\n";
    p += "</output-contract>\n";
    p
}

let target = if args == () { () } else { args.target };
if target == () { pause("verification", "Pass args.target: the diff, branch, or path to review."); }

let plugin_root = "plugins/intent-engineering";
if args != () && args.plugin_root != () {
    plugin_root = args.plugin_root;
}

let base_ref = ();
if args != () && args.base != () {
    base_ref = args.base;
}

let report_rel = "";
if args != () && args.out != () {
    report_rel = args.out;
} else if args != () && args.stamp != () {
    report_rel = "docs/intent-engineering/" + args.stamp + "-review.md";
} else {
    let slug = fingerprint("" + target);
    if type_of(slug) == "string" && slug.len() >= 8 {
        slug = slug.sub_string(0, 8);
    } else {
        slug = "run";
    }
    report_rel = "docs/intent-engineering/" + slug + "-review.md";
}

let config_dir = ();
if args != () && args.config != () {
    config_dir = args.config;
}

phase("Config");
let cfg_prompt = "";
cfg_prompt += "Resolve intent-engineering config for this review. Read-only. Do not edit files.\n";
cfg_prompt += "Read ";
cfg_prompt += plugin_root;
cfg_prompt += "/references/config-resolution.md and ";
cfg_prompt += plugin_root;
cfg_prompt += "/references/lens-catalog.md and ";
cfg_prompt += plugin_root;
cfg_prompt += "/references/stack-catalog.md and ";
cfg_prompt += plugin_root;
cfg_prompt += "/config/defaults/ways-of-working.yaml.\n";
cfg_prompt += "Walk up from the target for a nearest .intense/ that contains yaml. Honor config: override if given.\n";
if config_dir != () {
    cfg_prompt += "config override directory: ";
    cfg_prompt += config_dir;
    cfg_prompt += "\n";
}
cfg_prompt += "Target: ";
cfg_prompt += target;
cfg_prompt += "\n";
if base_ref != () && base_ref != "" {
    cfg_prompt += "Base ref: ";
    cfg_prompt += base_ref;
    cfg_prompt += "\n";
}
cfg_prompt += "Return source (project path or 'defaults'), confidence_gate (default 75), which lenses to run, standards_paths (AGENTS.md/CLAUDE.md ancestors, comma-separated), a 2-3 line intent, and scope_mode (local-aligned | pr-remote | branch-remote | path | doc).\n";
cfg_prompt += "Always-on unless config sets off: predictability, simplicity. Convention on unless off. Experience on only for a user-facing surface or lenses.experience=on. Architecture on only when a stack-catalog Arch pack is present or lenses.architecture=on.\n";
cfg_prompt += "Use read_file and grep. Do not guess a stack that the catalog does not list.\n";

let cfg = agent(cfg_prompt, #{
    label: "resolve-config",
    capability_mode: "read-only",
    output_schema: config_schema,
});

let config_source = "defaults";
let gate = 75;
let run_predictability = true;
let run_convention = true;
let run_simplicity = true;
let run_experience = false;
let run_architecture = false;
let standards_paths = "";
let intent_text = "Review the target for surprise against intent-engineering lenses.";
let scope_mode = "path";
if cfg != () && cfg.success == true && cfg.output != () {
    if cfg.output.source != () { config_source = cfg.output.source; }
    if cfg.output.confidence_gate != () { gate = cfg.output.confidence_gate; }
    if cfg.output.run_predictability == false { run_predictability = false; }
    if cfg.output.run_convention == false { run_convention = false; }
    if cfg.output.run_simplicity == false { run_simplicity = false; }
    if cfg.output.run_experience == true { run_experience = true; }
    if cfg.output.run_architecture == true { run_architecture = true; }
    if cfg.output.standards_paths != () { standards_paths = cfg.output.standards_paths; }
    if cfg.output.intent != () { intent_text = cfg.output.intent; }
    if cfg.output.scope_mode != () { scope_mode = cfg.output.scope_mode; }
    if cfg.output.notes != () { log(cfg.output.notes); }
}

let catalog = [
    #{
        id: "predictability",
        agent: "ie-predictability-reviewer.md",
        docs: "resources/principles/least-astonishment.md, resources/principles/dwim.md, resources/principles/wysiwyg.md, resources/agnostic/naming.md, resources/agnostic/error-handling.md, resources/agnostic/api-design.md",
        hunts: "name/behavior mismatch, hidden side effects, surprising returns, silent failures",
        selected: run_predictability,
    },
    #{
        id: "convention",
        agent: "ie-convention-reviewer.md",
        docs: "resources/principles/convention-over-configuration.md, matching resources/frameworks/<stack>.md, AGENTS.md and CLAUDE.md first",
        hunts: "reinvented conventions, config where convention exists, one-off patterns that fight the repo",
        selected: run_convention,
    },
    #{
        id: "simplicity",
        agent: "ie-simplicity-reviewer.md",
        docs: "resources/principles/occams-razor.md, resources/principles/software-philosophies.md, resources/agnostic/defaults-and-configuration.md",
        hunts: "needless abstraction, premature generality, layers that do not earn their keep",
        selected: run_simplicity,
    },
    #{
        id: "experience",
        agent: "ie-experience-reviewer.md",
        docs: "resources/principles/human-interface-guidelines.md, resources/principles/look-and-feel.md, resources/principles/ux-design.md, resources/agnostic/accessibility.md, resources/agnostic/information-architecture.md, resources/agnostic/ux-interaction-smells.md",
        hunts: "missing interaction states, weak labels, broken keyboard or focus, accessibility gaps",
        selected: run_experience,
    },
    #{
        id: "architecture",
        agent: "ie-architecture-reviewer.md",
        docs: "references/stack-catalog.md, matching resources/frameworks/<stack>-architecture.md and resources/patterns/<stack>.yaml",
        hunts: "fat objects, layer leaks, misused patterns",
        selected: run_architecture,
    },
];

phase("Review");
let jobs = [];
let job_ids = [];
for lens in catalog {
    if lens.selected {
        jobs.push(#{
            prompt: lens_prompt(target, plugin_root, lens.id, lens.agent, lens.docs, lens.hunts, base_ref, intent_text, scope_mode, standards_paths),
            label: "lens:" + lens.id,
            capability_mode: "read-only",
            output_schema: lens_schema,
        });
        job_ids.push(lens.id);
    }
}

let results = [];
if jobs.len() > 0 {
    results = parallel(jobs);
}

let statuses = [];
let observations = [];
let findings = [];
observations.push("Config source: " + config_source + ". confidence_gate=" + gate.to_string() + ".");

let ri = 0;
for lens in catalog {
    if !lens.selected {
        statuses.push(#{ lens: lens.id, status: "skipped" });
    } else {
        let r = ();
        if ri < results.len() { r = results[ri]; }
        if r == () || r.success != true || r.output == () || r.output.findings == () || type_of(r.output.findings) != "array" {
            statuses.push(#{ lens: lens.id, status: "failed" });
        } else {
            statuses.push(#{ lens: lens.id, status: "clean" });
            write_scratch_file(lens.id + ".json", json_encode(r.output));
            let fs = r.output.findings;
            for f in fs {
                if f != () && f.title != () && f.file != () {
                    let title = trimmed(f.title);
                    let file = trimmed(f.file);
                    if title != "" && file != "" {
                        findings.push(#{
                            lens: lens.id,
                            lenses: [lens.id],
                            title: title,
                            title_key: norm(title),
                            file: file,
                            file_key: norm(file),
                            principle: if f.principle == () { "" } else { f.principle },
                            severity: if f.severity == () { "P3" } else { f.severity },
                            confidence: if f.confidence == () { 0 } else { f.confidence },
                            line: if f.line == () { 0 } else { f.line },
                            fix_class: if f.fix_class == () { "manual" } else { f.fix_class },
                            suggested_fix: if f.suggested_fix == () { "" } else { f.suggested_fix },
                            evidence: if f.evidence == () { "" } else { f.evidence },
                            tension: if f.tension == () { "" } else { f.tension },
                        });
                    }
                }
            }
            if r.output.observations != () {
                for o in r.output.observations {
                    if o != () { observations.push(o); }
                }
            }
        }
        ri += 1;
    }
}

let unique = [];
for f in findings {
    let seen_at = -1;
    let ui = 0;
    for u in unique {
        let delta = 99;
        if type_of(u.line) != "()" && type_of(f.line) != "()" {
            delta = u.line - f.line;
            if delta < 0 { delta = 0 - delta; }
        }
        if u.file_key == f.file_key && u.title_key == f.title_key && delta <= 3 {
            seen_at = ui;
        }
        ui += 1;
    }
    if seen_at < 0 {
        unique.push(f);
    } else {
        let kept = unique[seen_at];
        if comes_first(f, kept) {
            let prior = kept.lenses;
            f.lenses = prior;
            unique[seen_at] = f;
        }
        let already = false;
        for lid in unique[seen_at].lenses {
            if lid == f.lens { already = true; }
        }
        if !already { unique[seen_at].lenses.push(f.lens); }
    }
}

let ui2 = 0;
for u in unique {
    if u.lenses.len() >= 2 {
        if u.confidence == 50 { unique[ui2].confidence = 75; }
        else if u.confidence == 75 { unique[ui2].confidence = 100; }
    }
    ui2 += 1;
}

let ranked = [];
for f in unique {
    let placed = false;
    let next = [];
    for r in ranked {
        if !placed && comes_first(f, r) {
            next.push(f);
            placed = true;
        }
        next.push(r);
    }
    if !placed { next.push(f); }
    ranked = next;
}

if ranked.len() > MAX_FINDINGS {
    let dropped = ranked.len() - MAX_FINDINGS;
    log("Dropped " + dropped.to_string() + " findings before verify (MAX_FINDINGS=" + MAX_FINDINGS.to_string() + "). Kept highest severity first.");
    observations.push("Dropped " + dropped.to_string() + " findings at MAX_FINDINGS=" + MAX_FINDINGS.to_string() + " after severity sort.");
}

let capped = [];
let n = 0;
for f in ranked {
    if n < MAX_FINDINGS {
        capped.push(f);
        n += 1;
    }
}

let none = [];
if capped.len() == 0 {
    let any_failed = false;
    for s in statuses {
        if s.status == "failed" { any_failed = true; }
    }
    if any_failed {
        complete(result_map(
            "No usable findings. One or more lenses failed. Not an all-clear.",
            "Not ready",
            "",
            "",
            none,
            0,
            statuses,
            observations,
            none,
            config_source
        ));
    }
    complete(result_map(
        "No findings after the lens panel.",
        "Ready",
        "",
        "",
        none,
        0,
        statuses,
        observations,
        none,
        config_source
    ));
}

phase("Verify");
let vjobs = [];
for f in capped {
    let blob = json_encode(f);
    let p = "";
    p += "Adversarially verify this intent-engineering finding by reading the shipped code.\n";
    p += "Finding JSON:\n";
    p += blob;
    p += "\nSet real=true only with concrete evidence you independently inspected in the file.\n";
    p += "If you cannot open the file, or the claim is wrong, or evidence is thin, set real=false.\n";
    p += "Empty evidence requires real=false. Use read_file and grep. Do not trust the JSON alone.\n";
    vjobs.push(#{
        prompt: p,
        label: "verify:" + f.file,
        capability_mode: "read-only",
        output_schema: verdict_schema,
    });
}
let verdicts = parallel(vjobs);

let verified = [];
let rejected = [];
let vi = 0;
for v in verdicts {
    let ev = "";
    let harness_ok = v != () && v.success == true && v.output != ();
    if harness_ok && v.output.evidence != () {
        ev = trimmed(v.output.evidence);
    }
    if harness_ok && v.output.real == true && ev != "" {
        verified.push(capped[vi]);
    } else {
        let why = "not_real";
        if !harness_ok { why = "verifier_failed"; }
        rejected.push(#{ finding: capped[vi], why: why });
    }
    vi += 1;
}

let confirmed = [];
for f in verified {
    if passes_gate_at(f, gate) { confirmed.push(f); }
    else { rejected.push(#{ finding: f, why: "below_confidence_gate" }); }
}
log(confirmed.len().to_string() + "/" + capped.len().to_string() + " findings survived verification and the confidence gate");

phase("Report");
let merge_prompt = "";
merge_prompt += "You merge a verified intent-engineering review. Context: review. Read-only. Do not write any file.\n";
merge_prompt += "Read ";
merge_prompt += plugin_root;
merge_prompt += "/references/report-template.md and ";
merge_prompt += plugin_root;
merge_prompt += "/references/findings-schema.json before you write the markdown.\n";
merge_prompt += "Target: ";
merge_prompt += target;
merge_prompt += "\nReturn the published markdown in the report field only. The orchestrator will store it.\n";
merge_prompt += "The confidence gate already ran. Use the confirmed list as-is.\n";
merge_prompt += "Do not claim Ready or all-clear if any lens status is failed.\n";
merge_prompt += "No apply section. No time estimates. No praise.\n";
merge_prompt += "Include Config source and rejected rows in Coverage.\n";
merge_prompt += "Lens statuses JSON:\n";
merge_prompt += json_encode(statuses);
merge_prompt += "\nObservations JSON:\n";
merge_prompt += json_encode(observations);
merge_prompt += "\nRejected JSON (verifier_failed / not_real / below_confidence_gate):\n";
merge_prompt += json_encode(rejected);
merge_prompt += "\nConfirmed findings JSON:\n";
merge_prompt += json_encode(confirmed);
merge_prompt += "\n";

let merged = agent(merge_prompt, #{
    label: "merge-report",
    capability_mode: "read-only",
    output_schema: report_schema,
});

if merged == () || merged.success != true || merged.output == () || merged.output.report == () {
    complete(result_map(
        confirmed.len().to_string() + " confirmed findings; merge did not return a report.",
        "Not ready",
        "",
        "",
        confirmed,
        capped.len(),
        statuses,
        observations,
        rejected,
        config_source
    ));
}

let report_text = merged.output.report;
let scratch = write_scratch_file("report.md", report_text);
let published = "";
let pub_prompt = "";
pub_prompt += "Write this exact markdown to this path and to no other path: ";
pub_prompt += report_rel;
pub_prompt += "\nDo not edit product code. Overwrite the file if it exists.\n";
pub_prompt += "Return wrote=true only after a successful Write.\n\n";
pub_prompt += report_text;

let pub = agent(pub_prompt, #{
    label: "publish-report",
    capability_mode: "read-write",
    output_schema: publish_schema,
});
if pub != () && pub.success == true && pub.output != () && pub.output.wrote == true {
    published = report_rel;
}

let verdict = if merged.output.verdict == () { "Ready with fixes" } else { merged.output.verdict };
let summary = if merged.output.summary == () {
    confirmed.len().to_string() + " confirmed findings."
} else {
    merged.output.summary
};
complete(result_map(summary, verdict, published, scratch, confirmed, capped.len(), statuses, observations, rejected, config_source));
