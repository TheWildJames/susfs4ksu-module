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

## priority_uid_filter: exactly one source at a time.
##  - all-apps toggle on : every installed app with uid >= 10000, the list is ignored
##  - toggle off         : only the manual list in priority_uid_filter.txt
## The kernel replaces the whole filter per call, so only one list ever goes out.
if echo "$susfs_features" | grep -q "CONFIG_KSU_SUSFS_PRIORITY_UID_FILTER"; then
	if [ "$priority_uid_filter_all_apps" = 1 ] && [ -f /data/system/packages.list ]; then
		priority_apps=$(awk '$2 >= 10000 { pkg = pkg (pkg ? "," : "") $1 } END { print pkg }' /data/system/packages.list)
		priority_source="all installed apps"
	else
		priority_apps=$(susfs_join_app_list "$PERSISTENT_DIR/priority_uid_filter.txt")
		priority_source="manual list"
	fi

	if [ -n "$priority_apps" ]; then
		${SUSFS_BIN} set_priority_uid_filter "$priority_apps" \
			&& echo "[priority_uid_filter]: susfs4ksu/apply_uid_filters $priority_source, $(echo "$priority_apps" | awk -F, '{print NF" apps"}')" >> $logfile1
	else
		# The kernel has no "clear" opcode and rejects an empty string, but it
		# skips package names it cannot resolve and publishes the resulting
		# (empty) bitmap - so one uninstallable name clears the filter live
		# instead of waiting for a reboot.
		${SUSFS_BIN} set_priority_uid_filter "susfs.clear.filter" \
			&& echo "[priority_uid_filter]: cleared, no apps configured" >> $logfile1
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
