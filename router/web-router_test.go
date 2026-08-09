package router

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"testing/fstest"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/require"
)

func TestServeAboutPageHandlesBothTrailingSlashForms(t *testing.T) {
	gin.SetMode(gin.TestMode)
	fileSystem := http.FS(fstest.MapFS{
		"about/index.html": &fstest.MapFile{Data: []byte("about")},
	})
	handler := serveAboutPage(fileSystem)

	for _, path := range []string{"/about", "/about/"} {
		engine := gin.New()
		engine.Use(handler)
		engine.NoRoute(func(c *gin.Context) {
			c.Status(http.StatusNotFound)
		})

		request := httptest.NewRequest(http.MethodGet, "https://example.test"+path, nil)
		response := httptest.NewRecorder()
		engine.ServeHTTP(response, request)

		require.Equal(t, http.StatusOK, response.Code, path)
		require.Empty(t, response.Header().Get("Location"), path)
		require.Equal(t, "about", response.Body.String(), path)
	}
}
