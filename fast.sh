echo "" > collecting_bugs.txt
make xm1000 install.0000 bsl,/dev/ttyUSB0 >> /dev/null
make xm1000 install.0004 bsl,/dev/ttyUSB1 >> /dev/null
make xm1000 install.0005 bsl,/dev/ttyUSB2 >> /dev/null
make xm1000 install.0006 bsl,/dev/ttyUSB3 >> /dev/null
make xm1000 install.0007 bsl,/dev/ttyUSB4 >> /dev/null
make xm1000 install.0008 bsl,/dev/ttyUSB5 >> /dev/null
make xm1000 install.0010 bsl,/dev/ttyUSB6 >> /dev/null
#java net.tinyos.tools.PrintfClient -comm serial@/dev/ttyUSB0:115200	>> collecting_bugs.txt
