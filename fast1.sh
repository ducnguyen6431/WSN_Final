echo "" > collecting_bugs_1.txt
make xm1000 install.0004 bsl,/dev/ttyUSB1
java net.tinyos.tools.PrintfClient -comm serial@/dev/ttyUSB1:115200 >> collecting_bugs_1.txt
