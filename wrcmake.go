package main

import (
	"scripts/mfcntl"

	"flag"
	"fmt"
	"io"
	"os"
	"strings"
)

func main() {
	f_projname := flag.String("name", "", "Project prefix.")
	f_cmakev := flag.String("cmakev", "1.15.7", "CMake version.")
	f_langs := flag.String("langs", "C", "Languages.")

	flag.Parse()

	var projname string = *f_projname
	if projname == "" {
		io.WriteString(os.Stdout, "Error: Name cannot be empty.\n" +
			"Usage: wrcmake -name=superduper\n")

		os.Exit(1)
	}

	var cmakev string = *f_cmakev
	var langs string = *f_langs

	var prefix string = strings.ToUpper(projname)

	var filepath string = "CMakeLists.txt"
	file := mfcntl.Open(filepath,
			    os.O_WRONLY | os.O_CREATE | os.O_TRUNC)
	if file == nil {
		fmt.Fprintf(os.Stderr, "Error: Could not open file: %s\n.",
			    filepath)
		os.Exit(1)
	}

	toplvl := fmt.Sprintf("%s_IS_TOP_LVL", prefix)
	deflibtype := fmt.Sprintf("%s_DEFAULT_LIB_TYPE", prefix)
	libtype := fmt.Sprintf("%s_LIB_TYPE", prefix)

	fmt.Fprintf(file, "cmake_minimum_required(VERSION %s)\n", cmakev)
	fmt.Fprintf(file, "project(%s %s)\n\n", projname, langs)
	io.WriteString(file,
		       "if (NOT CMAKE_BUILD_TYPE)\n" +
		       "\tset(CMAKE_BUILD_TYPE \"Release\")\n" +
		       "endif() # CMAKE_BUILD_TYPE\n\n" +
		       "set(CMAKE_EXPORT_COMPILE_COMMANDS ON)\n\n" +
		       "if (CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)\n")
	fmt.Fprintf(file,
		    "\tset(%s ON)\n" +
		    "else()\n" +
		    "\tset(%s OFF)\n" +
		    "endif() # %s\n\n" +
		    "if (%s)\n" +
		    "\tset(%s \"EXEC\")\n" +
		    "else()\n" +
		    "\tset(%s \"STATIC\")\n" +
		    "endif() # %s\n\n" +
		    "set(%s \"${%s}\" CACHE STRING \"Library type.\")\n\n" +
		    "if (%s STREQUAL \"SHARED\")\n" +
		    "\tadd_library(${PROJECT_NAME} SHARED)\n" +
		    "\ttarget_compile_definitions(${PROJECT_NAME} PUBLIC %s_LIB_SHARED)\n" +
		    "elseif (%s STREQUAL \"EXEC\")\n" +
		    "\tadd_executable(${PROJECT_NAME}\n" +
		    "\t\t${CMAKE_CURRENT_SOURCE_DIR}/tests/test.c)\n" +
		    "\ttarget_compile_definitions(${PROJECT_NAME} PUBLIC %s_LIB_EXEC)\n" +
		    "else()\n" +
		    "\tadd_library(${PROJECT_NAME} STATIC)\n" +
		    "\ttarget_compile_definitions(${PROJECT_NAME} PUBLIC %s_LIB_STATIC)\n" +
		    "endif() # %s\n\n" +
		    "target_include_directories(${PROJECT_NAME} PUBLIC\n" +
		    "\t${CMAKE_CURRENT_SOURCE_DIR}/include)\n",
		    toplvl, toplvl, toplvl, toplvl,
		    deflibtype, deflibtype, deflibtype,
		    libtype, deflibtype, libtype, prefix, libtype, prefix, prefix,
		    libtype)

	mfcntl.Close(file)

	os.Exit(0)
}
