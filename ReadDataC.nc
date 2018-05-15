#ifdef DEBUG
#include "printf.h"
#endif
configuration ReadDataC{
	provides interface ReadData;
}
implementation {
	components ReadDataP as Reader;
	ReadData = Reader;
	
	components new SensirionSht11C() as SensorHT;
	Reader.Temperature 	-> SensorHT.Temperature;  
  	Reader.Humidity   	-> SensorHT.Humidity;
	components new HamamatsuS1087ParC() as SensorPhoto;
	Reader.Photo		-> SensorPhoto;
	components new HamamatsuS10871TsrC() as SensorTotal;
	Reader.Radiation	-> SensorTotal;
	components new Msp430InternalVoltageC() as Vref;
	Reader.Vref			-> Vref;
	
	components LoggerC;
	Reader.Logger 		-> LoggerC.Logger;
}