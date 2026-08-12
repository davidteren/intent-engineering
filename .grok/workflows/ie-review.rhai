let meta = #{
    name: "ie-review",
    description: "Review a target through five intent-engineering lenses, then adversarially verify each finding. Report only.",
    when_to_use: "Review a diff, branch, or path for surprise. Report only. Does not apply fixes.",
    phases: [
        #{ title: "Review", detail: "one read-only lens per dimension" },
        #{ title: "Verify", detail: "one skeptic per finding" },
        #{ title: "Report", detail: "merge surviving findings" },
    ],
};

let lens_schema = #{
    "type": "object",
    "required": ["lens", "findings", "observations"],
    "properties": #{
        "lens": #{ "type": "string" },
        "findings": #{
            "type": "array",
            "maxItems": 8,
            "items": #{
                "type": "object",
                "required": ["title", "principle", "severity", "confidence", "file", "line", "fix_class", "suggested_fix"],
                "properties": #{
                    "title": #{ "type": "string" },
                    "principle": #{ "type": "string" },
                    "severity": #{ "type": "string" },
                    "confidence": #{ "type": "integer" },
                    "file": #{ "type": "string" },
                    "line": #{ "type": "integer" },
                    "fix_class": #{ "type": "string" },
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

const MAX_FINDINGS = 16;

fn trimmed(s) {
    if type_of(s) == "string" {
        s.trim();
        s
    } else {
        ""
    }
}

fn lens_prompt(target, plugin_root, lens_id, agent_file, docs, hunts, base_ref) {
    let p = "";
    p += "You are the ";
    p += lens_id;
    p += " lens for intent-engineering. Context: review.\n";
    p += "Read these files before you judge anything. Use read_file and grep. Do not answer from memory.\n";
    p += "1. ";
    p += plugin_root;
    p += "/agents/";
    p += agent_file;
    p += "\n2. ";
    p += plugin_root;
    p += "/references/findings-schema.json\n3. ";
    p += plugin_root;
    p += "/references/subagent-template.md\n4. Also read: ";
    p += docs;
    p += " (paths are under ";
    p += plugin_root;
    p += "/).\n";
    p += "Target to review: ";
    p += target;
    p += "\n";
    if base_ref != () && base_ref != "" {
        p += "Run git diff against this base yourself: ";
        p += base_ref;
        p += "\n";
    }
    p += "Hunt for: ";
    p += hunts;
    p += "\n";
    p += "Inspect the actual code. An empty findings list is valid only after you have read the target.\n";
    p += "Return at most 8 findings. Name the broken expectation. Concrete suggested_fix. No product-file edits.\n";
    p += "Skip formatter/linter nits. Flag principle tensions instead of picking a side.\n";
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

let report_rel = "docs/intent-engineering/workflow-ie-review.md";
if args != () && args.out != () {
    report_rel = args.out;
} else if args != () && args.stamp != () {
    report_rel = "docs/intent-engineering/" + args.stamp + "-ie-review.md";
}

let lenses = [
    #{
        id: "predictability",
        agent: "ie-predictability-reviewer.md",
        docs: "resources/principles/least-astonishment.md, resources/principles/dwim.md, resources/principles/wysiwyg.md, resources/agnostic/naming.md, resources/agnostic/error-handling.md, resources/agnostic/api-design.md",
        hunts: "name/behavior mismatch, hidden side effects, surprising returns, silent failures",
    },
    #{
        id: "convention",
        agent: "ie-convention-reviewer.md",
        docs: "resources/principles/convention-over-configuration.md, matching resources/frameworks/<stack>.md, AGENTS.md and CLAUDE.md first",
        hunts: "reinvented conventions, config where convention exists, one-off patterns that fight the repo",
    },
    #{
        id: "simplicity",
        agent: "ie-simplicity-reviewer.md",
        docs: "resources/principles/occams-razor.md, resources/principles/software-philosophies.md, resources/agnostic/defaults-and-configuration.md",
        hunts: "needless abstraction, premature generality, layers that do not earn their keep",
    },
    #{
        id: "experience",
        agent: "ie-experience-reviewer.md",
        docs: "resources/principles/human-interface-guidelines.md, resources/principles/look-and-feel.md, resources/principles/ux-design.md, resources/agnostic/accessibility.md, resources/agnostic/information-architecture.md, resources/agnostic/ux-interaction-smells.md",
        hunts: "missing interaction states, weak labels, broken keyboard or focus, accessibility gaps. If the target has no user-facing surface, return zero findings and say so in observations.",
    },
    #{
        id: "architecture",
        agent: "ie-architecture-reviewer.md",
        docs: "references/stack-catalog.md, matching resources/frameworks/<stack>-architecture.md and resources/patterns/<stack>.yaml",
        hunts: "fat objects, layer leaks, misused patterns. If no Arch-pack stack is present, return zero findings and say so in observations.",
    },
];

