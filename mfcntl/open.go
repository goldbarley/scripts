package mfcntl

import (
	"fmt"
	"os"
)

func Open(path string, oflag int) *os.File {
	file, err := os.OpenFile(path, oflag, 0644)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: Could not open file: %s\n.", path)
		return nil
	}

	return file
}
