package httpapi

import (
	"bytes"
	"errors"
	"image"
	_ "image/jpeg" // registers the decoders image.DecodeConfig needs
	_ "image/png"
	"sync"
	"time"
)

// ReportLimits bounds POST /v1/reports: the photo goes to Gemini and, when it
// is real flood evidence, to every commuter near it. Zero fields take the defaults.
type ReportLimits struct {
	MaxUploadBytes int64         // largest accepted photo
	MaxDimension   int           // largest accepted photo width or height in pixels
	Uploads        int           // uploads allowed per client in Window
	Window         time.Duration // sliding window for Uploads
}

var defaultReportLimits = ReportLimits{MaxUploadBytes: 6 << 20, MaxDimension: 8000, Uploads: 10, Window: 10 * time.Minute}

func (l ReportLimits) withDefaults() ReportLimits {
	d := defaultReportLimits
	if l.MaxUploadBytes > 0 {
		d.MaxUploadBytes = l.MaxUploadBytes
	}
	if l.MaxDimension > 0 {
		d.MaxDimension = l.MaxDimension
	}
	if l.Uploads > 0 {
		d.Uploads = l.Uploads
	}
	if l.Window > 0 {
		d.Window = l.Window
	}
	return d
}

// uploadLimiter is an in-memory sliding-window counter per client IP. It is per
// Cloud Run instance, which is enough to stop casual abuse.
type uploadLimiter struct {
	mu   sync.Mutex
	hits map[string][]time.Time
}

func (u *uploadLimiter) allow(key string, now time.Time, limit int, window time.Duration) bool {
	u.mu.Lock()
	defer u.mu.Unlock()
	if u.hits == nil {
		u.hits = map[string][]time.Time{}
	}
	if len(u.hits) > 5000 {
		for k, ts := range u.hits {
			if len(ts) == 0 || now.Sub(ts[len(ts)-1]) >= window {
				delete(u.hits, k)
			}
		}
	}
	recent := u.hits[key][:0]
	for _, t := range u.hits[key] {
		if now.Sub(t) < window {
			recent = append(recent, t)
		}
	}
	if len(recent) >= limit {
		u.hits[key] = recent
		return false
	}
	u.hits[key] = append(recent, now)
	return true
}

var errImageTooLarge = errors.New("image dimensions too large")

// checkDimensions rejects JPEG/PNG photos larger than max pixels per side.
// Formats the standard library cannot read (HEIC, WebP) pass; Gemini sees them.
func checkDimensions(photo []byte, max int) error {
	cfg, _, err := image.DecodeConfig(bytes.NewReader(photo))
	if err != nil {
		return nil
	}
	if cfg.Width > max || cfg.Height > max {
		return errImageTooLarge
	}
	return nil
}
