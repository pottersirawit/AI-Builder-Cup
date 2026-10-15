// Package clock provides the real clock and the demo clock that replays the scenario.
package clock

import (
	"fmt"
	"net/http"
	"time"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
)

// Header carries the demo time, e.g. "2026-09-29T16:10:00+07:00".
const Header = "X-Demo-Clock"

// DefaultDemoTime is beat 1 of the demo: the 16:10 push notification.
var DefaultDemoTime = time.Date(2026, 9, 29, 16, 10, 0, 0, domain.Bangkok)

type Real struct{}

func (Real) Now() time.Time { return time.Now().In(domain.Bangkok) }

type Fixed time.Time

func (f Fixed) Now() time.Time { return time.Time(f).In(domain.Bangkok) }

// FromRequest picks the clock for one request. A valid X-Demo-Clock header always
// wins and reports demo=true; otherwise demo mode uses DefaultDemoTime and live
// mode uses the real clock.
func FromRequest(r *http.Request, demoMode bool) (c domain.Clock, demo bool, err error) {
	if v := r.Header.Get(Header); v != "" {
		t, err := Parse(v)
		if err != nil {
			return nil, false, err
		}
		return Fixed(t), true, nil
	}
	if demoMode {
		return Fixed(DefaultDemoTime), true, nil
	}
	return Real{}, false, nil
}

// Parse accepts RFC 3339 and, for convenience, a bare "15:04" on the demo day.
func Parse(v string) (time.Time, error) {
	if t, err := time.Parse(time.RFC3339, v); err == nil {
		return t.In(domain.Bangkok), nil
	}
	if t, err := time.ParseInLocation("15:04", v, domain.Bangkok); err == nil {
		d := DefaultDemoTime
		return time.Date(d.Year(), d.Month(), d.Day(), t.Hour(), t.Minute(), 0, 0, domain.Bangkok), nil
	}
	return time.Time{}, fmt.Errorf("invalid %s %q: want RFC 3339 like 2026-09-29T16:10:00+07:00", Header, v)
}
