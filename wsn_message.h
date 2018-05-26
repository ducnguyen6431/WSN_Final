#ifndef MY_MESSAGES_H
#define MY_MESSAGES_H
#include "settings.h"
typedef nx_struct {
	// Timesync still need a group_id
	nx_uint8_t group_id;
	nx_uint8_t remain_round; // remain round until network reset
	// other_flag bit map
	// byte 0: full slot then 1 else 0 - current
	// byte 1: can reach sink - later
	// byte 2: can reach other head connected to sink - later
	// byte 3:
	// TODO replace flag of byte 3 with group_id
	// byte 4: 0 - normal | 1 - time to reset!
	// byte 5:
	// byte 6:
	// byte 7:
	nx_uint8_t other_flag;
} timesync_msg_t;

typedef nx_struct {
	nx_uint8_t new_group_id;
	nx_bool on_off;
	nx_bool is_new_head;
} head_to_node_assignment_msg_t;

typedef struct {
	uint8_t slot_no_of_new_head; // Head cannot be 
	uint8_t slot_map_new_group_id[SLOT_PER_ROUND_DEFAULT-2];
	uint8_t head_new_group_id;
	uint32_t slot_map_on_off;
} structured_sink_to_head_assignment_msg_t; // This might not be saved in TDMAController but in Nam's module, parse and setup from PC

typedef nx_struct {     
	nx_uint8_t data[28];
	// 28 is max content length of a packet
	// |01|02|03|04|
	// 01: new head for next big_round - meaning: slot_position (1 byte)
	// 02: up to 30 bytes of group_id for each node in slot_map (30 bytes = 30 slot from 2 to 31) the number of byte depend on SLOT_PER_ROUND_DEFAULT in settings.h
	// 03: 1 byte group_id for current big round head
	// 04: on off slot map (4 bytes)
	// this msg will transmit data with out knowing what is inside and will be parsed later by specific function like: 28 byte of group id then another 28 bytes of group id and on off map. On off map will take 32 bit after 3 byte of group id in second packet. The second packet is base on if number of nodes per cluster have more than 24 node if smaller than 24 node. This 2 packet will be parsed at beginning of local scheduler!
} sink_to_head_assignment_msg_t;

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

typedef nx_struct {
} assignment_start_signal;

typedef nx_struct {
} assignment_ack_signal;

#endif