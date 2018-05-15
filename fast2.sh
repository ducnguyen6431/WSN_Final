rm -r collecting_bugs_2.txt
make xm1000 install.0005 bsl,/dev/ttyUSB2
java net.tinyos.tools.PrintfClient -comm serial@/dev/ttyUSB2:115200 >> collecting_bugs_2.txt