phase("Review");
let jobs = [];
for lens in lenses {
    jobs.push(#{
        prompt: lens_prompt(target, plugin_root, lens.id, lens.agent, lens.docs, lens.hunts, base_ref),
        label: "lens:" + lens.id,
        capability_mode: "read-only",
        output_schema: lens_schema,
    });
}
let results = parallel(jobs);

let statuses = [];
let observations = [];
let findings = [];
let idx = 0;
for lens in lenses {
    let r = results[idx];
    let id = lens.id;
    if r == () || r.success != true || r.output == () || r.output.findings == () || type_of(r.output.findings) != "array" {
        statuses.push(#{ lens: id, status: "failed" });
    } else {
        let fs = r.output.findings;
        if fs.len() == 0 {
            statuses.push(#{ lens: id, status: "clean" });
        } else {
            statuses.push(#{ lens: id, status: "findings" });
        }
        for f in fs {
            if f != () && f.title != () && f.file != () {
                let title = trimmed(f.title);
                let file = trimmed(f.file);
                if title != "" && file != "" {
                    findings.push(#{
                        lens: id,
                        title: title,
                        principle: if f.principle == () { "" } else { f.principle },
                        severity: if f.severity == () { "P3" } else { f.severity },
                        confidence: if f.confidence == () { 0 } else { f.confidence },
                        file: file,
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
    idx += 1;
}

let unique = [];
for f in findings {
    let seen = false;
    for u in unique {
        if u.file == f.file && u.title == f.title { seen = true; }
    }
    if !seen { unique.push(f); }
}

if unique.len() > MAX_FINDINGS {
    let dropped = unique.len() - MAX_FINDINGS;
    log("Dropped " + dropped.to_string() + " findings before verify (MAX_FINDINGS=" + MAX_FINDINGS.to_string() + ").");
}

let capped = [];
let n = 0;
for f in unique {
    if n < MAX_FINDINGS {
        capped.push(f);
        n += 1;
    }
}

if capped.len() == 0 {
    let any_failed = false;
    for s in statuses {
        if s.status == "failed" { any_failed = true; }
    }
    if any_failed {
        complete(#{
            summary: "No usable findings. One or more lenses failed. Not an all-clear.",
            confirmed: [],
            statuses: statuses,
            observations: observations,
        });
    }
    complete(#{
        summary: "No findings after the lens panel.",
        confirmed: [],
        statuses: statuses,
        observations: observations,
    });
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

let confirmed = [];
let vi = 0;
for v in verdicts {
    let ev = "";
    if v != () && v.success && v.output.evidence != () {
        ev = trimmed(v.output.evidence);
    }
    if v != () && v.success && v.output.real == true && ev != "" {
        confirmed.push(capped[vi]);
    }
    vi += 1;
}
log(confirmed.len().to_string() + "/" + capped.len().to_string() + " findings survived verification");

phase("Report");
let merge_prompt = "";
merge_prompt += "You merge a verified intent-engineering review. Context: review. Report only. Do not edit product code.\n";
merge_prompt += "Read ";
merge_prompt += plugin_root;
merge_prompt += "/references/report-template.md and ";
merge_prompt += plugin_root;
merge_prompt += "/references/findings-schema.json before writing.\n";
merge_prompt += "Target: ";
merge_prompt += target;
merge_prompt += "\nWrite the published markdown report to this path using the Write tool: ";
merge_prompt += report_rel;
merge_prompt += "\nAlso return the same markdown in the report field.\n";
merge_prompt += "Confidence gate: drop findings below 75 unless severity is P0 and confidence is 50+.\n";
merge_prompt += "Do not claim Ready or all-clear if any lens status is failed.\n";
merge_prompt += "No apply section. No time estimates. No praise.\n";
merge_prompt += "Lens statuses JSON:\n";
merge_prompt += json_encode(statuses);
merge_prompt += "\nObservations JSON:\n";
merge_prompt += json_encode(observations);
merge_prompt += "\nVerified findings JSON:\n";
merge_prompt += json_encode(confirmed);
merge_prompt += "\n";

let merged = agent(merge_prompt, #{
    label: "merge-report",
    capability_mode: "read-write",
    output_schema: report_schema,
});

if merged != () && merged.success && merged.output.report != () {
    let report_text = merged.output.report;
    let scratch = write_scratch_file("report.md", report_text);
    complete(#{
        summary: merged.output.summary,
        verdict: merged.output.verdict,
        path: report_rel,
        scratch: scratch,
        confirmed: confirmed.len(),
        reviewed: capped.len(),
        statuses: statuses,
    });
}

complete(#{
    summary: confirmed.len().to_string() + " confirmed findings; merge did not return a report.",
    path: report_rel,
    confirmed: confirmed,
    statuses: statuses,
});
