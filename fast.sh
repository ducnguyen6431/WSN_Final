echo "" > collecting_bugs.txt
make xm1000 install.0000 bsl,/dev/ttyUSB0
java net.tinyos.tools.PrintfClient -comm serial@/dev/ttyUSB0:115200	>> collecting_bugs.txt
