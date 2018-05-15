#ifdef DEBUG
#include "printf.h"
#endif

#ifndef LIGHT_ON
#define LIGHT_ON
#endif
configuration MainExecC {

}
implementation {
	components MainC;
	components MainExecP as App;
	App.Boot		-> MainC.Boot;
	
	components ReadDataC;
	App.DataReader 	-> ReadDataC.ReadData;
	
	components LoggerC;
	App.Logger 		-> LoggerC.Logger;
	#ifdef LIGHT_ON
	components LedsC;
	App.Leds 		-> LedsC.Leds;
	components new TimerMilliC() as Timer;
	App.Timer		-> Timer;
	#endif
	
	components TDMAControllerC;
	App.TDMAController	-> TDMAControllerC.TDMAController;
}