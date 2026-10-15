package clock

import (
	"net/http/httptest"
	"testing"
	"time"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
)

func TestFromRequest(t *testing.T) {
	tests := []struct {
		name     string
		header   string
		demoMode bool
		want     time.Time
		wantDemo bool
		wantErr  bool
	}{
		{"header wins in live mode", "2026-09-29T18:52:00+07:00", false, time.Date(2026, 9, 29, 18, 52, 0, 0, domain.Bangkok), true, false},
		{"header in UTC is converted", "2026-09-29T14:40:00Z", true, time.Date(2026, 9, 29, 21, 40, 0, 0, domain.Bangkok), true, false},
		{"short form uses the demo day", "21:40", true, time.Date(2026, 9, 29, 21, 40, 0, 0, domain.Bangkok), true, false},
		{"demo mode without header starts at 16:10", "", true, DefaultDemoTime, true, false},
		{"garbage header", "tomorrow", true, time.Time{}, false, true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			r := httptest.NewRequest("GET", "/", nil)
			if tt.header != "" {
				r.Header.Set(Header, tt.header)
			}
			c, demo, err := FromRequest(r, tt.demoMode)
			if (err != nil) != tt.wantErr {
				t.Fatalf("err = %v, wantErr %v", err, tt.wantErr)
			}
			if err != nil {
				return
			}
			if !c.Now().Equal(tt.want) || demo != tt.wantDemo {
				t.Fatalf("got %v demo=%v, want %v demo=%v", c.Now(), demo, tt.want, tt.wantDemo)
			}
		})
	}
	r := httptest.NewRequest("GET", "/", nil)
	if c, demo, _ := FromRequest(r, false); demo || time.Since(c.Now()) > time.Minute {
		t.Fatal("live mode without header should use the real clock")
	}
}
