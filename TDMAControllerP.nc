#include <Timer.h>
#include "slot_scheduler.h"
typedef enum {
	ST_TIMESYNC = 0,
	ST_JOIN = 1,
	ST_DATA				// This data will be the rest
} slot_type_t;

#define SLEEP_THRESHOLD_DEFAULT	3
#define SETUP_COUNTDOWN			4
#define SLOT_UNAVAILABLE 		0xFD
#define MAX_MISSED_SYNC 		4
#define TOTAL_ROUND_PER_RESET	10

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
		interface SplitControl as RadioControl;
		interface SlotScheduler as SystemScheduler;
		interface SlotScheduler as LocalScheduler;
		interface Settings;
		interface ReadData;
	}
}

implementation{
	bool is_sink = FALSE;
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

	uint8_t system_sleep_slots = 0;
	bool setting_up_net = TRUE;
	uint8_t setup_countdown = SETUP_COUNTDOWN;
	am_addr_t* slot_map = NULL;
	uint8_t* missed_pkg_count = NULL;
	uint8_t current_round_idx = TOTAL_ROUND_PER_RESET;
	bool join_lock = FALSE;

	void startSlotTask(tdma_round_type_t round_type, slot_type_t slot_type);
	
	command error_t TDMAController.start(){
		// TODO this part need to be changed to more flexible
		uint8_t *round_norm_slot;
		round_norm_slot = call Settings.slotPerRound();
		system_sleep_slots = *round_norm_slot + *call Settings.sleepSlotPerRound() * 2;
		is_sink = (TOS_NODE_ID == 0x0000);
		is_head = (TOS_NODE_ID % 4 == 0);
		// Sink code
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
			bzero(slot_map, sizeof(am_addr_t) * *round_norm_slot);
			timesync_msg = (timesync_msg_t *)call TSSend.getPayload(&timesync_packet, sizeof(timesync_msg_t));
			join_ans_msg = (join_ans_msg_t *)call JoinAnsSend.getPayload(&join_ans_packet, sizeof(join_ans_msg_t));
			call Logger.log("Done setting up for head and sink", log_lvl_info);
		}
		return SUCCESS;
	}

	void sendSyncBeacon(tdma_round_type_t type) {
		uint8_t status;
		timesync_msg = (timesync_msg_t*)call TSSend.getPayload(&timesync_packet, sizeof(timesync_msg_t));
		timesync_msg->remain_round = setup_countdown;
		// TODO Need set on-off protocol
		timesync_msg->on_off_switch = 0x01;
		// TODO If other flags are needed in the future
		if(type == TDMA_ROUND_SYSTEM) {
			timesync_msg->other_flag = 1 << 3;
		} else {
			timesync_msg->other_flag &= 0xF7;
		}
		if(type == TDMA_ROUND_SYSTEM) {
			setup_countdown = setup_countdown==0?0:setup_countdown-1;
			status = call TSSend.send(AM_BROADCAST_ADDR, &timesync_packet, sizeof(timesync_msg_t), *call SystemScheduler.getSystemTime());
		} else
			status = call TSSend.send(AM_BROADCAST_ADDR, &timesync_packet, sizeof(timesync_msg_t), *call LocalScheduler.getSystemTime());
		call Logger.logValue("Set up phase end in", setup_countdown, FALSE, log_lvl_info);
		call Logger.logValue("Send timesync msg status", status, FALSE, log_lvl_dbg);
	}

	void sendJoinReq(tdma_round_type_t type) {
		uint8_t status;
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
		status = call DataPkgSend.send(head_addr, &data_pkg_packet, sizeof(data_pkg_msg_t));
		call Logger.logValue("Sending data... Status", status, FALSE, log_lvl_dbg);
	}
	
	void startSlotTask(tdma_round_type_t round_type, slot_type_t slot_type) {
		// TODO improve
		if (round_type == TDMA_ROUND_SYSTEM) {
			switch (slot_type) {
				case ST_TIMESYNC:
					if(is_sink) {
						sendSyncBeacon(round_type);
						call Logger.log("Sending Sync Beacon System", log_lvl_info);
					}
					break;
				case ST_JOIN:
					if(joined || is_sink)
						break;
					call Logger.log("Sending Join Req", log_lvl_info);
					sendJoinReq(round_type);
					break;
				default:
					if(is_sink)
						break;
					if((call SystemScheduler.mode() == MODE_REPEAT) && !joined){
						sendJoinReq(round_type);
						call Logger.log("Sending Join Req", log_lvl_info);
						break;
					}
					if(setup_countdown > 0) {
						call Logger.log("In set up phase", log_lvl_dbg);
						break;
					}
					if(!joined) {
						sendJoinReq(round_type);
						break;
					}
					sendData();
					call Logger.log("Sending Data Pkg", log_lvl_info);
						// Send Join req if in mode repeat and haven't successfully joined
					break;
			}
		} else {
			switch (slot_type) {
				case ST_TIMESYNC:
					if(is_head) {
						sendSyncBeacon(round_type);
						call Logger.log("Sending Sync Beacon Local", log_lvl_info);
					}
					break;
				case ST_JOIN:
					if(joined || is_head)
						break;
					call Logger.log("Sending Join Req", log_lvl_info);
					sendJoinReq(round_type);
						break;
					break;
				default:
					if(is_head)
						break;
					if((call LocalScheduler.mode() == MODE_REPEAT) && !joined){
						sendJoinReq(round_type);
						call Logger.log("Sending Join Req", log_lvl_info);
						break;
					}
					if(setup_countdown > 0) {
						call Logger.log("In set up phase", log_lvl_dbg);
						break;
					}
					if(!joined){
						sendJoinReq(round_type);
						break;
					}
					sendData();
					call Logger.log("Sending Data Pkg", log_lvl_info);
					break;
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

	command error_t TDMAController.stop(){
		// TODO Stop everything, reset variables
		is_sink = FALSE;
		is_head = FALSE;
		sync_mode = FALSE;
		joined = FALSE;
		sync_received = FALSE;
		missed_sync_count = 0; 
		head_addr = 0x0000;
		system_sleep_slots = 0;
		setting_up_net = TRUE;
		setup_countdown = SETUP_COUNTDOWN;
		free(missed_pkg_count);
		current_round_idx = TOTAL_ROUND_PER_RESET;
		free(slot_map);
		call SystemScheduler.stop();
		call LocalScheduler.stop();
		return SUCCESS;
	}
	
	// RadioControl Interface
	event void RadioControl.startDone(error_t error){
		call Logger.log("Radio started!", log_lvl_info);
		if (error != SUCCESS && error != EALREADY) {
			call Logger.logValue("Radio failed to start. Code", error, TRUE, log_lvl_err);
			call RadioControl.start();
		} else {
			if(call SystemScheduler.isSlotActive()) {
				// call Logger.log("System scheduler start slot task", log_lvl_dbg);
				startSlotTask(TDMA_ROUND_SYSTEM, call SystemScheduler.currentSlot());
			}
			if(call LocalScheduler.isSlotActive())
				startSlotTask(TDMA_ROUND_LOCAL, call LocalScheduler.currentSlot());
//			call Logger.log("Radio started!", log_lvl_dbg);
		}
	}

	event void RadioControl.stopDone(error_t error){
		if (error == SUCCESS || error == EALREADY)
			call Logger.log("Radio Stopped!", log_lvl_info);
	}

	void checkOffTimeArrived(uint16_t on_off_flag) {
		
	}

	// Node receive TS for Local Scheduler only
	// Head receive TS for System Scheduler only
	event message_t * TSReceive.receive(message_t *msg, void *payload, uint8_t len) {
		uint32_t ref_time;
		if(is_sink)
			return msg;
		call Logger.log("TS received", log_lvl_info);
		if(len != sizeof(timesync_msg_t))
			return msg;
		if(!call TSPacket.isValid(msg))
			return msg;
		missed_sync_count = 0;
		timesync_msg = (timesync_msg_t*)payload;
		ref_time = call TSPacket.eventTime(msg);
		setup_countdown = timesync_msg->remain_round;
		//call Logger.log("Packet:", log_lvl_dbg);
		//call Logger.logValue("On off switch", timesync_msg->on_off_switch, TRUE, log_lvl_dbg);
		//call Logger.logValue("Remain round", timesync_msg->remain_round, TRUE, log_lvl_dbg);
		//call Logger.logValue("Other flag", timesync_msg->other_flag, TRUE, log_lvl_dbg);
		if(!sync_mode) {
			if(timesync_msg->other_flag & (1 << 3)) {
				call SystemScheduler.syncSystemTime(ref_time);
			} else {
				call LocalScheduler.syncSystemTime(ref_time);
			}
			return msg;
		}
		// If syncing, the 
		if(is_head) {
			// This will setup head's System scheduler only
			if(timesync_msg->other_flag & (1 << 3)) {
				head_addr = call AMPacket.source(msg);
				call Logger.log("System scheduler start for head", log_lvl_dbg);
				call SystemScheduler.start(SLOT_REPEAT, ref_time, 0, system_sleep_slots, call Settings.slotDuration(), call Settings.slotPerRound());
				sync_mode = FALSE;
			} else {
				call Logger.log("System scheduler did not start", log_lvl_dbg);
			}
		} else {
			// This will setup node's Local scheduler only
			if((timesync_msg->other_flag & (1 << 3)) == 0) {
				head_addr = call AMPacket.source(msg);
				call Logger.log("Local scheduler start for head", log_lvl_dbg);
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
		call ReadData.readMsg((data_pkg_msg_t*) payload);
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
		if(join_ans_msg->slot == SLOT_UNAVAILABLE) {
			// TODO Do something here
			return msg;
		}
		if(call SystemScheduler.isSlotActive()) {
			joined = TRUE;
			call SystemScheduler.reset(join_ans_msg->slot);
			call LocalScheduler.start(SLOT_REPEAT, *call SystemScheduler.getSystemTime(), (system_sleep_slots - *call Settings.slotPerRound())* *call Settings.slotDuration() , system_sleep_slots, call Settings.slotDuration(), call Settings.slotPerRound());
		}
		if(call LocalScheduler.isSlotActive()) {
			joined = TRUE;
			call LocalScheduler.reset(join_ans_msg->slot);
		}
		return msg;
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
		call Logger.log("New round system", log_lvl_info);
		missed_sync_count++;
		signal TDMAController.newRound(TDMA_ROUND_SYSTEM);
	}

	event void SystemScheduler.endRound() {
		if(current_round_idx > 0) {
			current_round_idx--;
		} else {
			current_round_idx = TOTAL_ROUND_PER_RESET;
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
		call Logger.logValue("System slot started. Slot", actual_slot, FALSE, log_lvl_dbg);
		if(call RadioControl.start() == EALREADY)
			startSlotTask(TDMA_ROUND_SYSTEM, actual_slot);
	}

	event void SystemScheduler.slotEnded(uint8_t slot_no, uint8_t actual_slot){
		// TODO Auto-generated method stub
		join_lock = FALSE;
		call Logger.logValue("System slot ended. Slot", actual_slot, FALSE, log_lvl_dbg);
		putRadioToSleep(TDMA_ROUND_SYSTEM, SLEEP_THRESHOLD_DEFAULT);
	}
	
	event void LocalScheduler.startDone(uint8_t slot_no){
		// TODO Auto-generated method stub
		call Logger.log("Start done in TDMA", log_lvl_info);
	}

	event void LocalScheduler.stopDone(error_t err){
		// TODO Auto-generated method stub
		if(!call SystemScheduler.isRunning() && (err == SUCCESS || err == EALREADY)) {
			signal TDMAController.stopDone(SUCCESS);
		}
	}

	event void LocalScheduler.newRound(){
		// TODO Auto-generated method stub
		missed_sync_count++;
		call Logger.log("New round local", log_lvl_info);
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
		// TODO Auto-generated method stub
		join_lock = FALSE;
		call Logger.logValue("Local slot ended. Slot", actual_slot, FALSE, log_lvl_dbg);
		putRadioToSleep(TDMA_ROUND_LOCAL, SLEEP_THRESHOLD_DEFAULT);
	}

	event void LocalScheduler.slotStarted(uint8_t slot_no, uint8_t actual_slot){
		call Logger.logValue("Local slot started. Slot", actual_slot, FALSE, log_lvl_dbg);
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

	// Always success so no need to return!
	void removeAssignedSlot(uint8_t slot) {
		slot_map[slot] = 0x0000;
		return;
	}

	uint8_t allocateNewSlot(am_addr_t client_addr){
		uint8_t slot=2;
		// get next slot
		for (slot; slot < call Settings.slotPerRound(); slot++) {
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
		call Logger.logValue("Client", client_addr, TRUE, log_lvl_info);
		call Logger.logValue("Slot", client_future_slot, FALSE, log_lvl_info);
		sendJoinAns(client_addr, client_future_slot);
		return msg;
	}

	event void DataPkgSend.sendDone(message_t *msg, error_t error){
		// TODO Auto-generated method stub
		call Logger.log("Data pkg sent", log_lvl_info);
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