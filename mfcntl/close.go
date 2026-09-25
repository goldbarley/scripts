package mfcntl

import (
	"os"
)

func Close(file *os.File) {
	if file != nil {
		file.Close()
	}
}
