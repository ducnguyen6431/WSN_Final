#include "slot_scheduler.h"
generic module SlotSchedulerP() @safe(){
	provides interface SlotScheduler;
	uses {
		interface Logger;
		interface Timer<TMilli> as SystemTimer;
		interface Timer<TMilli> as SlotTimer;
	}
}
implementation {
	bool is_active = FALSE;
	bool is_running = FALSE;
	bool is_slot_start = FALSE;
	uint32_t system_time_ref = 0x0;
	uint32_t round_active_time = 0x0;
	uint32_t round_offline_time = 0x0;
	uint16_t* duration_local;
	uint32_t slot_map = 0x0003;
	uint8_t actual_slot = SLOT_INACTIVE;
	uint8_t last_slot = SLOT_INACTIVE;
	uint8_t *active_slot_per_round_ref;
	bool rest_next_round = FALSE;

	uint8_t getNextSlot(uint8_t);
	
	command error_t SlotScheduler.start(uint8_t initial_slot, uint32_t start_time, uint32_t delay, uint8_t sleep_slots_per_round, uint16_t* duration, uint8_t* active_slot_per_round) {
		if(is_running) {
			return EALREADY;
		}
		active_slot_per_round_ref = active_slot_per_round;
		if(initial_slot > *active_slot_per_round_ref && initial_slot != SLOT_REPEAT)
			return FAIL;
		duration_local = duration;
		is_running = TRUE;
		system_time_ref = start_time;
		round_active_time = *duration_local * *active_slot_per_round_ref;
		round_offline_time = *duration_local * sleep_slots_per_round;
		is_active = TRUE;
		call SystemTimer.startOneShotAt(system_time_ref, round_active_time + delay);
		signal SlotScheduler.newRound();
		if (initial_slot == SLOT_REPEAT) {
			slot_map = 0xFFFF;
			last_slot = SLOT_REPEAT;
			actual_slot = getNextSlot(actual_slot);
			call SlotTimer.startOneShotAt(system_time_ref, 0 + delay);
		} else {
			call SlotScheduler.updateSlotMap(initial_slot, ut_add);
			call SlotTimer.startOneShotAt(system_time_ref, *duration_local * getNextSlot(last_slot) + delay);
			last_slot = getNextSlot(last_slot);
			actual_slot = getNextSlot(actual_slot);
		}
		system_time_ref += delay;
		signal SlotScheduler.startDone(initial_slot);
		return SUCCESS;
	}

	command void SlotScheduler.reset(uint8_t initial_slot) {
		slot_map = 0x0003;
		last_slot = actual_slot;
		call SlotScheduler.updateSlotMap(initial_slot, ut_add);
	}

	uint8_t getNextSlot(uint8_t last_slot_local) {
		uint8_t next_slot = last_slot_local;
		uint32_t ptr = 1 << last_slot_local;
		if(last_slot_local == SLOT_REPEAT) {
			// if being on full on mode, return SLOT_REPEAT and the Slot Timer will be fired on all slot 
			return SLOT_REPEAT;
		}
		if(last_slot_local == SLOT_INACTIVE) {
			return 0;
		}
		while(next_slot < *active_slot_per_round_ref) {
			ptr <<= 1;
			next_slot += 1;
			if(ptr & slot_map) {
				return next_slot;
			}
		}
		return SLOT_INACTIVE;
	}

	command error_t SlotScheduler.updateSlotMap(uint8_t new_slot_pos, update_type_t type) {
		uint8_t new_slot = 1;
		if(new_slot_pos >= 32) {
			call Logger.logValue("New slot position can't bigger than 31. Slot position", new_slot_pos, FALSE, log_lvl_err);
			return FAIL;
		}
		new_slot <<= new_slot_pos;
		switch(type) {
			case ut_add:
				call Logger.logValue("Adding new slot to slot map. Slot position", new_slot_pos, FALSE, log_lvl_info);
				slot_map |= new_slot;
				break;
			case ut_delete:
				call Logger.logValue("Removing slot from slot map. Slot position", new_slot_pos, FALSE, log_lvl_info);
				if(slot_map && new_slot == 0)
					return EALREADY;
				slot_map -= new_slot;
				break;
			default:
				call Logger.log("Expect value ut_add or ut_delete", log_lvl_err);
				return FAIL;
		}
		return SUCCESS;
	}

	command error_t SlotScheduler.stop(){
		is_active = FALSE;
		is_running = FALSE;
		is_slot_start = FALSE;
		system_time_ref = 0x0;
		round_active_time = 0x0;
		round_offline_time = 0x0;
		slot_map = 0x0001;
		last_slot = SLOT_INACTIVE;
		call SystemTimer.stop();
		call SlotTimer.stop();
		signal SlotScheduler.stopDone(SUCCESS);
		return SUCCESS;
	}
	
	// If out of active time then everything will go to sleep
	// TODO make active time last longer than just active time (Setting up phase)
	event void SystemTimer.fired(){
		if (!is_running) {
			call Logger.log("Retry stopping SystemTimer", log_lvl_dbg);
			call SystemTimer.stop();
			return;
		}
		if(is_active) {
			// Start hibernation process, put the whole thing to sleep
			is_active = FALSE;
			if(last_slot != SLOT_REPEAT)
				last_slot = SLOT_INACTIVE;
			if(is_slot_start) {
				call Logger.log("Force end last slot", log_lvl_info);
				is_slot_start = FALSE;
				signal SlotScheduler.slotEnded(last_slot, actual_slot);
				call SlotTimer.stop();
			}
			actual_slot = SLOT_INACTIVE;
			signal SlotScheduler.endRound();
			system_time_ref += round_active_time;
			call SystemTimer.startOneShotAt(system_time_ref, round_offline_time);
		} else {
			// Start a new round
			is_active = TRUE;
			system_time_ref = system_time_ref + round_offline_time;
			signal SlotScheduler.newRound(); 
			call SystemTimer.startOneShotAt(system_time_ref, round_active_time);
			actual_slot = getNextSlot(actual_slot);
			if(last_slot != SLOT_REPEAT) {
				// Not repeat
				call SlotTimer.startOneShotAt(system_time_ref, *duration_local * getNextSlot(last_slot));
				last_slot = getNextSlot(last_slot);
			} else 
				call SlotTimer.startOneShotAt(system_time_ref, 0);
			
		}
	}

	// TODO make active time last longer than just active time (Setting up phase)
	event void SlotTimer.fired(){
		if (!is_running) {
			call Logger.log("Retry stopping SlotTimer", log_lvl_dbg);
			call SlotTimer.stop();
			return;
		}
		if(!is_active)
			return;
		if(!is_slot_start) {
			// Starting of the slot
			is_slot_start = TRUE;
			signal SlotScheduler.slotStarted(last_slot, actual_slot);
			call SlotTimer.startOneShot(*duration_local);
			return;
		}
		// Ending of the slot
		is_slot_start = FALSE;
		signal SlotScheduler.slotEnded(last_slot, actual_slot);
		last_slot = getNextSlot(last_slot);
		actual_slot = getNextSlot(actual_slot);
		if (last_slot == SLOT_REPEAT)
			call SlotTimer.startOneShot(0);
		else
			call SlotTimer.startOneShotAt(system_time_ref, *duration_local * last_slot);
	}
	
	command uint8_t SlotScheduler.nextSlot() {
		return getNextSlot(actual_slot);
	}
	
	// Check if any slot of this scheduler is being active
	command bool SlotScheduler.isSlotActive() {
		return is_slot_start;
	}
	
	command scheduler_mode_t SlotScheduler.mode(){
		if(last_slot == SLOT_REPEAT)
			return MODE_REPEAT;
		return MODE_NORMAL;
	}
	
	command uint8_t SlotScheduler.currentSlot() {
		return (call SystemTimer.getNow() - system_time_ref) / *duration_local;
	}
	
	command uint32_t * SlotScheduler.getSystemTime(){
		if(system_time_ref == 0)
			system_time_ref = call SystemTimer.getNow();
		return &system_time_ref;
	}

	command bool SlotScheduler.isRunning(){
		return is_running;
	}

	command void SlotScheduler.updateSleepSlot(uint8_t sleep_slots_per_round){
		// TODO Auto-generated method stub
	}

	command void SlotScheduler.syncSystemTime(uint32_t system_time){
		system_time_ref = system_time;
		// TODO Ensure sync time properly
	}
}