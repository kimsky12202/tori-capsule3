package main

import (
	"database/sql"
	"errors"
	"math"
	"net/http"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/hook"
)

const defaultSpotRadiusMeters = 200

func registerTouristSpotRoutes(app *pocketbase.PocketBase) {
	app.OnServe().Bind(&hook.Handler[*core.ServeEvent]{
		Func: func(e *core.ServeEvent) error {
			e.Router.GET("/tourist-spots", listTouristSpots(app))
			e.Router.POST("/tourist-spots/{id}/visit", visitTouristSpot(app))
			return e.Next()
		},
	})
}

func listTouristSpots(app *pocketbase.PocketBase) func(*core.RequestEvent) error {
	return func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.JSON(http.StatusUnauthorized, map[string]string{"message": "unauthorized"})
		}

		spots, err := app.FindAllRecords("tourist_spots", dbx.HashExp{"is_active": true})
		if err != nil {
			return re.JSON(http.StatusInternalServerError, map[string]string{"message": err.Error()})
		}

		visits, err := app.FindAllRecords("tourist_spot_visits", dbx.HashExp{"user": re.Auth.Id})
		if err != nil {
			return re.JSON(http.StatusInternalServerError, map[string]string{"message": err.Error()})
		}
		visitBySpot := make(map[string]*core.Record, len(visits))
		for _, v := range visits {
			visitBySpot[v.GetString("spot")] = v
		}

		sort.Slice(spots, func(i, j int) bool {
			si, sj := spots[i].GetInt("sort_order"), spots[j].GetInt("sort_order")
			if si != sj {
				return si < sj
			}
			return spots[i].GetString("name") < spots[j].GetString("name")
		})

		result := make([]map[string]any, 0, len(spots))
		for _, s := range spots {
			item := map[string]any{
				"id":          s.Id,
				"code":        s.GetString("code"),
				"name":        s.GetString("name"),
				"description": s.GetString("description"),
				"category":    s.GetString("category"),
				"icon":        s.GetString("icon"),
				"color":       s.GetString("color"),
				"image_url":   s.GetString("image_url"),
				"location":    s.Get("location"),
				"radius_m":    spotRadius(s),
				"visited":     false,
			}
			if v, ok := visitBySpot[s.Id]; ok {
				item["visited"] = true
				item["visit"] = map[string]any{
					"source":     v.GetString("source"),
					"capsule":    v.GetString("capsule"),
					"visited_at": v.Get("visited_at"),
				}
			}
			result = append(result, item)
		}

		return re.JSON(http.StatusOK, map[string]any{"spots": result})
	}
}

func visitTouristSpot(app *pocketbase.PocketBase) func(*core.RequestEvent) error {
	return func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.JSON(http.StatusUnauthorized, map[string]string{"message": "unauthorized"})
		}

		spotID := strings.TrimSpace(re.Request.PathValue("id"))
		if spotID == "" {
			return re.JSON(http.StatusBadRequest, map[string]string{"message": "spot id is required"})
		}

		spot, err := app.FindRecordById("tourist_spots", spotID)
		if err != nil {
			return re.JSON(http.StatusNotFound, map[string]string{"message": "tourist spot not found"})
		}

		source := strings.TrimSpace(re.Request.FormValue("source"))
		if source == "" {
			source = "manual"
		}
		capsuleID := strings.TrimSpace(re.Request.FormValue("capsule_id"))
		userLat, hasLat := parseOptionalFloat(re.Request.FormValue("latitude"))
		userLng, hasLng := parseOptionalFloat(re.Request.FormValue("longitude"))

		// The server only enforces the radius when the client supplied a
		// location; capsule-triggered visits may omit it on purpose.
		if hasLat && hasLng {
			point := spot.GetGeoPoint("location")
			dist := haversineMeters(userLat, userLng, point.Lat, point.Lon)
			if dist > float64(spotRadius(spot)) {
				return re.JSON(http.StatusUnprocessableEntity, map[string]any{
					"message":    "out of range",
					"distance_m": math.Round(dist),
					"radius_m":   spotRadius(spot),
				})
			}
		}

		visit, isNew, err := findOrInitSpotVisit(app, re.Auth.Id, spot.Id)
		if err != nil {
			return re.JSON(http.StatusInternalServerError, map[string]string{"message": err.Error()})
		}

		visit.Set("source", source)
		if capsuleID != "" {
			visit.Set("capsule", capsuleID)
		}
		visit.Set("visited_at", time.Now().UTC())
		if hasLat {
			visit.Set("latitude", userLat)
		}
		if hasLng {
			visit.Set("longitude", userLng)
		}

		if err := app.Save(visit); err != nil {
			return re.JSON(http.StatusBadRequest, map[string]string{"message": err.Error()})
		}

		// Only the first discovery of a spot counts toward the challenge so
		// re-checking-in the same place can't inflate progress.
		if isNew {
			trackPlaceVisitedChallenge(app, re.Auth.Id)
		}

		return re.JSON(http.StatusOK, map[string]any{
			"spot_id": spot.Id,
			"visited": true,
			"visit": map[string]any{
				"source":     visit.GetString("source"),
				"capsule":    visit.GetString("capsule"),
				"visited_at": visit.Get("visited_at"),
			},
		})
	}
}

