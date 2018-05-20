#ifndef SETTINGS_H
#define SETTINGS_H

#define ONE_SECOND	1000

// For settings module
#ifndef SLEEP_SLOT_DEFAULT
#define SLEEP_SLOT_DEFAULT	2
#endif
#ifndef SLOT_DURATION_DEFAULT
#define SLOT_DURATION_DEFAULT ONE_SECOND * 1
#endif
#ifndef SLOT_PER_ROUND_DEFAULT
#define SLOT_PER_ROUND_DEFAULT 5
#endif

// For Delay between 
#define DELAY_BETWEEN_BIG_ROUND	0 * ONE_SECOND // Currently, we shouldn't change this

// For TDMAController
#define SYSTEM_GROUP_ID			0x00
#define SLEEP_THRESHOLD_DEFAULT	3
#define TOTAL_ROUND_PER_RESET	10
#define SETUP_COUNTDOWN			TOTAL_ROUND_PER_RESET - 3
#define OFF_ROUND_MAX			5
#define SLOT_UNAVAILABLE 		0xFD
#define MAX_MISSED_SYNC 		3
#define MISSED_PKG_THRESHOLD	2
#define INITIAL_HEAD_DIVIDE_NO	4 // if tos_node_id mod this == 0 => this node is head. This will define how many group this network will have
#define NO_HEAD_TIMEOUT			5 // No matter which TS, if 5 TS are missed then restart!

#endif