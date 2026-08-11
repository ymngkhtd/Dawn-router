package main

import (
	"io"
	"testing"

	"github.com/QuantumNous/new-api/common"
	"github.com/stretchr/testify/require"
)

func TestEmbeddedAboutBackgroundHasContent(t *testing.T) {
	fileSystem := common.EmbedFolder(buildFS, "web/dist")
	file, err := fileSystem.Open("/about/bg-about.webp")
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, file.Close()) })

	content, err := io.ReadAll(file)
	require.NoError(t, err)
	require.NotEmpty(t, content)
}
