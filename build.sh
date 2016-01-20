#!/bin/bash

gnatmake src/picoserver.adb -gnat2012 -gnata -gnatU
rm *.ali *.o
