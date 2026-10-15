package domain

// Label is the mode's name for the user in l.
func (m Mode) Label(l Lang) string {
	switch m {
	case ModeTransit:
		return "BTS / MRT"
	case ModeMoto:
		return l.Pick("มอเตอร์ไซค์", "Motorbike")
	default:
		return l.Pick("รถยนต์", "Car")
	}
}
