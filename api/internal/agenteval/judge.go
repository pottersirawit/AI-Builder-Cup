package agenteval

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"google.golang.org/genai"

	"github.com/pottersirawit/fontokmai/api/internal/agent"
	"github.com/pottersirawit/fontokmai/api/internal/decision"
)

// JudgeScore is Gemini's rating of one answer as a Bangkok commuter would read it.
type JudgeScore struct {
	Score  int    `json:"score"` // 1-5
	NoteTH string `json:"note_th"`
}

const judgePrompt = `คุณเป็นผู้ตรวจคำตอบของแอป "ฝนตกไหม" ที่บอกคนกรุงเทพฯ ว่าควรออกเดินทางตอนไหน ด้วยอะไร
ให้คะแนน 1-5 จากมุมมองคนที่อ่านบนมือถือตอนรีบ:
5 = ภาษาไทยเป็นธรรมชาติเหมือนเพื่อนบอก, ตรงกับข้อมูลทุกตัวเลข, บอกว่าต้องทำอะไรภายในประโยคแรก
3 = เข้าใจได้แต่แข็งหรือยาวเกิน หรือขาดเหตุผลสำคัญ
1 = ผิดข้อมูล ขัดกับผลประเมิน หรืออ่านไม่รู้เรื่อง
note_th: เหตุผลสั้น ๆ 1 ประโยค ถ้าหักคะแนนให้บอกจุดที่ต้องแก้`

var judgeSchema = &genai.Schema{
	Type: genai.TypeObject,
	Properties: map[string]*genai.Schema{
		"score":   {Type: genai.TypeInteger},
		"note_th": {Type: genai.TypeString},
	},
	Required: []string{"score", "note_th"},
}

// Judge asks Gemini to rate an answer's Thai and its faithfulness to the
// engine's numbers. It is advisory: callers report a failure, never score it.
func Judge(ctx context.Context, g *agent.Gemini, resp agent.Response, core decision.Result) (JudgeScore, error) {
	if !g.Available() {
		return JudgeScore{}, errors.New("judge needs Gemini")
	}
	ctx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()
	leaveBy := "ไม่มี"
	if core.LeaveBy != nil {
		leaveBy = core.LeaveBy.Format("15:04")
	}
	var modes []string
	for _, o := range core.ModeOptions {
		modes = append(modes, fmt.Sprintf("%s: %s, ความเสี่ยง %s, %d นาที", o.Mode, o.Verdict, o.Risk, o.EtaMin))
	}
	facts := fmt.Sprintf("ข้อมูลจากระบบคำนวณ: ออก %s ด้วย %s, ผลประเมิน %s, ออกได้ถึง %s\n%s",
		resp.DepartAt.Format("15:04"), resp.Mode, core.Verdict, leaveBy, strings.Join(modes, "\n"))
	answer := fmt.Sprintf("คำตอบที่ผู้ใช้เห็น:\nหัวข้อ: %s\nสรุป: %s\nเหตุผล: %s",
		resp.HeadlineTH, resp.SummaryTH, resp.Explanation.ReasonWhyTH)
	zero := float32(0)
	out, _, err := g.Generate(ctx, []*genai.Content{genai.NewContentFromText(facts+"\n\n"+answer, genai.RoleUser)},
		&genai.GenerateContentConfig{
			SystemInstruction: genai.NewContentFromText(judgePrompt, genai.RoleUser),
			Temperature:       &zero, ResponseMIMEType: "application/json", ResponseSchema: judgeSchema,
		})
	if err != nil {
		return JudgeScore{}, err
	}
	var j JudgeScore
	if err := json.Unmarshal([]byte(out.Text()), &j); err != nil {
		return JudgeScore{}, fmt.Errorf("judge JSON: %w", err)
	}
	if j.Score < 1 || j.Score > 5 {
		return JudgeScore{}, fmt.Errorf("judge score %d out of range", j.Score)
	}
	return j, nil
}
