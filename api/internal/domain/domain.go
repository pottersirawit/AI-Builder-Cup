// Package domain holds the shared vocabulary of the ฝนตกไหม API (see CONTEXT.md)
// and the seams (interfaces) that every data source plugs into.
package domain

import (
	"context"
	"strings"
	"time"
)

// Bangkok is Indochina Time. A fixed zone keeps distroless images free of tzdata.
var Bangkok = time.FixedZone("ICT", 7*60*60)

type LatLng struct {
	Lat float64 `json:"lat"`
	Lng float64 `json:"lng"`
}

// Mode is how the traveller moves. Each mode maps to a Vehicle Clearance Profile.
type Mode string

const (
	ModeCar     Mode = "car"
	ModeTransit Mode = "transit"
	ModeMoto    Mode = "moto"
)

var AllModes = []Mode{ModeCar, ModeTransit, ModeMoto}

func (m Mode) Valid() bool { return m == ModeCar || m == ModeTransit || m == ModeMoto }

// NameTH is the label shown to the user.
func (m Mode) NameTH() string {
	switch m {
	case ModeTransit:
		return "BTS / MRT"
	case ModeMoto:
		return "มอเตอร์ไซค์"
	default:
		return "รถยนต์"
	}
}

// NameFor is the mode's label in l: "car", "BTS / MRT" or "motorbike" in
// English, NameTH in Thai.
func (m Mode) NameFor(l Lang) string {
	if l != LangEN {
		return m.NameTH()
	}
	switch m {
	case ModeTransit:
		return "BTS / MRT"
	case ModeMoto:
		return "motorbike"
	default:
		return "car"
	}
}

// Place is a named point. A place at (0,0) is unresolved: only its name is
// known (an event location we could not geocode), and its JSON has no lat/lng.
type Place struct {
	NameTH string  `json:"name_th"`
	Lat    float64 `json:"lat,omitempty"`
	Lng    float64 `json:"lng,omitempty"`
}

func (p Place) Point() LatLng { return LatLng{p.Lat, p.Lng} }

// Resolved reports whether p has coordinates.
func (p Place) Resolved() bool { return p.Lat != 0 || p.Lng != 0 }

// Kinds of saved place. A user has at most one home and one work place.
const (
	KindHome  = "home"
	KindWork  = "work"
	KindOther = "other"
)

// SavedPlace is a place the user has named in the app (บ้าน, ที่ทำงาน, ...).
// Keywords are the words that point at it in a typed Thai question.
type SavedPlace struct {
	ID      string `json:"id"`
	Kind    string `json:"kind"`
	LabelTH string `json:"label_th"`
	Place
	Keywords []string `json:"-"`
}

// LabelFor is the label to show in l. In English a Thai label becomes "Home",
// "Work", or the place's first Latin keyword ("siam" -> "Siam"); a label the
// user typed in Latin letters is theirs and stays.
func (p SavedPlace) LabelFor(l Lang) string {
	if l != LangEN || !HasThai(p.LabelTH) {
		return p.LabelTH
	}
	switch p.Kind {
	case KindHome:
		return "Home"
	case KindWork:
		return "Work"
	}
	for _, kw := range p.Keywords {
		if kw != "" && !HasThai(kw) {
			return strings.ToUpper(kw[:1]) + kw[1:]
		}
	}
	return p.LabelTH
}

// HasThai reports whether s contains a Thai letter.
func HasThai(s string) bool {
	for _, r := range s {
		if r >= 0x0E00 && r <= 0x0E7F {
			return true
		}
	}
	return false
}

type Trip struct {
	ID          string    `json:"id"`
	TitleTH     string    `json:"title_th"`
	Source      string    `json:"source"`
	Origin      Place     `json:"origin"`
	Destination Place     `json:"destination"`
	ArriveBy    time.Time `json:"arrive_by,omitzero"` // zero for a typed trip with no deadline
	Mode        Mode      `json:"mode"`
	EndsAt      time.Time `json:"ends_at,omitzero"`
	// Virtual is an online meeting and AllDay an all-day event: neither is travel.
	Virtual bool `json:"virtual,omitempty"`
	AllDay  bool `json:"all_day,omitempty"`
	// LocationTextTH is the event's location as written, kept when Destination
	// is unresolved so the app can ask the user where it is.
	LocationTextTH string `json:"location_text_th,omitempty"`
	// InferredPlace reports whether Destination was inferred from the event title
	// rather than explicitly set in the event's location field or confirmed by the user.
	InferredPlace bool `json:"inferred_place,omitempty"`
	// NoteTH says how the trip was found when that is not obvious, such as an
	// email Gemini read.
	NoteTH string `json:"note_th,omitempty"`
}

// Plannable reports whether t is travel the planner can route: a real trip
// with both ends resolved.
func (t Trip) Plannable() bool {
	return !t.Virtual && t.Origin.Resolved() && t.Destination.Resolved()
}

// TransitLeg is one rail/transit segment from a boarding station to an alighting station.
type TransitLeg struct {
	LineTH        string `json:"line_th"`
	FromStationTH string `json:"from_station_th"`
	ToStationTH   string `json:"to_station_th"`
	StopCount     int    `json:"stop_count,omitempty"`
}

// Route is one way of getting from origin to destination with one mode.
type Route struct {
	Mode        Mode         `json:"mode"`
	Polyline    []LatLng     `json:"-"`
	DurationMin int          `json:"duration_min"`
	ViaTH       []string     `json:"via_th"`
	TransitLegs []TransitLeg `json:"transit_legs,omitempty"`
	Source      string       `json:"source"`
}

