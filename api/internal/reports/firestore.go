package reports

import (
	"context"
	"fmt"
	"time"

	"cloud.google.com/go/firestore"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
	"github.com/pottersirawit/fontokmai/api/internal/geo"
)

// FirestoreStore keeps reports in one Firestore collection so they survive
// restarts and are shared by every Cloud Run instance. Like MemoryStore it only
// returns reports created inside the requested window, so seeded reports still
// replay with the demo clock.
type FirestoreStore struct {
	client *firestore.Client
	col    *firestore.CollectionRef
}

// NewFirestoreStore connects with Application Default Credentials. An empty
// projectID is detected from the environment (the Cloud Run service's project).
func NewFirestoreStore(ctx context.Context, projectID, collection string) (*FirestoreStore, error) {
	if projectID == "" {
		projectID = firestore.DetectProjectID
	}
	client, err := firestore.NewClient(ctx, projectID)
	if err != nil {
		return nil, fmt.Errorf("firestore: %w", err)
	}
	return &FirestoreStore{client: client, col: client.Collection(collection)}, nil
}

func (s *FirestoreStore) Close() error { return s.client.Close() }

// Add writes r under its ID (so re-seeding is idempotent) or a new random ID.
func (s *FirestoreStore) Add(ctx context.Context, r domain.Report) (domain.Report, error) {
	doc := s.col.NewDoc()
	if r.ID != "" {
		doc = s.col.Doc(r.ID)
	}
	r.ID = doc.ID
	if _, err := doc.Set(ctx, toDoc(r)); err != nil {
		return domain.Report{}, fmt.Errorf("firestore add report: %w", err)
	}
	return r, nil
}

// Near queries the time window (a single-field range, no composite index
// needed) and filters by distance in memory.
func (s *FirestoreStore) Near(ctx context.Context, center domain.LatLng, radiusM float64, since, until time.Time) ([]domain.Report, error) {
	docs, err := s.col.Where("created_at", ">=", since).Where("created_at", "<=", until).
		OrderBy("created_at", firestore.Asc).Documents(ctx).GetAll()
	if err != nil {
		return nil, fmt.Errorf("firestore near reports: %w", err)
	}
	var out []domain.Report
	for _, d := range docs {
		var rd reportDoc
		if err := d.DataTo(&rd); err != nil {
			return nil, fmt.Errorf("firestore report %s: %w", d.Ref.ID, err)
		}
		if r := fromDoc(d.Ref.ID, rd); geo.HaversineM(center, r.Point()) <= radiusM {
			out = append(out, r)
		}
	}
	return out, nil
}

// reportDoc is the stored shape of a Report; the ID is the document ID.
type reportDoc struct {
	Lat             float64   `firestore:"lat"`
	Lng             float64   `firestore:"lng"`
	CreatedAt       time.Time `firestore:"created_at"`
	DepthCMMin      int       `firestore:"depth_cm_min"`
	DepthCMMax      int       `firestore:"depth_cm_max"`
	Confidence      float64   `firestore:"confidence"`
	DescriptionTH   string    `firestore:"description_th"`
	PassableCar     string    `firestore:"passable_car"`
	PassableTransit string    `firestore:"passable_transit"`
	PassableMoto    string    `firestore:"passable_moto"`
	GeneratedBy     string    `firestore:"generated_by"`
}

func toDoc(r domain.Report) reportDoc {
	return reportDoc{
		Lat: r.Lat, Lng: r.Lng, CreatedAt: r.CreatedAt, DepthCMMin: r.DepthCMMin, DepthCMMax: r.DepthCMMax,
		Confidence: r.Confidence, DescriptionTH: r.DescriptionTH,
		PassableCar: r.Passable.Car, PassableTransit: r.Passable.Transit, PassableMoto: r.Passable.Moto,
		GeneratedBy: r.GeneratedBy,
	}
}

func fromDoc(id string, d reportDoc) domain.Report {
	return domain.Report{
		ID: id, Lat: d.Lat, Lng: d.Lng, CreatedAt: d.CreatedAt.In(domain.Bangkok), DepthCMMin: d.DepthCMMin, DepthCMMax: d.DepthCMMax,
		Confidence: d.Confidence, DescriptionTH: d.DescriptionTH,
		Passable:    domain.Passable{Car: d.PassableCar, Transit: d.PassableTransit, Moto: d.PassableMoto},
		GeneratedBy: d.GeneratedBy,
	}
}
