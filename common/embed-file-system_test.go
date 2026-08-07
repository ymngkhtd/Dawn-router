package common

import (
	"io"
	"net/http"
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
