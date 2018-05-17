echo "" > collecting_bugs_3.txt
make xm1000 install.0006 bsl,/dev/ttyUSB3
java net.tinyos.tools.PrintfClient -comm serial@/dev/ttyUSB3:115200 >> collecting_bugs_3.txt
