package reports

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
	"github.com/pottersirawit/fontokmai/api/internal/scenario"
)

func TestReportDocRoundTrip(t *testing.T) {
	r := scenario.SeedReports()[0]
	r.GeneratedBy = "gemini"
	got := fromDoc(r.ID, toDoc(r))
	if got.ID != r.ID || got.Lat != r.Lat || got.Lng != r.Lng || !got.CreatedAt.Equal(r.CreatedAt) || got.CreatedAt.Location() != domain.Bangkok ||
		got.DepthCMMin != r.DepthCMMin || got.DepthCMMax != r.DepthCMMax || got.Confidence != r.Confidence ||
		got.DescriptionTH != r.DescriptionTH || got.Passable != r.Passable || got.GeneratedBy != "gemini" {
		t.Fatalf("round trip\n got %+v\nwant %+v", got, r)
	}
}

// TestFirestoreStoreAgainstEmulator runs only with the Firestore emulator
// (gcloud emulators firestore start; export FIRESTORE_EMULATOR_HOST=...), so the
// default test run stays offline.
func TestFirestoreStoreAgainstEmulator(t *testing.T) {
	if os.Getenv("FIRESTORE_EMULATOR_HOST") == "" {
		t.Skip("FIRESTORE_EMULATOR_HOST not set")
	}
	ctx := context.Background()
	s, err := NewFirestoreStore(ctx, "demo-fontokmai", "reports-test-"+time.Now().Format("150405.000"))
	if err != nil {
		t.Fatal(err)
	}
	defer s.Close()
	for _, r := range scenario.SeedReports() {
		if _, err := s.Add(ctx, r); err != nil {
			t.Fatal(err)
		}
	}
	added, err := s.Add(ctx, domain.Report{Lat: scenario.HeroReportPoint.Lat, Lng: scenario.HeroReportPoint.Lng, CreatedAt: at(18, 52)})
	if err != nil || added.ID == "" {
		t.Fatalf("add: %+v %v", added, err)
	}
	testNear(t, s)
}
