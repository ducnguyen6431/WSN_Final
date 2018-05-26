#include "radio_info.h"
configuration PCConnectC{
	provides interface PCConnect;
}
implementation{
	components PCConnectP;
	PCConnect	= PCConnectP;
	
	components SerialActiveMessageC as Serial;
	PCConnectP.UartPacket	-> Serial.Packet;
	PCConnectP.UartAMPacket	-> Serial.AMPacket;
	PCConnectP.UartReceive	-> Serial.Receive;
	PCConnectP.SerialControl-> Serial.SplitControl;
	PCConnectP.UartSend		-> Serial.AMSend;
	
	components LedsC;
	PCConnectP.Leds		-> LedsC.Leds;
	
	components LoggerC;
	PCConnectP.Logger	-> LoggerC.Logger;
}