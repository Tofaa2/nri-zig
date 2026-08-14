#!/bin/sh
CXX_BIN="${NRI_CXX:-g++}"
exec "$CXX_BIN" "$@" -Wno-error=uninitialized -Wno-error=maybe-uninitialized
