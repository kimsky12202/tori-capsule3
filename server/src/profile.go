package main

import (
	"database/sql"
	"errors"
	"net/http"
	"strings"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/hook"
)

type updateProfileRequest struct {
	Username string `json:"username"`
}

func registerProfileRoutes(app *pocketbase.PocketBase) {
	app.OnServe().Bind(&hook.Handler[*core.ServeEvent]{
		Func: func(e *core.ServeEvent) error {
			e.Router.PATCH("/users/me", func(re *core.RequestEvent) error {
				if re.Auth == nil {
					return re.JSON(http.StatusUnauthorized, map[string]string{"message": "authentication required"})
				}

				var body updateProfileRequest
				if err := re.BindBody(&body); err != nil {
					return re.JSON(http.StatusBadRequest, map[string]string{"message": err.Error()})
				}

				username := strings.TrimSpace(body.Username)
				if username == "" {
					return re.JSON(http.StatusBadRequest, map[string]string{"message": "username is required"})
				}

				usersCol, err := findAuthCollection(app)
				if err != nil {
					return re.JSON(http.StatusInternalServerError, map[string]string{"message": err.Error()})
				}

				user, err := app.FindRecordById(usersCol.Id, re.Auth.Id)
				if err != nil {
					return re.JSON(http.StatusNotFound, map[string]string{"message": "user not found"})
				}

				hasUsernameField := usersCol.Fields.GetByName("username") != nil
				hasNameField := usersCol.Fields.GetByName("name") != nil
				if !hasUsernameField && !hasNameField {
					return re.JSON(http.StatusBadRequest, map[string]string{"message": "profile name field is not configured"})
				}

				if hasUsernameField {
					existing, err := app.FindFirstRecordByData(usersCol.Id, "username", username)
					if err == nil && existing.Id != user.Id {
						return re.JSON(http.StatusConflict, map[string]string{"message": "username already taken"})
					}
					if err != nil && !errors.Is(err, sql.ErrNoRows) {
						return re.JSON(http.StatusBadRequest, map[string]string{"message": err.Error()})
					}

					user.Set("username", username)
				}
				if hasNameField {
					user.Set("name", username)
				}

				if err := app.Save(user); err != nil {
					return re.JSON(http.StatusBadRequest, map[string]string{"message": err.Error()})
				}

				return re.JSON(http.StatusOK, map[string]any{
					"user": map[string]any{
						"id":       user.Id,
						"email":    user.Email(),
						"username": firstNonEmpty(user.GetString("username"), user.GetString("name")),
					},
				})
			})
			return e.Next()
		},
	})
}
