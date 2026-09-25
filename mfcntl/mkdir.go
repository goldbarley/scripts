package mfcntl

import (
	"fmt"
	"os"
)

func Mkdir(dirname string) int {
	err := os.Mkdir(dirname, 0755)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: Could not create directory: %s\n",
			    dirname)
		return -1
	}

	return 0
}

func MkdirAll(dirname string) int {
	err := os.MkdirAll(dirname, 0755)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: Could not create directories: %s\n",
			    dirname)
		return -1
	}

	return 0
}
