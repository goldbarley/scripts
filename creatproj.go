package main

import (
	"scripts/mfcntl"

	"flag"
	"fmt"
	"strings"
	"os"
)

func main() {
	f_lang := flag.String("lang", "c", "Language.")
	f_projname := flag.String("name", "naught", "Project name.")

	flag.Parse()

	var projname string = *f_projname
	var lang string = strings.ToLower(*f_lang)

	var err int = 0

	switch lang {
		case "c":
			err = creatproj_c(projname)
			if err != 0 {
				os.Exit(-1)
			}
			break
		case "c++":
		case "cpp":
		case "cxx":
		case "cc":
			err = creatproj_c(projname)
			if err != 0 {
				os.Exit(-1)
			}
			fmt.Printf("Created project: %s.\n", projname)
			break
	}

	os.Exit(0)
}

func creatproj_c(projname string) int {
	var inclpath string = fmt.Sprintf("%s/include/%s", projname, projname)
	var srcpath string = fmt.Sprintf("%s/src", projname)
	var capname = strings.ToUpper(projname)

	err := mfcntl.MkdirAll(inclpath)
	if err != 0 {
		return err
	}

	err = mfcntl.Mkdir(srcpath)
	if err != 0 {
		return err
	}

	var inclfilepath string = fmt.Sprintf("%s/%s.h", inclpath, projname)
	var srcfilepath string = fmt.Sprintf("%s/%s.c", srcpath, projname)

	header := mfcntl.Open(inclfilepath,
			      os.O_WRONLY | os.O_CREATE |os.O_TRUNC)
	if header == nil {
		return -1
	}

	var header_guard string = fmt.Sprintf("%s_H_", capname)

	fmt.Fprintf(header, "#ifndef %s\n#define %s 1\n\n\n\n", header_guard,
		   header_guard)
	fmt.Fprintf(header, "#endif /* %s */\n", header_guard)

	mfcntl.Close(header)

	source := mfcntl.Open(srcfilepath, os.O_WRONLY | os.O_CREATE)
	if source == nil {
		return -1
	}

	fmt.Fprintf(source, "#include \"%s/%s.h\"\n", projname, projname)

	mfcntl.Close(source)

	return 0
}
