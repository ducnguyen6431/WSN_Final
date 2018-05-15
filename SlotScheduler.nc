typedef enum {
	ut_add,
	ut_delete
} update_type_t;

typedef enum {
	MODE_REPEAT,
	MODE_NORMAL
} scheduler_mode_t;

interface SlotScheduler {
	// start with slot no, start time and number of sleep slot
	// if slot_no == -1 => notify every slot start and end
	// slot 0 will always be on
	command error_t start(uint8_t slot_no, 
						  uint32_t start_time, 
						  uint32_t delay,
						  uint8_t sleep_slots_per_round, 
						  uint16_t* duration, 
						  uint8_t *active_slot_per_round);
	// start done with slot
	event void startDone(uint8_t slot_no);
	// stop scheduler
	command error_t stop();
	// stop done if everything is ok the return SUCCESS
	//If fail, turn on DEBUG flag and check log
	event void stopDone(error_t err);
	command void reset(uint8_t initial_slot);
	command bool isRunning();
	command void syncSystemTime(uint32_t system_time);
	command uint32_t* getSystemTime();
	command uint8_t currentSlot();
	command uint8_t nextSlot();
	command bool isSlotActive();
	command scheduler_mode_t mode();
	command error_t updateSlotMap(uint8_t new_slot_pos, 
								  update_type_t type);
	event void newRound();
	event void endRound();
	event void slotStarted(uint8_t slot_no, uint8_t actual_slot_no);
	event void slotEnded(uint8_t slot_no, uint8_t actual_slot_no);
	
	// Not using for now
	command void updateSleepSlot(uint8_t sleep_slots_per_round);
	
}