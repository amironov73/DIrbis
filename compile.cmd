@echo off

dub build -c library
dub build -b docs
dub test

:DONE
