@echo off

dub build -c library
dub test

:DONE
