# Live measurements

`measure_live.py` sends the 19 demo-storm cases of `api/cmd/scorecard` to the deployed
`/v1/decide` three times each and records who answered, latency, the verdict and
whether a guardrail fired. Raw results are in the `live-run-*.json` files next to it.

## 2026-10-15, Cloud Run revision `fontokmai-api-00008-h8f` (Thai, `gemini-2.5-flash` on Vertex AI)

| | |
|---|---|
| Calls | 57 (19 cases x 3), 0 errors |
| Answered by Gemini | 55 (96%); 2 fell back to the rules engine |
| Guard fired on Gemini answers | 9 of 55 (16%), all `guardrail_verdict` (Gemini proposed a different verdict than the engine) |
| Latency | p50 12.7 s, p95 21.4 s, max 23.8 s |
| Verdict stability | the same verdict on all three runs of every case |

The guard-fire rate counts answers the safety layer had to correct. It is not a measure of
real-world safety: the engine's thresholds define "correct", and no ground truth from real trips exists.
The storm is a scripted replay, so these figures describe the demo scenario only.
