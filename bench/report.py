import json, re, sys, glob, os, statistics as st

out = sys.argv[1]
tasks = {t["id"]: t for t in json.load(open(os.path.join(os.path.dirname(__file__) or ".", "tasks.json")))}
rows = {}
for f in glob.glob(os.path.join(out, "*.json")):
    c, rest = os.path.basename(f)[:-5].split("-", 1)
    tid = rest.rsplit("-", 1)[0]
    try:
        r = json.loads(open(f).read().strip().splitlines()[-1])
    except Exception:
        print("unreadable:", f); continue
    facts = tasks[tid]["facts"]
    text = r.get("result", "") or ""
    score = sum(bool(re.search(x, text, re.I)) for x in facts) / len(facts)
    mu = r.get("modelUsage", {})
    main = sum(v["costUSD"] for k, v in mu.items() if "haiku" not in k)
    cheap = sum(v["costUSD"] for k, v in mu.items() if "haiku" in k)
    main_in = sum(v["inputTokens"] + v["cacheReadInputTokens"] + v["cacheCreationInputTokens"] for k, v in mu.items() if "haiku" not in k)
    rows.setdefault((tid, c), []).append(dict(cost=r.get("total_cost_usd", 0), main=main, cheap=cheap, main_in=main_in,
                                              secs=r.get("duration_ms", 0) / 1000, score=score, err=r.get("is_error", False)))

def agg(rs, k): return st.mean(x[k] for x in rs)
fmt = "{:<13}{:>6}{:>10}{:>10}{:>10}{:>12}{:>8}{:>8}"
print(fmt.format("task", "shunt", "total$", "main$", "haiku$", "main tok in", "secs", "score"))
tot = {"0": [], "1": []}
for tid in tasks:
    for c in ("0", "1"):
        rs = rows.get((tid, c))
        if not rs: continue
        tot[c] += rs
        print(fmt.format(tid, "on" if c == "1" else "off", f"{agg(rs,'cost'):.3f}", f"{agg(rs,'main'):.3f}", f"{agg(rs,'cheap'):.3f}",
                         f"{agg(rs,'main_in'):,.0f}", f"{agg(rs,'secs'):.0f}", f"{agg(rs,'score'):.0%}"))
if tot["0"] and tot["1"]:
    print()
    for k, label in (("cost", "total cost"), ("main_in", "main-model input tokens"), ("secs", "wall time"), ("score", "answer score")):
        a, b = agg(tot["0"], k), agg(tot["1"], k)
        print(f"{label:<25} off {a:,.3f}  on {b:,.3f}  change {((b - a) / a * 100 if a else 0):+.0f}%")
    errs = sum(x["err"] for x in tot["0"] + tot["1"])
    if errs: print(f"\n{errs} runs reported errors")
