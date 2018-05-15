#ifndef MESSAGES_H
#define MESSAGES_H

typedef nx_struct {
	nx_uint16_t on_off_switch;
	nx_uint8_t remain_round;
	// other_flag bit map
	// byte 0: full slot then 1 else 0 - current
	// byte 1: can reach sink - later
	// byte 2: can reach other head connected to sink - later
	// byte 3: 0 - system schedule | 1 - local schedule
	// byte 4: 0 - normal | 1 - time to reset!
	// byte 5:
	// byte 6:
	// byte 7:
	nx_uint8_t other_flag;
} timesync_msg_t;

typedef nx_struct {
	nx_uint16_t vref;
	nx_uint16_t temperature;
	nx_uint16_t humidity;
	nx_uint16_t photo;
	nx_uint16_t radiation;
} data_pkg_msg_t;

typedef nx_struct {
} join_req_msg_t;

typedef nx_struct {
	nx_uint8_t slot;
} join_ans_msg_t;

#endif