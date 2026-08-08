package common

import (
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
	"testing/fstest"

	"github.com/stretchr/testify/require"
)

func TestEmbedFileSystemOpenNormalizesURLPath(t *testing.T) {
	fileSystem := &embedFileSystem{
		FileSystem: http.FS(fstest.MapFS{
			"about/index.html": &fstest.MapFile{Data: []byte("about")},
		}),
	}

	file, err := fileSystem.Open("/about/index.html")
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, file.Close()) })

	content, err := io.ReadAll(file)
	require.NoError(t, err)
	require.Equal(t, "about", string(content))
}

func TestEmbedFileSystemOpenRejectsRepeatedRootPath(t *testing.T) {
	fileSystem := &embedFileSystem{
		FileSystem: http.FS(fstest.MapFS{
			"index.html": &fstest.MapFile{Data: []byte("index")},
		}),
	}

	file, err := fileSystem.Open("//")
	require.ErrorIs(t, err, os.ErrNotExist)
	require.Nil(t, file)
}

func TestEmbedFileSystemServesDirectoryIndexWithoutRedirect(t *testing.T) {
	fileSystem := &embedFileSystem{
		FileSystem: http.FS(fstest.MapFS{
			"about/index.html": &fstest.MapFile{Data: []byte("about")},
		}),
	}

	request := httptest.NewRequest(http.MethodGet, "https://example.test/about/", nil)
	response := httptest.NewRecorder()
	http.FileServer(fileSystem).ServeHTTP(response, request)

	require.Equal(t, http.StatusOK, response.Code)
	require.Empty(t, response.Header().Get("Location"))
	require.Equal(t, "about", response.Body.String())
}
