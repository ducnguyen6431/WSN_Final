#include <Timer.h>
#include "slot_scheduler.h"
#include "settings.h"
#include "wsn_message.h"
typedef enum {
	ST_TIMESYNC = 0,
	ST_JOIN = 1,
	ST_DATA				// This data will be the rest
} slot_type_t;

module TDMAControllerP {
	provides interface TDMAController;
	uses {
		interface Logger;
		interface TimeSyncPacket<TMilli, uint32_t> as TSPacket;
		interface TimeSyncAMSend<TMilli, uint32_t> as TSSend;
		interface Receive as TSReceive;
		interface AMPacket as AMPacket;
		interface AMSend as JoinReqSend;
		interface Receive as JoinReqReceive;
		interface AMSend as JoinAnsSend;
		interface Receive as JoinAnsReceive;
		interface AMSend as DataPkgSend;
		interface Receive as DataPkgReceive;
		interface AMSend as AssignmentSend;
		interface Receive as AssignmentReceive;
		interface SplitControl as RadioControl;
		interface SlotScheduler as SystemScheduler;
		interface SlotScheduler as LocalScheduler;
		interface Settings;
		interface ReadData;
		interface Leds;
		interface PCConnect;
	}
}

implementation{
	am_group_t group_id = 0x00;
	bool off_time = FALSE;
	bool rested = FALSE;
	bool is_sink = FALSE;
	bool first_time = TRUE;
	bool is_new_head = FALSE;
	bool is_head = FALSE;
	bool sync_mode = FALSE;
	bool joined = FALSE;
	bool sync_received = FALSE;
	bool join_ans_recv = FALSE;
	uint8_t missed_sync_count = 0;
	am_addr_t head_addr = 0x0000;
	message_t timesync_packet;
	timesync_msg_t *timesync_msg;
	message_t join_req_packet;
	join_req_msg_t *join_req_msg;
	message_t join_ans_packet;
	join_ans_msg_t *join_ans_msg;
	message_t data_pkg_packet;
	data_pkg_msg_t *data_pkg_msg;
	uint8_t assigned_slot = 0;
	uint8_t system_sleep_slots = 0;
	am_addr_t* slot_map = NULL;
	uint8_t* missed_pkg_count = NULL;
	uint8_t current_round_idx = TOTAL_ROUND_PER_RESET;
	bool join_lock = FALSE;
	head_to_node_assignment_msg_t* head_to_node_assignment_msg; // These 2 type of payload both use assignment_msg
	sink_to_head_assignment_msg_t* sink_to_head_assignment_msg; // 
	message_t assignment_pkt;
	structured_sink_to_head_assignment_msg_t structured_sink_to_head_assignment_msg_sink[32];
	structured_sink_to_head_assignment_msg_t structured_sink_to_head_assignment_msg;
	uint8_t count_off_time = 0;
	uint8_t self_count_emergency = NO_HEAD_TIMEOUT;	// If this count reach 0 => Initialize every from the start!


	void startSlotTask(tdma_round_type_t round_type, uint8_t slot_no);

	command error_t TDMAController.start(){
		uint8_t *round_norm_slot;
		round_norm_slot = call Settings.slotPerRound();
		system_sleep_slots = *round_norm_slot + *call Settings.sleepSlotPerRound() * 2;
		is_sink = (TOS_NODE_ID == 0x0000);
		if(first_time) {
//			if(is_sink) {
//				call PCConnect.start();
//				call PCConnect.getAllAssignmentsPtr();
//			}
			is_head = (TOS_NODE_ID % INITIAL_HEAD_DIVIDE_NO == 0);
			group_id = (TOS_NODE_ID / INITIAL_HEAD_DIVIDE_NO);
			first_time = FALSE;
		} else {
			if(is_new_head) {
				is_head = TRUE;
				call Logger.log("Reverse error", log_lvl_err);
				off_time = FALSE;
			}
			is_new_head = FALSE;
		}
		// Testing
		if(is_sink) {
			bzero(structured_sink_to_head_assignment_msg_sink, sizeof(structured_sink_to_head_assignment_msg_t)*32);
			structured_sink_to_head_assignment_msg_sink[02].slot_no_of_new_head = 0x02;
			structured_sink_to_head_assignment_msg_sink[02].slot_map_new_group_id[00] = 0x01;
			structured_sink_to_head_assignment_msg_sink[02].slot_map_new_group_id[01] = 0x01;
			structured_sink_to_head_assignment_msg_sink[02].slot_map_new_group_id[02] = 0x01;
			structured_sink_to_head_assignment_msg_sink[02].head_new_group_id = 0x01;
			structured_sink_to_head_assignment_msg_sink[02].slot_map_on_off = 0x0004;
			structured_sink_to_head_assignment_msg_sink[03].slot_no_of_new_head = 0x02;
			structured_sink_to_head_assignment_msg_sink[03].slot_map_new_group_id[00] = 0x02;
			structured_sink_to_head_assignment_msg_sink[03].slot_map_new_group_id[01] = 0x02;
			structured_sink_to_head_assignment_msg_sink[03].slot_map_new_group_id[02] = 0x02;
			structured_sink_to_head_assignment_msg_sink[03].head_new_group_id = 0x02;
			structured_sink_to_head_assignment_msg_sink[03].slot_map_on_off = 0x0004;
			structured_sink_to_head_assignment_msg_sink[04].slot_no_of_new_head = 0x02;
			structured_sink_to_head_assignment_msg_sink[04].slot_map_new_group_id[00] = 0x03;
			structured_sink_to_head_assignment_msg_sink[04].slot_map_new_group_id[01] = 0x03;
			structured_sink_to_head_assignment_msg_sink[04].slot_map_new_group_id[02] = 0x03;
			structured_sink_to_head_assignment_msg_sink[04].head_new_group_id = 0x03;
			structured_sink_to_head_assignment_msg_sink[04].slot_map_on_off = 0x0004;
			structured_sink_to_head_assignment_msg_sink[05].slot_no_of_new_head = 0x02;
			structured_sink_to_head_assignment_msg_sink[05].slot_map_new_group_id[00] = 0x04;
			structured_sink_to_head_assignment_msg_sink[05].slot_map_new_group_id[01] = 0x04;
			structured_sink_to_head_assignment_msg_sink[05].slot_map_new_group_id[02] = 0x04;
			structured_sink_to_head_assignment_msg_sink[05].head_new_group_id = 0x04;
			structured_sink_to_head_assignment_msg_sink[05].slot_map_on_off = 0x0004;
			structured_sink_to_head_assignment_msg_sink[06].slot_no_of_new_head = 0x02;
			structured_sink_to_head_assignment_msg_sink[06].slot_map_new_group_id[00] = 0x05;
			structured_sink_to_head_assignment_msg_sink[06].slot_map_new_group_id[01] = 0x05;
			structured_sink_to_head_assignment_msg_sink[06].slot_map_new_group_id[02] = 0x05;
			structured_sink_to_head_assignment_msg_sink[06].head_new_group_id = 0x05;
			structured_sink_to_head_assignment_msg_sink[06].slot_map_on_off = 0x0004;
		}
		// test end
		if (!is_sink) {
			call RadioControl.start();
			// Head and node have Join Request pkg to join the net and have DataSend pkg to send data
			join_req_msg = (join_req_msg_t *)call JoinReqSend.getPayload(&join_req_packet, sizeof(join_req_msg_t));
			data_pkg_msg = (data_pkg_msg_t *)call DataPkgSend.getPayload(&data_pkg_packet, sizeof(data_pkg_msg_t));
			call Logger.log("Setting up for head and node", log_lvl_info);
			sync_mode = TRUE; 
		} else {
			is_head = TRUE;
			call Logger.log("Start system scheduler for sink", log_lvl_info);
			call SystemScheduler.start(SLOT_REPEAT, *call SystemScheduler.getSystemTime(), 0, system_sleep_slots, call Settings.slotDuration(), round_norm_slot);
		}
		if (is_head) {
			// Head and sink will have TimeSync send and Join Answer
			slot_map = (am_addr_t*)malloc(sizeof(am_addr_t) * * round_norm_slot);
			missed_pkg_count = (uint8_t*)malloc(sizeof(uint8_t) * *round_norm_slot);
			bzero(slot_map, sizeof(am_addr_t) * *round_norm_slot);
			bzero(missed_pkg_count, sizeof(uint8_t) * *round_norm_slot);
			timesync_msg = (timesync_msg_t *)call TSSend.getPayload(&timesync_packet, sizeof(timesync_msg_t));
			join_ans_msg = (join_ans_msg_t *)call JoinAnsSend.getPayload(&join_ans_packet, sizeof(join_ans_msg_t));
			call Logger.log("Done setting up for head and sink", log_lvl_info);
		}
		return SUCCESS;
	}

	void sendSyncBeacon(tdma_round_type_t type) {
		uint8_t status;
		timesync_msg = (timesync_msg_t*)call TSSend.getPayload(&timesync_packet, sizeof(timesync_msg_t));
		if(is_sink)
			current_round_idx = current_round_idx==0?0:current_round_idx-1;
		timesync_msg->remain_round = current_round_idx;
		// TODO Need set on-off protocol
		timesync_msg->group_id = group_id;
		// TODO If other flags are needed in the future
		if(type == TDMA_ROUND_SYSTEM) {
			timesync_msg->other_flag = 1 << 3;
		} else {
			timesync_msg->other_flag &= 0xF7;
		}
		if(type == TDMA_ROUND_SYSTEM) {
			status = call TSSend.send(AM_BROADCAST_ADDR, &timesync_packet, sizeof(timesync_msg_t), *call SystemScheduler.getSystemTime());
		} else
			status = call TSSend.send(AM_BROADCAST_ADDR, &timesync_packet, sizeof(timesync_msg_t), *call LocalScheduler.getSystemTime());
		call Logger.logValue("My Group id", group_id, FALSE, log_lvl_dbg);
		call Logger.logValue("Current round", current_round_idx, FALSE, log_lvl_info);
		call Logger.logValue("Send timesync msg status", status, FALSE, log_lvl_dbg);
	}

	void sendJoinReq(tdma_round_type_t type) {
		uint8_t status;
		if(off_time) {
			return;
		}
		call Logger.log("Sending Join Req", log_lvl_info);
		// join_req_msg->other_flag = type - 1;
		join_req_msg = (join_req_msg_t*)call JoinReqSend.getPayload(&join_req_packet, sizeof(join_req_msg));
		status = call JoinReqSend.send(head_addr, &join_req_packet, sizeof(join_req_msg_t));
		call Logger.logValue("Sending Join req... Status", status, FALSE, log_lvl_dbg);
	}

	command void TDMAController.setDataPkg(data_pkg_msg_t *data_pkg) {
		data_pkg_msg->vref = data_pkg->vref;
		data_pkg_msg->temperature = data_pkg->temperature;
		data_pkg_msg->humidity = data_pkg->humidity;
		data_pkg_msg->photo = data_pkg->photo;
		data_pkg_msg->radiation = data_pkg->radiation;
	}

	void sendData() {
		uint8_t status;
		call Logger.log("Sending Data Pkg", log_lvl_info);
		status = call DataPkgSend.send(head_addr, &data_pkg_packet, sizeof(data_pkg_msg_t));
		call Logger.logValue("Sending data... Status", status, FALSE, log_lvl_dbg);
	}
	
	void sendAssignment(uint8_t slot_no);

	void startSlotTask(tdma_round_type_t round_type, uint8_t slot_no) {
		// TODO improve
		if (round_type == TDMA_ROUND_SYSTEM) {
			switch (slot_no) {
				case ST_TIMESYNC:
					if(is_sink) {
						sendSyncBeacon(round_type);
						call Logger.log("Sending Sync Beacon System", log_lvl_info);
					}
					break;
				case ST_JOIN:
					if(joined || is_sink)
						break;
					sendJoinReq(round_type);
					break;
				default:
					if(is_sink) {
						if(current_round_idx <= 0)
							sendAssignment(slot_no);
						break;
					}
					if((call SystemScheduler.mode() == MODE_REPEAT) && !joined){
						sendJoinReq(round_type);
						break;
					}
					if(current_round_idx > SETUP_COUNTDOWN) {
						call Logger.log("In set up phase", log_lvl_dbg);
						break;
					}
					// Send Join req if in mode repeat and haven't successfully joined
					if(!joined) {
						sendJoinReq(round_type);
						break;
					}
					if(current_round_idx > 0) {
						sendData();
					}
					break;
			}
		} else {
			switch (slot_no) {
				case ST_TIMESYNC:
					if(is_head) {
						sendSyncBeacon(round_type);
						call Logger.log("Sending Sync Beacon Local", log_lvl_info);
					}
					break;
				case ST_JOIN:
					if(joined || is_head)
						break;
					sendJoinReq(round_type);
						break;
					break;
				default:
					if(is_head) {
						if(current_round_idx <= 0)
							sendAssignment(slot_no);
						break;
					}
					if((call LocalScheduler.mode() == MODE_REPEAT) && !joined){
						sendJoinReq(round_type);
						break;
					}
					if(current_round_idx > SETUP_COUNTDOWN) {
						call Logger.log("In set up phase", log_lvl_dbg);
						break;
					}
					if(!joined){
						sendJoinReq(round_type);
						break;
					}
					if(current_round_idx > 0) {
						sendData();
					}
					break;
			}
		}
	}

	void removeBlankSlotFromSlotMap() {
		uint8_t slot_no;
		if(is_sink)
			call SystemScheduler.reset(0);
		if(is_head)
			call LocalScheduler.reset(0);
		for(slot_no = 2; slot_no < *call Settings.slotPerRound(); slot_no++) {
			if(slot_map[slot_no] != 0x0000) {
				if(is_sink)
					call SystemScheduler.updateSlotMap(slot_no, ut_add);
				if(is_head)
					call LocalScheduler.updateSlotMap(slot_no, ut_add);
			}
		}
	}

	error_t putRadioToSleep(tdma_round_type_t round_type, uint8_t sleep_threshold) {
		// TODO Turn off radio logic
		// turn off if gap between 2 slot is too long (no of gap slot > sleep_threshold)
		if(round_type == TDMA_ROUND_SYSTEM) {
			if((call SystemScheduler.nextSlot() - call SystemScheduler.currentSlot()) > sleep_threshold) {
				call Logger.log("Shutting radio down", log_lvl_info);
				call RadioControl.stop();
			}
		} else {
			if((call LocalScheduler.nextSlot() - call LocalScheduler.currentSlot()) > sleep_threshold) {
				call Logger.log("Shutting radio down", log_lvl_info);
				call RadioControl.stop();
			}
		}
		return SUCCESS;
	}

	// RadioControl Interface
	event void RadioControl.startDone(error_t error){
		if (error != SUCCESS && error != EALREADY) {
			call Logger.logValue("Radio failed to start. Code", error, TRUE, log_lvl_err);
			call RadioControl.start();
		} else {
			call Leds.led0On();
			call Logger.log("Radio started!", log_lvl_info);
			if(call SystemScheduler.isSlotActive()) {
				// call Logger.log("System scheduler start slot task", log_lvl_dbg);
				startSlotTask(TDMA_ROUND_SYSTEM, call SystemScheduler.currentSlot());
			}
			if(call LocalScheduler.isSlotActive())
				startSlotTask(TDMA_ROUND_LOCAL, call LocalScheduler.currentSlot());
		}
	}

	bool head_last_local_round_checked = FALSE;
	event void RadioControl.stopDone(error_t error){
		if (error == SUCCESS || error == EALREADY) {
			call Leds.led0Off();
			call Logger.log("Radio Stopped!", log_lvl_info);
		} else {
			call Logger.logValue("Radio can't stop. Status", error, FALSE, log_lvl_err);
		}
		if(head_last_local_round_checked)
			if (current_round_idx <= 0) {
				call TDMAController.stop();
			}
	}

	command error_t TDMAController.stop(){
		// TODO Stop everything, reset variables
		head_last_local_round_checked = FALSE;
		is_sink = FALSE;
		is_head = FALSE;
		sync_mode = FALSE;
		joined = FALSE;
		sync_received = FALSE;
		missed_sync_count = 0; 
		head_addr = 0x0000;
		system_sleep_slots = 0;
		free(missed_pkg_count);
		current_round_idx = TOTAL_ROUND_PER_RESET;
		self_count_emergency = NO_HEAD_TIMEOUT;
		free(slot_map);
		call SystemScheduler.stop();
		call LocalScheduler.stop();
		return SUCCESS;
	}
	
	// Node receive TS for Local Scheduler only
	// Head receive TS for System Scheduler only
	event message_t * TSReceive.receive(message_t *msg, void *payload, uint8_t len) {
		uint32_t ref_time;
		if(is_sink)
			return msg;
		call Leds.led1On();
		call Logger.log("TS received", log_lvl_info);
		call Leds.led1Off();
		if(!is_sink && sync_mode) {
			self_count_emergency--;
			if(self_count_emergency == 0) {
				first_time = TRUE;
				call TDMAController.stop();
				return msg;
			}
		}
		if(len != sizeof(timesync_msg_t))
			return msg;
		if(!call TSPacket.isValid(msg))
			return msg;
		missed_sync_count = 0;
		timesync_msg = (timesync_msg_t*)payload;
		ref_time = call TSPacket.eventTime(msg);
		current_round_idx = timesync_msg->remain_round;
		if(timesync_msg->group_id != SYSTEM_GROUP_ID) {
			if(off_time) {
				call RadioControl.stop();
				if(count_off_time >= OFF_ROUND_MAX) {
					count_off_time = 0;
					off_time = FALSE;
				}
				count_off_time++;
			}
		}
		if(!sync_mode) {
			if(timesync_msg->group_id == SYSTEM_GROUP_ID) {
				call SystemScheduler.syncSystemTime(ref_time);
			} else {
				call LocalScheduler.syncSystemTime(ref_time);
			}
			return msg;
		}
		// If syncing
		if(is_head) {
			// This will setup head's System scheduler only
			if(timesync_msg->group_id == SYSTEM_GROUP_ID) {
				head_addr = call AMPacket.source(msg);
				call Logger.log("System scheduler start for head", log_lvl_dbg);
				call SystemScheduler.start(SLOT_REPEAT, ref_time, 0, system_sleep_slots, call Settings.slotDuration(), call Settings.slotPerRound());
				sync_mode = FALSE;
			} else {
				call Logger.log("System scheduler did not start", log_lvl_dbg);
			}
		} else {
			// This will setup node's Local scheduler only
			if(timesync_msg->group_id != SYSTEM_GROUP_ID && timesync_msg->group_id == group_id) {
				head_addr = call AMPacket.source(msg);
				call Logger.log("Local scheduler start for node", log_lvl_dbg);
				call LocalScheduler.start(SLOT_REPEAT, ref_time, 0, system_sleep_slots, call Settings.slotDuration(), call Settings.slotPerRound());
				sync_mode = FALSE;
			} else {
				call Logger.log("Local scheduler did not start", log_lvl_dbg);
			}
		}
		return msg;
	}

	event void TSSend.sendDone(message_t *msg, error_t error){
		// TODO Auto-generated method stub
		call Logger.log("Time Sync Sent!", log_lvl_info);
	}

	event message_t * DataPkgReceive.receive(message_t *msg, void *payload, uint8_t len){
		// TODO Auto-generated method stub
		if (len != sizeof(data_pkg_msg_t))
			return msg;
		if(call SystemScheduler.isSlotActive()) {
			missed_pkg_count[call SystemScheduler.currentSlot()] = 0;
		} else 
			if(call LocalScheduler.isSlotActive()) {
				missed_pkg_count[call LocalScheduler.currentSlot()] = 0;
			}
//		call PCConnect.gatherDataToPC(call AMPacket.source(msg), (data_pkg_msg_t*) payload);
		return msg;
	}

	event void ReadData.readDone(error_t error, data_pkg_msg_t *msg) {
		// Don't need to implement
		return;
	}

	event message_t * JoinAnsReceive.receive(message_t *msg, void *payload, uint8_t len) {
		if(len != sizeof(join_ans_msg_t))
			return msg;
		join_ans_msg = (join_ans_msg_t*)payload;
		call Logger.logValue("Slot assigned", join_ans_msg->slot, FALSE, log_lvl_info);
		assigned_slot = join_ans_msg->slot;
		if(join_ans_msg->slot == SLOT_UNAVAILABLE) {
			// TODO Do something here
			call TDMAController.stop();
			return msg;
		}
		if(call SystemScheduler.isSlotActive()) {
			joined = TRUE;
			call SystemScheduler.reset(join_ans_msg->slot);
			call SystemScheduler.updateSlotMap(ST_JOIN, ut_delete);
			call LocalScheduler.start(SLOT_REPEAT, *call SystemScheduler.getSystemTime(), (system_sleep_slots - *call Settings.sleepSlotPerRound())* *call Settings.slotDuration() , system_sleep_slots, call Settings.slotDuration(), call Settings.slotPerRound());
		}
		if(call LocalScheduler.isSlotActive()) {
			joined = TRUE;
			call LocalScheduler.reset(join_ans_msg->slot);
			call LocalScheduler.updateSlotMap(ST_JOIN, ut_delete);
		}
		return msg;
	}

	bool checkMissingPkt(uint8_t slot_no) {
		if(slot_no != ST_JOIN && slot_no != ST_TIMESYNC)
			if(is_head) {
				if(missed_pkg_count[slot_no] >= MISSED_PKG_THRESHOLD) {
					slot_map[slot_no] = 0x0000;
					call LocalScheduler.updateSlotMap(slot_no, ut_delete);
					call Logger.logValue("Kicking node at slot", slot_no, FALSE, log_lvl_dbg);
					return TRUE;
				} else 
					missed_pkg_count[slot_no] += 1;
			}
		if(!is_sink) {
			if (missed_sync_count >= MISSED_PKG_THRESHOLD) {
				call Logger.logValue("Missed sync count", missed_sync_count, FALSE, log_lvl_dbg);
				call TDMAController.stop();
				return TRUE;
			}
		}
		return FALSE;
	}

	command bool TDMAController.isSink() {
		return is_sink;
	}

	command bool TDMAController.isHead() {
		return is_head;
	}

	event void JoinReqSend.sendDone(message_t *msg, error_t error){
		// TODO Auto-generated method stub
		call Logger.logValue("Join Req Send status", error, FALSE, log_lvl_dbg);
	}

	event void SystemScheduler.stopDone(error_t err) {
		// TODO Auto-generated method stub
		if(!call LocalScheduler.isRunning() && (err == SUCCESS || err == EALREADY)) {
			signal TDMAController.stopDone(SUCCESS);
		}
	}

	event void SystemScheduler.newRound(){
		// TODO Auto-generated method stub
		call Logger.log("New round system", log_lvl_dbg);
		if(!is_sink)
			missed_sync_count++;
		signal TDMAController.newRound(TDMA_ROUND_SYSTEM);
	}

	event void SystemScheduler.endRound() {
		if(is_sink) {
			if(current_round_idx == 1) {
//				call PCConnect.getAssignmentPackages();
			}
			if(current_round_idx <= 0) {
				current_round_idx = TOTAL_ROUND_PER_RESET;
				bzero(slot_map, sizeof(am_addr_t) * *call Settings.slotPerRound());
				bzero(missed_pkg_count, sizeof(uint8_t) * *call Settings.slotPerRound());
			}
		}
		if(missed_sync_count >= MAX_MISSED_SYNC) {
			sync_mode = TRUE;
			joined = FALSE;
		}
		call RadioControl.stop();
	}

	event void SystemScheduler.startDone(uint8_t slot_no){
		// TODO Auto-generated method stub
		call Logger.logValue("System scheduler started. Slot", slot_no, FALSE, log_lvl_dbg);
	}

	event void SystemScheduler.slotStarted(uint8_t slot_no, uint8_t actual_slot){
		// TODO Auto-generated method stub
		if(!(current_round_idx > SETUP_COUNTDOWN) && is_sink) {
			checkMissingPkt(actual_slot);
		}
		call Logger.logValue("System start slot", actual_slot, FALSE, log_lvl_dbg);
		if(call RadioControl.start() == EALREADY)
			startSlotTask(TDMA_ROUND_SYSTEM, actual_slot);
	}

	event void SystemScheduler.slotEnded(uint8_t slot_no, uint8_t actual_slot){
		// TODO Auto-generated method stub
		join_lock = FALSE;
		call Logger.logValue("System end slot", actual_slot, FALSE, log_lvl_dbg);
		putRadioToSleep(TDMA_ROUND_SYSTEM, SLEEP_THRESHOLD_DEFAULT);
	}
	
	event void LocalScheduler.startDone(uint8_t slot_no){
	}

	event void LocalScheduler.stopDone(error_t err){
		// TODO Auto-generated method stub
		if(!call SystemScheduler.isRunning() && (err == SUCCESS || err == EALREADY)) {
			signal TDMAController.stopDone(SUCCESS);
		}
	}

	event void LocalScheduler.newRound(){
		if(current_round_idx <= 0) {
			head_last_local_round_checked = TRUE;
		}
		if(current_round_idx <= 1 && !is_head) {
			head_last_local_round_checked = TRUE;
		}
		if(current_round_idx == SETUP_COUNTDOWN && is_head)
			removeBlankSlotFromSlotMap();
		if(!is_head) {
			checkMissingPkt(0);
			missed_sync_count++;
		}
		call Logger.log("New round local", log_lvl_dbg);
		signal TDMAController.newRound(TDMA_ROUND_LOCAL);
	}

	event void LocalScheduler.endRound(){
		if(missed_sync_count >= MAX_MISSED_SYNC) {
			sync_mode = TRUE;
			joined = FALSE;
		}
		call RadioControl.stop();
	}
	
	event void LocalScheduler.slotEnded(uint8_t slot_no, uint8_t actual_slot){
		join_lock = FALSE;
		call Logger.logValue("Local end slot", actual_slot, FALSE, log_lvl_dbg);
		putRadioToSleep(TDMA_ROUND_LOCAL, SLEEP_THRESHOLD_DEFAULT);
	}

	event void LocalScheduler.slotStarted(uint8_t slot_no, uint8_t actual_slot){
		if(off_time && actual_slot != ST_TIMESYNC) {
			return;
		}
		if(!(current_round_idx > SETUP_COUNTDOWN) && is_head) {
			checkMissingPkt(actual_slot);
		}
		call Logger.logValue("Local start slot", actual_slot, FALSE, log_lvl_dbg);
		if(actual_slot != ST_TIMESYNC && off_time)
			return;
		if(call RadioControl.start() == EALREADY)
			startSlotTask(TDMA_ROUND_LOCAL, actual_slot);
	}

	event void JoinAnsSend.sendDone(message_t *msg, error_t error){
		call Logger.logValue("Join Ans Send status", error, FALSE, log_lvl_dbg);
		// call Logger.logValue("Client joined at slot", ((join_ans_msg_t *)call JoinAnsSend.getPayload(msg, sizeof(join_ans_msg_t)))->slot, FALSE, log_lvl_dbg);
	}

	void sendJoinAns(am_addr_t client_addr, uint8_t slot) {
		join_ans_msg = (join_ans_msg_t *)call JoinAnsSend.getPayload(&join_ans_packet, sizeof(join_ans_msg_t));
		join_ans_msg->slot = slot;
		call Logger.logValue("Client join at slot", join_ans_msg->slot, FALSE, log_lvl_dbg);
		call JoinAnsSend.send(client_addr, &join_ans_packet, sizeof(join_ans_msg_t));
	}

	uint8_t allocateNewSlot(am_addr_t client_addr){
		uint8_t slot=2;
		for (slot; slot < *call Settings.slotPerRound(); slot++) {
			if(slot_map[slot] == client_addr) {
				call Logger.logValue("Slot", slot, FALSE, log_lvl_dbg);
				return slot;
			}
		}
		// get next slot
		slot = 2;
		for (slot; slot < *call Settings.slotPerRound(); slot++) {
			if(slot_map[slot] == 0x0000) {
				slot_map[slot] = client_addr;
				return slot;
			}
		}
		return SLOT_UNAVAILABLE;
	}

	event message_t * JoinReqReceive.receive(message_t *msg, void *payload, uint8_t len){
		// Don't really care which round type it is since head will get node and sink will get head, no conflict
		am_addr_t client_addr;
		uint8_t client_future_slot;
		if (join_lock)
			return msg;
		join_lock = TRUE;
		if (len != sizeof(join_req_msg_t))
			return msg;
		client_addr = call AMPacket.source(msg);
		client_future_slot = allocateNewSlot(client_addr);
		if(is_sink) {
			call SystemScheduler.updateSlotMap(client_future_slot, ut_add);
		} else {
			call LocalScheduler.updateSlotMap(client_future_slot, ut_add);
		}
		call Logger.logValue("Client", client_addr, TRUE, log_lvl_info);
		call Logger.logValue("Slot", client_future_slot, FALSE, log_lvl_info);
		sendJoinAns(client_addr, client_future_slot);
		return msg;
	}

	event void DataPkgSend.sendDone(message_t *msg, error_t error){
		// TODO Auto-generated method stub
		call Logger.log("Data pkg sent", log_lvl_info);
	}

	void sendBigMsgProtocol(uint8_t sent_time) {

	}

	void sendAssignment(uint8_t slot_no) {
		uint8_t* tmp_ptr;
		uint8_t tmp_idx;
		uint32_t check_on_off = 1 << slot_no;
		if(group_id != SYSTEM_GROUP_ID) {
			head_to_node_assignment_msg = (head_to_node_assignment_msg_t*)call AssignmentSend.getPayload(&assignment_pkt, sizeof(head_to_node_assignment_msg_t));
			if((check_on_off & structured_sink_to_head_assignment_msg.slot_map_on_off) != 0)
				call Logger.log("No need", log_lvl_info);
			else
				call Logger.log("Need off", log_lvl_info);
			head_to_node_assignment_msg->is_new_head = (slot_no == structured_sink_to_head_assignment_msg.slot_no_of_new_head?TRUE:FALSE);
			head_to_node_assignment_msg->new_group_id = structured_sink_to_head_assignment_msg.slot_map_new_group_id[slot_no - 2];
			head_to_node_assignment_msg->on_off = ((check_on_off & structured_sink_to_head_assignment_msg.slot_map_on_off) != 0?FALSE:TRUE);
			call AssignmentSend.send(slot_map[slot_no], &assignment_pkt, sizeof(head_to_node_assignment_msg_t));
		} else {
			if(SLOT_PER_ROUND_DEFAULT > 22) {
				sendBigMsgProtocol(0);
			} else {
				sink_to_head_assignment_msg = (sink_to_head_assignment_msg_t*)call AssignmentSend.getPayload(&assignment_pkt, sizeof(sink_to_head_assignment_msg_t));
				tmp_ptr = (uint8_t*)&structured_sink_to_head_assignment_msg_sink[slot_no];
				for(tmp_idx = 0; tmp_idx < sizeof(sink_to_head_assignment_msg_t);tmp_idx++) {
					sink_to_head_assignment_msg->data[tmp_idx] = tmp_ptr[tmp_idx];
				}
				call AssignmentSend.send(slot_map[slot_no], &assignment_pkt, sizeof(structured_sink_to_head_assignment_msg_t));
			}
		}
	}

	event void AssignmentSend.sendDone(message_t *msg, error_t error) {
		// TODO implement logic here
		call Logger.log("Assignment sent!", log_lvl_info);
	}

	uint8_t receive_time = 0;
	event message_t * AssignmentReceive.receive(message_t *msg, void *payload, uint8_t len) {
		uint8_t tmp_idx;
		uint8_t* tmp_ptr;
		if (is_sink)
			return msg;
		if(is_head) {
			sink_to_head_assignment_msg = (sink_to_head_assignment_msg_t*)payload;
			receive_time++;
			switch(receive_time){
				case 1:
					tmp_ptr = (uint8_t*)&structured_sink_to_head_assignment_msg;
					for(tmp_idx = 0; tmp_idx < len; tmp_idx++) {
						tmp_ptr[tmp_idx] = sink_to_head_assignment_msg->data[tmp_idx];
					}
					group_id = structured_sink_to_head_assignment_msg.head_new_group_id;
					break;
				case 2:
					tmp_ptr = (uint8_t*)&structured_sink_to_head_assignment_msg;
					tmp_ptr += len;
					for(tmp_idx = 0; tmp_idx < len; tmp_idx++) {
						tmp_ptr[tmp_idx] = sink_to_head_assignment_msg->data[tmp_idx];
					}
					group_id = structured_sink_to_head_assignment_msg.head_new_group_id;
					receive_time = 0;
					break;
				default:
					receive_time = 0;
			}
		} else {
			if(len != sizeof(head_to_node_assignment_msg_t))
				return msg;
			head_to_node_assignment_msg = (head_to_node_assignment_msg_t*)payload;
			group_id = head_to_node_assignment_msg->new_group_id;
			off_time = head_to_node_assignment_msg->on_off;
			rested = !off_time;
			if(!off_time)
				call Logger.log("No need", log_lvl_dbg);
			else
				call Logger.log("Need off", log_lvl_dbg);
			is_new_head = head_to_node_assignment_msg->is_new_head;
		}
		return msg;
	}

	// Unuse event
	event void Settings.sleepSlotPerRoundChange(uint8_t *sleep_slot_per_round){
		// TODO Auto-generated method stub
	}

	event void Settings.slotPerRoundChange(uint8_t *slot_per_round){
		// TODO Auto-generated method stub
	}

	event void Settings.slotDurationChanged(uint16_t *slot_duration){
		// TODO Auto-generated method stub
	}
}