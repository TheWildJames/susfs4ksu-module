#!/bin/sh
# Applies the two uid filters to the kernel:
#   priority_uid_filter     - uids hidden from getpriority/setpriority/ioprio probing
#   sus_path_uid_filter     - apps that may still see the sus paths
# Called from boot-completed.sh and from the WebUI when a filter toggle or the
# custom lists change, so both paths always behave the same way.
MODDIR=/data/adb/modules/susfs4ksu
SUSFS_BIN=/data/adb/ksu/bin/ksu_susfs
. ${MODDIR}/utils.sh
PERSISTENT_DIR=/data/adb/susfs4ksu
tmpfolder=/data/adb/ksu/susfs4ksu
mkdir -p $tmpfolder/logs
logfile1="$tmpfolder/logs/susfs1.log"

priority_uid_filter_all_apps=0
[ -f $PERSISTENT_DIR/config.sh ] && . $PERSISTENT_DIR/config.sh

susfs_features=$(${SUSFS_BIN} show enabled_features)

## priority_uid_filter: the manual list, plus every installed app uid when the
## all-apps toggle is on (the kernel replaces the whole filter per call, so the
## two sources have to go out as one list).
if echo "$susfs_features" | grep -q "CONFIG_KSU_SUSFS_PRIORITY_UID_FILTER"; then
	priority_apps=$(susfs_join_app_list "$PERSISTENT_DIR/priority_uid_filter.txt")

	if [ "$priority_uid_filter_all_apps" = 1 ] && [ -f /data/system/packages.list ]; then
		all_apps=$(awk '$2 >= 10000 { pkg = pkg (pkg ? "," : "") $1 } END { print pkg }' /data/system/packages.list)
		priority_apps=$(susfs_merge_app_lists "$priority_apps" "$all_apps")
	fi

	if [ -n "$priority_apps" ]; then
		${SUSFS_BIN} set_priority_uid_filter "$priority_apps" \
			&& echo "[priority_uid_filter]: susfs4ksu/apply_uid_filters $(echo "$priority_apps" | awk -F, '{print NF" apps"}')" >> $logfile1
	else
		echo "[priority_uid_filter]: no apps to add, filter unchanged (reboot clears it)" >> $logfile1
	fi
fi

## sus_path_uid_filter: apps still allowed to see the sus paths
if susfs_have_cmd set_sus_path_uid_filter; then
	uid_filter_apps=$(susfs_join_app_list "$PERSISTENT_DIR/sus_path_uid_filter.txt")
	if [ -n "$uid_filter_apps" ]; then
		${SUSFS_BIN} set_sus_path_uid_filter "$uid_filter_apps" \
			&& echo "[sus_path_uid_filter]: susfs4ksu/apply_uid_filters $uid_filter_apps" >> $logfile1
	fi
fi
