#!/usr/bin/env python3
"""Measure the deployed /v1/decide on the 19 demo-storm cases of cmd/scorecard.

Each case is sent RUNS times (Gemini is not deterministic). For every answer we
record who answered (generated_by, model), latency, the verdict, and whether a
guardrail fired (a `guardrail_*` step in the reasoning trace). The guard-fire
rate is the share of Gemini answers the safety layer had to correct, measured
on the real deployed service; it is not a measure of real-world safety.

    python3 docs/evidence/measure_live.py [BASE_URL] [RUNS]
"""
import json, sys, time, concurrent.futures as cf, statistics, datetime, os

BASE = (sys.argv[1] if len(sys.argv) > 1 else "https://fontokmai-api-945826169258.asia-southeast1.run.app").rstrip("/")
RUNS = int(sys.argv[2]) if len(sys.argv) > 2 else 3
LANG = os.environ.get("LANG_HDR", "th")

cases = []
for clock in ["16:10", "17:15", "18:00", "18:55", "19:30"]:
    for mode in ["car", "transit", "moto"]:
        cases.append({"name": f"{clock}/{mode}", "clock": clock, "body": {"trip_id": "cal-dinner", "mode": mode}})
for q in ["ถ้ารอถึงสองทุ่มค่อยกลับล่ะ", "ไป BTS แทนดีไหม", "ไปสยามตอนหกโมงดีไหม", "นั่งมอไซค์ไปตอนห้าโมงครึ่งได้ไหม"]:
    cases.append({"name": f'16:10 "{q}"', "clock": "16:10", "body": {"question_th": q}})

def call(case, run):
    import subprocess
    t0 = time.time()
    p = subprocess.run(["curl", "-s", "-m", "60", "-X", "POST", BASE + "/v1/decide",
        "-H", "Content-Type: application/json", "-H", "X-Demo-Clock: " + case["clock"], "-H", "Accept-Language: " + LANG,
        "-d", json.dumps(case["body"]), "-w", "\n%{http_code}"], capture_output=True, text=True)
    body, _, code = p.stdout.rpartition("\n")
    if code != "200":
        return {"case": case["name"], "run": run, "error": f"http {code} {body[:120]}", "latency_s": round(time.time() - t0, 2)}
    d = json.loads(body); status = 200
    tools = [s["tool"] for s in d.get("reasoning", [])]
    return {"case": case["name"], "run": run, "status": status, "latency_s": round(time.time() - t0, 2),
            "generated_by": d.get("generated_by"), "model": d.get("model"), "verdict": d.get("verdict"),
            "headline": d.get("headline_th"), "leave_by": d.get("leave_by"), "confidence": d.get("confidence"),
            "guards": [t for t in tools if t.startswith("guardrail")], "tools": [t for t in tools if not t.startswith("guardrail")]}

jobs = [(c, r) for c in cases for r in range(RUNS)]
results = []
with cf.ThreadPoolExecutor(max_workers=4) as ex:
    for res in ex.map(lambda j: call(*j), jobs):
        results.append(res)
        print(res["case"], res["run"], res.get("generated_by"), res.get("verdict"), res.get("guards"), res["latency_s"], flush=True)

ok = [r for r in results if "error" not in r]
gem = [r for r in ok if r["generated_by"] == "gemini"]
fired = [r for r in gem if r["guards"]]
lat = sorted(r["latency_s"] for r in ok)
def pct(p): return lat[min(len(lat) - 1, int(len(lat) * p))] if lat else None
by_guard = {}
for r in gem:
    for g in set(r["guards"]): by_guard[g] = by_guard.get(g, 0) + 1
summary = {
    "base": BASE, "language": LANG, "runs_per_case": RUNS, "cases": len(cases), "calls": len(results),
    "errors": len(results) - len(ok), "answered_by_gemini": len(gem), "fallback": len(ok) - len(gem),
    "models": sorted({r["model"] for r in gem if r["model"]}),
    "guard_fire_rate": round(len(fired) / len(gem), 3) if gem else None, "guard_fired_by_type": by_guard,
    "latency_s": {"p50": pct(0.5), "p95": pct(0.95), "max": lat[-1] if lat else None, "mean": round(statistics.mean(lat), 2) if lat else None},
    "measured_at": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
}
out = {"summary": summary, "results": results}
path = os.path.join(os.path.dirname(os.path.abspath(__file__)), f"live-run-{datetime.date.today().isoformat()}-{LANG}.json")
json.dump(out, open(path, "w"), ensure_ascii=False, indent=2)
print(json.dumps(summary, ensure_ascii=False, indent=2)); print("wrote", path)
