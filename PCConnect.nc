#include "radio_info.h"
#include "wsn_message.h"
#include "message.h"
interface PCConnect{
	command void start();
	command void getAssignmentPackages();
	command structured_sink_to_head_assignment_msg_t* getAllAssignmentsPtr();
	command void gatherDataToPC(am_addr_t source, data_pkg_msg_t* msg);
}