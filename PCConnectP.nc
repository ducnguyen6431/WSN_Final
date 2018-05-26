#include "settings.h"
module PCConnectP{
	provides interface PCConnect;
	uses {
		interface Logger;
		interface AMSend as UartSend[am_id_t id];
	    interface Receive as UartReceive[am_id_t id];
	    interface Packet as UartPacket;
	    interface AMPacket as UartAMPacket;
	    interface SplitControl as SerialControl;
	    interface Leds;
	}
}
implementation{
	structured_sink_to_head_assignment_msg_t assignments[32];
	uint8_t count_assignments;
	message_t start_signal_pkt;
	message_t ack_signal_pkt;
	message_t data_pkt;

	command void PCConnect.start() {
		count_assignments = 0;
		call SerialControl.start();
	}

	command structured_sink_to_head_assignment_msg_t * PCConnect.getAllAssignmentsPtr(){
		return assignments;
	}

	void sendStartAssignmentRecv() {
		call Leds.led2Toggle();
		call UartSend.send[RADIO_ASSIGNMENT_START_MSG](0xFFFF, &start_signal_pkt, sizeof(assignment_start_signal));
	}

	void sendAssignmentAckSignal() {
		call Leds.led0Off();
		call UartSend.send[RADIO_ASSIGNMENT_ACK_MSG](0xFFFF, &ack_signal_pkt, sizeof(assignment_ack_signal));
	}

	command void PCConnect.getAssignmentPackages() {
		count_assignments = 0;
		sendStartAssignmentRecv();
	}

	command void PCConnect.gatherDataToPC(am_addr_t source, data_pkg_msg_t* data_msg) {
		data_pkg_msg_t* tmp_msg;
		tmp_msg = (data_pkg_msg_t*)call UartPacket.getPayload(&data_pkt, sizeof(data_pkg_msg_t));
		tmp_msg->temperature = data_msg->temperature;
		tmp_msg->humidity	 = data_msg->humidity;
		tmp_msg->radiation	 = data_msg->radiation;
		tmp_msg->photo		 = data_msg->photo;
		tmp_msg->vref		 = data_msg->vref;
		call UartSend.send[RADIO_PC_MOTE_DATA](source, &data_pkt, sizeof(data_pkg_msg_t));
	}

	event message_t *UartReceive.receive[am_id_t id](message_t *msg, void *payload, uint8_t len) {
		uint8_t i;
		structured_sink_to_head_assignment_msg_t *ptr;
		call Leds.led1Toggle();
		if(call UartAMPacket.type(msg) == RADIO_ASSIGNMENT_MSG) {
			call Leds.led0On();
			ptr = (structured_sink_to_head_assignment_msg_t*)payload;
			assignments[count_assignments].slot_no_of_new_head = ptr->slot_no_of_new_head;
			if(assignments[count_assignments].slot_no_of_new_head == 0x02)
				call Leds.led1Toggle();
			memcpy(assignments[count_assignments].slot_map_new_group_id, ptr->slot_map_new_group_id, sizeof(uint8_t)*(SLOT_PER_ROUND_DEFAULT-2));
			assignments[count_assignments].head_new_group_id = ptr->head_new_group_id;
			assignments[count_assignments].slot_map_on_off = ptr->slot_map_on_off;
			count_assignments++;
			sendAssignmentAckSignal();
		}
		return msg;
	}
	
	// useless
	event void UartSend.sendDone[am_id_t id](message_t* msg, error_t error) { }

	event void SerialControl.stopDone(error_t error){ }

	event void SerialControl.startDone(error_t error){ }
}