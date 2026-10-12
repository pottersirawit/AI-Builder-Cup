// Command scorecard scores the /v1/decide agent on the demo storm and prints a
// Markdown scorecard. Without GEMINI_API_KEY or GOOGLE_CLOUD_PROJECT it scores
// the rules fallback offline; with one it runs the real agent (paid calls).
package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"log/slog"
	"os"
	"strings"

	"github.com/pottersirawit/fontokmai/api/internal/agent"
	"github.com/pottersirawit/fontokmai/api/internal/agenteval"
	"github.com/pottersirawit/fontokmai/api/internal/floodspot"
	"github.com/pottersirawit/fontokmai/api/internal/planner"
	"github.com/pottersirawit/fontokmai/api/internal/scenario"
)

func main() {
	floodPoints := flag.String("flood-points", os.Getenv("FLOOD_POINTS_PATH"), "path to bkk_flood_risk_points.json")
	jsonOut := flag.String("json", "", "also write the full report as JSON to this file")
	judge := flag.Bool("judge", false, "ask Gemini to rate each answer's Thai (one extra call per case)")
	only := flag.String("case", "", "run only cases whose name contains this text")
	strict := flag.Bool("strict", false, "exit 1 unless every case passes every check")
	flag.Parse()
	slog.SetDefault(slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{Level: slog.LevelError})))

	path := *floodPoints
	if path == "" {
		path = findData("bkk_flood_risk_points.json")
	}
	spots, err := floodspot.Load(path)
	if err != nil {
		fmt.Fprintln(os.Stderr, "cannot load flood spots; set -flood-points:", err)
		os.Exit(2)
	}
	p := &planner.Planner{Spots: spots, Trips: scenario.Trips, Places: scenario.Places, Whereabouts: scenario.Whereabouts}

	var cases []agenteval.Case
	for _, c := range agenteval.DemoCases() {
		if strings.Contains(c.Name, *only) {
			cases = append(cases, c)
		}
	}
	ctx := context.Background()
	rep := agenteval.Run(ctx, agent.NewGeminiFromEnv(ctx), p, cases, agenteval.Options{Judge: *judge})
	fmt.Print(rep.Markdown())

	if *jsonOut != "" {
		b, _ := json.MarshalIndent(struct {
			agenteval.Report
			Summary agenteval.Summary `json:"summary"`
		}{rep, rep.Summary()}, "", "  ")
		if err := os.WriteFile(*jsonOut, b, 0o644); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(2)
		}
	}
	if s := rep.Summary(); *strict && s.Passed != s.Cases {
		os.Exit(1)
	}
}

func findData(name string) string {
	for _, dir := range []string{"data", "../data", "/app/data"} {
		if _, err := os.Stat(dir + "/" + name); err == nil {
			return dir + "/" + name
		}
	}
	return "data/" + name
}
