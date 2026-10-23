package router

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"testing/fstest"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestServeAboutPageHandlesBothTrailingSlashForms(t *testing.T) {
	gin.SetMode(gin.TestMode)
	fileSystem := http.FS(fstest.MapFS{
		"about/index.html": &fstest.MapFile{Data: []byte("about")},
	})
	handler := serveAboutPage(fileSystem)

	for _, method := range []string{http.MethodGet, http.MethodHead} {
		for _, path := range []string{"/about", "/about/"} {
			t.Run(method+path, func(t *testing.T) {
				engine := gin.New()
				engine.NoRoute(handler, func(c *gin.Context) {
					c.Status(http.StatusNotFound)
				})
				request := httptest.NewRequest(method, "https://example.test"+path, nil)
				response := httptest.NewRecorder()
				engine.ServeHTTP(response, request)

				require.Equal(t, http.StatusOK, response.Code)
				assert.Empty(t, response.Header().Get("Location"))
				assert.Equal(t, "no-cache", response.Header().Get("Cache-Control"))
				if method == http.MethodHead {
					assert.Empty(t, response.Body.String())
				} else {
					assert.Equal(t, "about", response.Body.String())
				}
			})
		}
	}
}

func TestServeAboutPagePreservesFallback(t *testing.T) {
	gin.SetMode(gin.TestMode)
	for _, testCase := range []struct {
		name   string
		method string
		path   string
		files  fstest.MapFS
	}{
		{"missing file", http.MethodGet, "/about", fstest.MapFS{}},
		{"other path", http.MethodGet, "/dashboard", fstest.MapFS{"about/index.html": {Data: []byte("about")}}},
		{"post request", http.MethodPost, "/about", fstest.MapFS{"about/index.html": {Data: []byte("about")}}},
	} {
		t.Run(testCase.name, func(t *testing.T) {
			engine := gin.New()
			engine.NoRoute(serveAboutPage(http.FS(testCase.files)), func(c *gin.Context) {
				c.String(http.StatusNotFound, "fallback")
			})
			request := httptest.NewRequest(testCase.method, "https://example.test"+testCase.path, nil)
			response := httptest.NewRecorder()
			engine.ServeHTTP(response, request)
			assert.Equal(t, http.StatusNotFound, response.Code)
			assert.Equal(t, "fallback", response.Body.String())
		})
	}
}
