package mfcntl

import "os"

func Open(path string, oflag int) *os.File {
	file, err := os.OpenFile(path, oflag, 0644)
	if err != nil {
		return nil
	}

	return file
}
