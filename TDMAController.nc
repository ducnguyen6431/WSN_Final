#include "wsn_message.h"
typedef enum {
	TDMA_ROUND_SYSTEM	= 1,
	TDMA_ROUND_LOCAL	= 2
} tdma_round_type_t;

interface TDMAController{
	command bool isSink();
	command bool isHead();
	command error_t start();
	event void startDone(error_t err);
	command error_t stop();
	event void stopDone(error_t err);
	event void newRound(tdma_round_type_t type);
	command void setDataPkg(data_pkg_msg_t* data_pkg);
}