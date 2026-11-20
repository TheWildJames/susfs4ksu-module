#!/bin/sh
PATH=/data/adb/ksu/bin:$PATH
kernel_version='default'
kernel_build='default'
[ -f $PERSISTENT_DIR/config.sh ] && . $PERSISTENT_DIR/config.sh
## susfs_clone_perm <file/or/dir/perm/to/be/changed> <file/or/dir/to/clone/from>
susfs_clone_perm() {
	TO=$1
	FROM=$2
	if [ -z "${TO}" -o -z "${FROM}" ]; then
		return
	fi
	CLONED_PERM_STRING=$(stat -c "%a %U %G" ${FROM})
	set ${CLONED_PERM_STRING}
	chmod $1 ${TO}
	chown $2:$3 ${TO}
	busybox chcon --reference=${FROM} ${TO}
}

## susfs_hexpatch_props <target_prop_name> <spoofed_prop_name> <spoofed_prop_value>
susfs_hexpatch_props() {
	TARGET_PROP_NAME=$1
	SPOOFED_PROP_NAME=$2
	SPOOFED_PROP_VALUE=$3
	if [ -z "${TARGET_PROP_NAME}" -o -z "${SPOOFED_PROP_NAME}" -o -z "${SPOOFED_PROP_VALUE}" ]; then
		return 1
	fi
	if [ "${#TARGET_PROP_NAME}" != "${#SPOOFED_PROP_NAME}" ]; then
		return 1
	fi
	resetprop -n ${TARGET_PROP_NAME} ${SPOOFED_PROP_VALUE}
	magiskboot hexpatch /dev/__properties__/$(resetprop -Z ${TARGET_PROP_NAME}) $(echo -n ${TARGET_PROP_NAME} | xxd -p | tr "[:lower:]" "[:upper:]") $(echo -n ${SPOOFED_PROP_NAME} | xxd -p | tr "[:lower:]" "[:upper:]")
}

check_missing_prop() {
  local NAME=$1
  local EXPECTED=$2
  local VALUE=$(resetprop $NAME)
  [ -z $VALUE ] && resetprop $NAME $EXPECTED # if the property is missing
}

check_reset_prop() {
  local NAME=$1
  local EXPECTED=$2
  local VALUE=$(resetprop $NAME)
  [ -z $VALUE ] || [ $VALUE = $EXPECTED ] || resetprop $NAME $EXPECTED # if the property is not what we expect
}

check_missing_match_prop() {
  local NAME=$1
  local EXPECTED=$2
  local VALUE=$(resetprop $NAME)
  [ -z $VALUE ] || [ $VALUE = $EXPECTED ] || resetprop $NAME $EXPECTED # if the property is not what we expect
  [ -z $VALUE ] && resetprop $NAME $EXPECTED # if the property is missing
}

contains_reset_prop() {
  local NAME=$1
  local CONTAINS=$2
  local NEWVAL=$3
  [[ "$(resetprop $NAME)" = *"$CONTAINS"* ]] && resetprop $NAME $NEWVAL
}

spoof_uname() {
	[ -z $kernel_version ] && kernel_version='default'
	[ -z $kernel_build ] && kernel_build='default'
	${SUSFS_BIN} set_uname "$kernel_version" "$kernel_build"
}

## susfs_have_cmd <subcommand>
## Returns success when the installed ksu_susfs binary knows the subcommand.
## Used for features that have no CONFIG_KSU_SUSFS_* string in
## 'show enabled_features' and no distinct susfs version yet.
susfs_have_cmd() {
	[ -n "$1" ] || return 1
	${SUSFS_BIN} --help 2>/dev/null | sed 's/^[[:space:]]*//' | cut -d' ' -f1 | grep -qx "$1"
}

## susfs_join_app_list <file>
## Collapses a per-line or comma separated app list into the single comma
## separated argument the *_uid_filter subcommands expect.
susfs_join_app_list() {
	[ -f "$1" ] || return 0
	grep -v "#" "$1" | tr -d ' 	\r' | grep -v '^$' | tr '\n' ',' | sed 's/,*$//'
}
