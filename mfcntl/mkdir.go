package mfcntl

import "os"

func Mkdir(dirname string) int {
	err := os.Mkdir(dirname, 0755)
	if err != nil {
		return -1
	}

	return 0
}

func MkdirAll(dirname string) int {
	err := os.MkdirAll(dirname, 0755)
	if err != nil {
		return -1
	}

	return 0
}