func findOrInitSpotVisit(app *pocketbase.PocketBase, userID, spotID string) (*core.Record, bool, error) {
	record, err := app.FindFirstRecordByFilter(
		"tourist_spot_visits",
		"user = {:user} && spot = {:spot}",
		dbx.Params{"user": userID, "spot": spotID},
	)
	if err == nil {
		return record, false, nil
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return nil, false, err
	}

	collection, err := app.FindCollectionByNameOrId("tourist_spot_visits")
	if err != nil {
		return nil, false, err
	}

	record = core.NewRecord(collection)
	record.Set("user", userID)
	record.Set("spot", spotID)

	return record, true, nil
}

// discoverNearbyTouristSpotsForCapsule 는 캡슐 묻은 위치 근처의 관광지를 자동으로
// 방문 처리한다. 캡슐 생성 직후에 호출됨. 이미 방문한 관광지는 건드리지 않음.
// 실패는 로그만 남기고 캡슐 생성 흐름을 막지 않음 (best-effort).
func discoverNearbyTouristSpotsForCapsule(
	app *pocketbase.PocketBase,
	userID, capsuleID string,
	lat, lng float64,
) {
	spots, err := app.FindAllRecords("tourist_spots", dbx.HashExp{"is_active": true})
	if err != nil {
		return
	}
	for _, spot := range spots {
		point := spot.GetGeoPoint("location")
		dist := haversineMeters(lat, lng, point.Lat, point.Lon)
		if dist > float64(spotRadius(spot)) {
			continue
		}

		visit, isNew, err := findOrInitSpotVisit(app, userID, spot.Id)
		if err != nil {
			continue
		}
		// 이미 다른 경로로 방문한 곳은 source/visited_at 을 덮어쓰지 않는다.
		if !isNew {
			continue
		}

		visit.Set("source", "capsule")
		visit.Set("capsule", capsuleID)
		visit.Set("visited_at", time.Now().UTC())
		visit.Set("latitude", lat)
		visit.Set("longitude", lng)
		if err := app.Save(visit); err != nil {
			continue
		}
		trackPlaceVisitedChallenge(app, userID)
	}
}

func spotRadius(s *core.Record) int {
	r := s.GetInt("radius_m")
	if r <= 0 {
		return defaultSpotRadiusMeters
	}
	return r
}

func parseOptionalFloat(raw string) (float64, bool) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return 0, false
	}
	v, err := strconv.ParseFloat(raw, 64)
	if err != nil {
		return 0, false
	}
	return v, true
}

func haversineMeters(lat1, lon1, lat2, lon2 float64) float64 {
	const earth = 6371000.0
	rad := math.Pi / 180
	dLat := (lat2 - lat1) * rad
	dLon := (lon2 - lon1) * rad
	h := math.Sin(dLat/2)*math.Sin(dLat/2) +
		math.Cos(lat1*rad)*math.Cos(lat2*rad)*math.Sin(dLon/2)*math.Sin(dLon/2)
	return earth * 2 * math.Atan2(math.Sqrt(h), math.Sqrt(1-h))
}
