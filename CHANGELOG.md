## Unreleased
### Features
* Added `priority_uid_filter` support (susfs v2.4.0+, `CONFIG_KSU_SUSFS_PRIORITY_UID_FILTER`)
    * App list: `/data/adb/susfs4ksu/priority_uid_filter.txt` (one package per line or comma separated)
    * Applied at `boot-completed.sh`, uids are hidden from getpriority/setpriority/ioprio probing
    * WebUI: custom feature editor entry, applies live on save
* Added `sus_path_uid_filter` support (susfs kernel tree after v2.4.0)
    * App list: `/data/adb/susfs4ksu/sus_path_uid_filter.txt` (one package per line or comma separated)
    * Set before the sus_path entries at `boot-completed.sh` so the allowed uids exist
    * Detected by probing `ksu_susfs --help` (the feature exposes no `CONFIG_*` string), so the binary has to support `set_sus_path_uid_filter`
    * WebUI: custom feature editor entry, applies live on save
* WebUI: custom feature editor entries may declare an `applyCmd`; the save action then applies the change immediately instead of only asking for a reboot
* Bundled `ksu_susfs` rebuilt from `TheWildJames/susfs4ksu-binaries@universal-binary`, which adds `set_sus_path_uid_filter` on top of upstream's `priority_uid_filter`, so both features are usable out of the box
    * the binary update/check paths (`customize.sh`, `action.sh`, `susfs-bin-check.sh`, `susfs-bin-update.sh`) now pull from that fork instead of `sidex15/susfs4ksu-binaries`
* New toggle "Hide All App UIDs" (below Emulate Vold App Data Isolation): feeds every installed app with uid >= 10000 from `/data/system/packages.list` into `priority_uid_filter`, unioned with the manual list, so uids you never listed are hidden from getpriority/setpriority/ioprio probing too
    * both filters now live in `apply_uid_filters.sh`, called from `boot-completed.sh` and from the WebUI, so a toggle takes effect without a reboot
    * turning it off (or emptying the list) clears the kernel filter immediately: an uninstallable placeholder name is sent, which the kernel skips, publishing an empty bitmap - no reboot needed

## v1.5.2+ Revision 28
### Notes
Sorry for the very late update. This update focuses on WebUI configuration import/export, boot-stage script performance and correctness fixes, and better handling of newer susfs (v2.0.0+/v2.1.0+) kernel implementations.

For more frequent updates use the CI version [here](https://nightly.link/sidex15/susfs4ksu-module/workflows/build/v1.5.2%2B?preview)

### WebUI
* Implement SUSFS import config feature
    * Include/exclude "Auto add and umount for zygote system process" flag files in export/import depending on the detected susfs version (not applicable on susfs v2.0.0+)
    * Use `LegitSusfsConfig` to check the validity of the susfs config file.
    * Exported config files are compatible to import from v1.5.2 and above
* Hide 'try umount for zygote system process' toggle on susfs v2.1.0+ with susfs `try_umount`
* Disable `avc_log_spoofing` toggle when greyed out
* Add date to exported susfs logs gzip filename, export to `/sdcard/Download`, and fix export error by only reading the first pid of zygote64
* Refactor `index.js` into feature-based modules
* Localization
    * New Crowdin translations by GitHub Action

### Scripts
* boot-completed: reduce boot-stage overhead and fix correctness issues
    * Reuse the cached `$susfs_features` variable instead of respawning the susfs binary in post-fs-data.sh and service.sh (4 fewer binary calls per boot)
    * Capture `dmesg` once per stage instead of invoking it twice for log append and timestamp extraction
    * Skip `stat()` calls in the open_redirect loop for lines already skipped by `execute_on`
    * Replace `cat | grep` patterns with direct `grep` on `/proc/1/mountinfo`
    * Collapse the five duplicated hide_cusrom `find` blocks into a single case-driven block
    * Replace the per-entry 14-pipeline JSON sus_kstat parser with a single awk pass per object
    * Bound the previously unbounded `/sdcard/Android/data` wait to 60s to prevent boot-completed hanging indefinitely
    * Fix a typo (`sus_su_acitve` -> `sus_su_active`) and remove a duplicate echo that caused key duplication in config.sh
* boot-completed: catch sus_mount mountid tagged within 2 billion for newer susfs implementations
* boot-completed: do not enable ksud umount feature if auto try umount (userspace) is enabled
* service: only use sus_kstat spoofing when it's on susfs v2.0.0+
* customize: add `SUSFS_DECIMAL_MAIN` for checking sus_su install
* Fix GKI bootconfig spoof formatting to match the `key = "value"` bootconfig syntax instead of the compact cmdline format @okhsunrog

### [Universal SUSFS Binary](https://github.com/sidex15/susfs4ksu-binaries/tree/universal-binary)
* refactor: split monolithic main.c into modules built via Makefile
* implement have_susfs_feature function for checking features in dispatch and help menu
* Replace nested-if version parser with a data-driven lookup table.
* limit support for umount_for_zygote_iso_service to v1.5.9-v2.0.0
* reduce requirement for try_umount_for_zygote_iso_service down to susfs v1.5.9
* skip v2.0.0 sus_path layout check if it's on susfs v2.1.0+
* implement add_sus_memfd exclusive feature, port from v1.3.8 susfs (experimental)
    * This is only for custom kernels with modified susfs patches, such as [this one](https://github.com/sidex15/android_kernel_lge_sm8150/commit/bc23096b9df4d76c43bfea9e217978ecc93b94d4)

### Dev Note
Sorry for the very late update. I'm currently under thesis this year. Apologies for the very slow update 😔. I hope you understand 😊