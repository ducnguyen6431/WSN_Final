// Full round = head round + cluster round
// Number of slot in a full round = (sleep_slot + normal_slot) * 2
// Any round < full round is a small round
/* Full round:
 * n = normal_slot
 * s = sleep slot
 * h = head round
 * c = cluster round
 * 
 * |n|n|...|n|n|s|s|...|s|s|n|n|...|n|n|s|s|...|s|s|
 * |     cluster round     |      head round       |
 * |                   full round                  |
 */


interface Settings {
	// Number of sleep slots between every type of round are equal
	command uint8_t* sleepSlotPerRound();
	command void setSleepSlotPerRound(uint8_t sleep_slot_per_round);
	event void sleepSlotPerRoundChange(uint8_t* sleep_slot_per_round);
	// Slot duration can be change if base demand to do so.
	command uint16_t* slotDuration();
	command void setSlotDuration(uint16_t slot_duration);
	event void slotDurationChanged(uint16_t* slot_duration);
	// number of normal slots between every type of round are equal
	command uint8_t* slotPerRound();
	command void setSlotPerRound(uint8_t slot_per_round);
	event void slotPerRoundChange(uint8_t* slot_per_round);	
}