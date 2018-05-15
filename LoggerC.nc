#ifdef SYSTEM_LOGGER
#include "printf.h"
#endif
configuration LoggerC{
	provides interface Logger;
}
implementation{
	components LoggerP;
	Logger	= LoggerP;
	#ifdef SYSTEM_LOGGER
	components SerialStartC;
	components PrintfC;
	#endif
}