// RainSample is precipitation intensity valid from Time until the next sample.
type RainSample struct {
	Time    time.Time `json:"time"`
	MMPerHr float64   `json:"mm_per_hr"`
	ProbPct int       `json:"prob_pct,omitempty"`
}

type CanalReading struct {
	StationID string  `json:"station_id"`
	NameTH    string  `json:"name_th"`
	NameEN    string  `json:"-"` // English station name when the source has one
	Lat       float64 `json:"lat"`
	Lng       float64 `json:"lng"`
	LevelM    float64 `json:"level_m"`
	BankM     float64 `json:"bank_m"`
	RiseCM2h  float64 `json:"rise_cm_2h"`
	Source    string  `json:"source"`
}

// Passable is the per-mode verdict of a flood photo: yes, slow or no.
type Passable struct {
	Car     string `json:"car"`
	Transit string `json:"transit"`
	Moto    string `json:"moto"`
}

// Report is a community flood photo report, assessed by Gemini vision.
type Report struct {
	ID            string    `json:"id"`
	Lat           float64   `json:"lat"`
	Lng           float64   `json:"lng"`
	CreatedAt     time.Time `json:"created_at"`
	DepthCMMin    int       `json:"depth_cm_min"`
	DepthCMMax    int       `json:"depth_cm_max"`
	Confidence    float64   `json:"confidence"`
	DescriptionTH string    `json:"description_th"`
	Passable      Passable  `json:"passable"`
	GeneratedBy   string    `json:"generated_by,omitempty"`
}

func (r Report) Point() LatLng { return LatLng{r.Lat, r.Lng} }

// MockUser is a commuter whose usual route we know, used for report fan-out.
type MockUser struct {
	ID    string
	Route []LatLng
}

// Clock tells the current time. The demo clock replays the มิว scenario.
type Clock interface {
	Now() time.Time
}

// WeatherProvider forecasts rain at a point between from and to.
type WeatherProvider interface {
	Rain(ctx context.Context, at LatLng, from, to time.Time) ([]RainSample, error)
	Name() string
}

// RouteProvider plans a route for one mode departing at a given time.
type RouteProvider interface {
	Route(ctx context.Context, from, to LatLng, mode Mode, departAt time.Time) (Route, error)
	Name() string
}

// CanalProvider reports canal stage levels near a point at a given time.
type CanalProvider interface {
	Canals(ctx context.Context, near LatLng, at time.Time) ([]CanalReading, error)
	Name() string
}

// ReportStore keeps community flood reports.
type ReportStore interface {
	Add(ctx context.Context, r Report) (Report, error)
	// Near returns reports within radiusM of center created in [since, until].
	Near(ctx context.Context, center LatLng, radiusM float64, since, until time.Time) ([]Report, error)
}

// TravelTimer is an optional RouteProvider capability: cheap duration lookups
// for many candidate departures, used to search for the latest safe departure.
type TravelTimer interface {
	TravelMinutes(from, to LatLng, mode Mode, departAt time.Time) int
}

// WeatherNextProvider provides high-resolution ~5km weather grid predictions,
// surface wind gusts, and peak atmospheric conditions along commute routes.
type WeatherNextProvider interface {
	PeakConditionsAlongRoute(polyline []LatLng) (maxGust float64, maxTemp float64, err error)
	Name() string
}

// RoadFloodSensor represents in-situ telemetry from BMA road flood sensors.
type RoadFloodSensor struct {
	Code      string    `json:"code"`
	NameTH    string    `json:"name_th"`
	NameEN    string    `json:"name_en"`
	Lat       float64   `json:"lat"`
	Lng       float64   `json:"lng"`
	DepthCM   float64   `json:"depth_cm"`
	UpdatedAt time.Time `json:"updated_at"`
}

// Point returns the geographical coordinates of the sensor.
func (s RoadFloodSensor) Point() LatLng { return LatLng{Lat: s.Lat, Lng: s.Lng} }

// RoadFloodProvider delivers live in-situ water depth from municipal road flood sensors.
type RoadFloodProvider interface {
	SensorsNearRoute(polyline []LatLng, radiusM float64) ([]RoadFloodSensor, error)
	Name() string
}

// TidalReading captures daily sea-tide backwater potential in the lower Chao Phraya river.
type TidalReading struct {
	HighTideM    float64   `json:"high_tide_m"`
	HighTideTime time.Time `json:"high_tide_time"`
	LowTideM     float64   `json:"low_tide_m"`
	SurgeRisk    string    `json:"surge_risk"` // "low", "medium", "high"
}

// TidalProvider provides astronomical high tide & canal drainage backwater potential.
type TidalProvider interface {
	TidalStatus(ctx context.Context, at time.Time) (TidalReading, error)
	Name() string
}

// EmergencyContact details an official government emergency helpline during severe weather/flooding.
type EmergencyContact struct {
	AgencyTH  string `json:"agency_th"`
	AgencyEN  string `json:"agency_en"`
	Number    string `json:"number"`
	PurposeTH string `json:"purpose_th"`
	PurposeEN string `json:"purpose_en"`
	LineID    string `json:"line_id,omitempty"`
}

// HotlineProvider supplies official emergency dispatch contacts.
type HotlineProvider interface {
	EmergencyContacts() []EmergencyContact
	Name() string
}
