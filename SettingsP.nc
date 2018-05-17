#include "settings.h"
module SettingsP {
	provides interface Settings;
}
implementation {
	uint8_t sleep_slot_per_round_ref = SLEEP_SLOT_DEFAULT;
	uint16_t slot_duration_ref = SLOT_DURATION_DEFAULT;
	uint8_t slot_per_round_ref = SLOT_PER_ROUND_DEFAULT;
	command uint8_t* Settings.sleepSlotPerRound() {
		return &sleep_slot_per_round_ref;
	}
	
	command void Settings.setSleepSlotPerRound(uint8_t sleep_slot_per_round) {
		sleep_slot_per_round_ref = sleep_slot_per_round;
		signal Settings.sleepSlotPerRoundChange(&sleep_slot_per_round_ref);
	}
	
	command uint16_t* Settings.slotDuration() {
		return &slot_duration_ref;
	}
	
	command void Settings.setSlotDuration(uint16_t slot_duration) {
		slot_duration_ref = slot_duration;
		signal Settings.slotDurationChanged(&slot_duration_ref);
	}
	
	command uint8_t* Settings.slotPerRound() {
		return &slot_per_round_ref;
	}
	
	command void Settings.setSlotPerRound(uint8_t slot_per_round) {
		slot_per_round_ref = slot_per_round;
		signal Settings.slotPerRoundChange(&slot_per_round_ref);
	}
}
