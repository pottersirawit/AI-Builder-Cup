package main

import (
	"encoding/json"
	"io"
	"os"

	"github.com/saransirichote/weather-resilience-gateway/internal/line"
	"github.com/saransirichote/weather-resilience-gateway/internal/model"
)

func main() {
	inputBytes, err := io.ReadAll(os.Stdin)
	if err != nil {
		panic(err)
	}

	var adv model.AdvisoryPayload
	if err := json.Unmarshal(inputBytes, &adv); err != nil {
		panic(err)
	}

	bubble := line.BuildFlexMessageBubble(adv)
	if err := json.NewEncoder(os.Stdout).Encode(bubble); err != nil {
		panic(err)
	}
}
