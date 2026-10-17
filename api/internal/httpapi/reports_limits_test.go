package httpapi

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"image"
	"image/png"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"testing"

	"google.golang.org/genai"

	"github.com/pottersirawit/fontokmai/api/internal/agent"
)

type fakeVision struct{ text string }

func (f fakeVision) GenerateContent(context.Context, string, []*genai.Content, *genai.GenerateContentConfig) (*genai.GenerateContentResponse, error) {
	return &genai.GenerateContentResponse{Candidates: []*genai.Candidate{{Content: &genai.Content{Parts: []*genai.Part{{Text: f.text}}}}}}, nil
}

const floodJSON = `{"depth_cm_min":30,"depth_cm_max":40,"confidence":0.8,"is_flood_scene":%s,"looks_like_screenshot":false,"description_th":"น้ำถึงครึ่งล้อ","passable":{"car":"no","transit":"yes","moto":"no"}}`

func postPhoto(t *testing.T, h http.Handler, photo []byte, ip string) (int, map[string]any) {
	t.Helper()
	var buf bytes.Buffer
	mw := multipart.NewWriter(&buf)
	mw.WriteField("lat", "13.8130")
	mw.WriteField("lng", "100.5760")
	fw, _ := mw.CreateFormFile("photo", "flood.jpg")
	fw.Write(photo)
	mw.Close()
	r := httptest.NewRequest("POST", "/v1/reports", &buf)
	r.Header.Set("Content-Type", mw.FormDataContentType())
	r.Header.Set("X-Demo-Clock", "2026-09-29T18:52:00+07:00")
	r.Header.Set("X-Forwarded-For", ip)
	w := httptest.NewRecorder()
	h.ServeHTTP(w, r)
	var out map[string]any
	if w.Body.Len() > 0 {
		if err := json.Unmarshal(w.Body.Bytes(), &out); err != nil {
			t.Fatalf("not JSON: %s", w.Body.String())
		}
	}
	return w.Code, out
}

func countReports(t *testing.T, h http.Handler) int {
	_, list := do(t, h, "GET", "/v1/reports?lat=13.8130&lng=100.5760&radius_m=300", "2026-09-29T18:55:00+07:00", nil, "")
	return len(list["reports"].([]any))
}

func TestOnlyGeminiEvidenceIsStored(t *testing.T) {
	tests := []struct {
		name, flood string
		wantStored  int
		wantStatus  int
		wantBy      string
	}{
		{"flood photo is stored", "true", 3, 201, "gemini"},
		{"non flood photo is not stored", "false", 2, 400, "rejected"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			s := newTestServer(t, true)
			s.Gemini = &agent.Gemini{Gen: fakeVision{text: fmt.Sprintf(floodJSON, tt.flood)}}
			h := s.Handler()
			status, out := postPhoto(t, h, []byte("\xff\xd8\xff\xe0 fake jpeg"), "1.1.1.1")
			if status != tt.wantStatus {
				t.Fatalf("status %d, want %d: %v", status, tt.wantStatus, out)
			}
			if tt.wantStatus == 201 && out["generated_by"] != tt.wantBy {
				t.Fatalf("generated_by %v, want %s", out["generated_by"], tt.wantBy)
			}
			if n := countReports(t, h); n != tt.wantStored {
				t.Fatalf("stored %d reports, want %d", n, tt.wantStored)
			}
		})
	}
}

func TestReportUploadLimits(t *testing.T) {
	s := newTestServer(t, true)
	s.ReportLimits = ReportLimits{MaxUploadBytes: 1000, MaxDimension: 50, Uploads: 3}
	h := s.Handler()
	jpeg := []byte("\xff\xd8\xff\xe0 fake jpeg")

	if status, _ := postPhoto(t, h, make([]byte, 5000), "2.2.2.2"); status != 413 {
		t.Errorf("oversized photo: status %d, want 413", status)
	}
	var big bytes.Buffer
	png.Encode(&big, image.NewRGBA(image.Rect(0, 0, 60, 10)))
	if status, _ := postPhoto(t, h, big.Bytes(), "2.2.2.2"); status != 413 {
		t.Errorf("oversized dimensions: status %d, want 413", status)
	}
	// Two attempts above plus this one use the 3 allowed uploads for 2.2.2.2.
	if status, _ := postPhoto(t, h, jpeg, "2.2.2.2"); status != 201 {
		t.Errorf("third upload: status %d, want 201", status)
	}
	if status, out := postPhoto(t, h, jpeg, "2.2.2.2"); status != 429 {
		t.Errorf("fourth upload: status %d %v, want 429", status, out)
	}
	if status, _ := postPhoto(t, h, jpeg, "3.3.3.3"); status != 201 {
		t.Errorf("another client: status %d, want 201", status)
	}
}
