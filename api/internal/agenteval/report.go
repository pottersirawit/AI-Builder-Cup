package agenteval

import (
	"fmt"
	"strings"
)

// Summary is a run at a glance.
type Summary struct {
	Cases        int            `json:"cases"`
	Passed       int            `json:"passed"`
	Errors       int            `json:"errors"`
	GeminiRate   float64        `json:"gemini_rate"` // share of answers written by Gemini, not the fallback
	MeanLatency  int64          `json:"mean_latency_ms"`
	JudgeMean    float64        `json:"judge_mean,omitempty"`
	ChecksRun    map[string]int `json:"checks_run"`
	ChecksFailed map[string]int `json:"checks_failed"`
}

func (r Report) Summary() Summary {
	s := Summary{Cases: len(r.Results), ChecksRun: map[string]int{}, ChecksFailed: map[string]int{}}
	var latency int64
	judged, judgeSum, gemini := 0, 0, 0
	for _, res := range r.Results {
		if res.Passed() {
			s.Passed++
		}
		if res.Err != "" {
			s.Errors++
		}
		if res.GeneratedBy == "gemini" {
			gemini++
		}
		latency += res.LatencyMS
		if res.Judge != nil {
			judged++
			judgeSum += res.Judge.Score
		}
		for _, c := range res.Checks {
			s.ChecksRun[c.Name]++
			if !c.Pass {
				s.ChecksFailed[c.Name]++
			}
		}
	}
	if s.Cases > 0 {
		s.GeminiRate = float64(gemini) / float64(s.Cases)
		s.MeanLatency = latency / int64(s.Cases)
	}
	if judged > 0 {
		s.JudgeMean = float64(judgeSum) / float64(judged)
	}
	return s
}

// Markdown renders the scorecard: totals, pass rate per check, then each
// case with its failures.
func (r Report) Markdown() string {
	s := r.Summary()
	var b strings.Builder
	fmt.Fprintf(&b, "# ผลประเมิน agent ฝนตกไหม (%s)\n\n", r.Model)
	fmt.Fprintf(&b, "ผ่านทุกข้อ %d/%d เคส · Gemini เขียนคำตอบ %.0f%% · เวลาตอบเฉลี่ย %d ms", s.Passed, s.Cases, s.GeminiRate*100, s.MeanLatency)
	if s.JudgeMean > 0 {
		fmt.Fprintf(&b, " · คะแนนภาษาจาก Gemini judge %.1f/5", s.JudgeMean)
	}
	if s.Errors > 0 {
		fmt.Fprintf(&b, " · error %d เคส", s.Errors)
	}
	b.WriteString("\n\n| check | ผ่าน |\n|---|---|\n")
	for _, name := range checkOrder {
		if run := s.ChecksRun[name]; run > 0 {
			fmt.Fprintf(&b, "| %s | %d/%d |\n", name, run-s.ChecksFailed[name], run)
		}
	}
	b.WriteString("\n| เคส | โดย | verdict | แกนคำนวณ | headline | ไม่ผ่าน |\n|---|---|---|---|---|---|\n")
	for _, res := range r.Results {
		var failed []string
		if res.Err != "" {
			failed = append(failed, "error: "+res.Err)
		}
		for _, c := range res.Checks {
			if !c.Pass {
				failed = append(failed, c.Name+" ("+c.Detail+")")
			}
		}
		if res.JudgeErr != "" {
			failed = append(failed, "judge: "+res.JudgeErr)
		} else if res.Judge != nil && res.Judge.Score < 4 {
			failed = append(failed, fmt.Sprintf("judge %d/5: %s", res.Judge.Score, res.Judge.NoteTH))
		}
		fmt.Fprintf(&b, "| %s | %s | %s | %s | %s | %s |\n", res.Case, res.GeneratedBy, res.Verdict, res.CoreVerdict,
			cell(res.HeadlineTH), cell(strings.Join(failed, "; ")))
	}
	return b.String()
}

func cell(s string) string { return strings.ReplaceAll(s, "|", "/") }
