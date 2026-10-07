# Build from the repository root so the BMA flood spot dataset can be copied in:
#   docker build -f api/Dockerfile -t fontokmai-api .
FROM golang:1.24-alpine AS build
WORKDIR /src
COPY api/go.mod api/go.sum ./
RUN go mod download
COPY api/ ./
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/server ./cmd/server

FROM gcr.io/distroless/static-debian12:nonroot
WORKDIR /app
COPY --from=build /out/server /app/server
COPY data/bkk_flood_risk_points.json /app/data/bkk_flood_risk_points.json
ENV PORT=8080 \
    FLOOD_POINTS_PATH=/app/data/bkk_flood_risk_points.json
EXPOSE 8080
USER nonroot:nonroot
ENTRYPOINT ["/app/server"]
