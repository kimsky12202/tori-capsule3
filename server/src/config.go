package main

import (
	"net/http"
	"os"
	"strings"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/hook"
)

// 인증된 사용자에게만 공개 가능한 런타임 설정값을 돌려준다.
// 클라이언트 코드에 토큰을 박지 않기 위해 만들어진 엔드포인트.
func registerConfigRoutes(app *pocketbase.PocketBase) {
	app.OnServe().Bind(&hook.Handler[*core.ServeEvent]{
		Func: func(e *core.ServeEvent) error {
			e.Router.GET("/config/mapbox-token", func(re *core.RequestEvent) error {
				if re.Auth == nil {
					return re.JSON(http.StatusUnauthorized, map[string]string{"message": "unauthorized"})
				}
				token := strings.TrimSpace(os.Getenv("MAPBOX_TOKEN"))
				if token == "" {
					return re.JSON(http.StatusNotFound, map[string]string{
						"message": "MAPBOX_TOKEN not configured on server",
					})
				}
				return re.JSON(http.StatusOK, map[string]string{"token": token})
			})
			return e.Next()
		},
	})
}
