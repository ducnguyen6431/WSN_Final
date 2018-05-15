#include "message.h"
interface ReadData {
	command error_t read();
	event void readDone(error_t error, data_pkg_msg_t *msg);
	command void readMsg(data_pkg_msg_t *msg);
}