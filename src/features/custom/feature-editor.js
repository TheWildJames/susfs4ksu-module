import { toast } from 'kernelsu';
import { gsap } from 'gsap';
import { run, versionAtLeast, haveSusfsCommand } from '../../utils.js';
import { config, moddir } from '../../core/constants.js';

// Collapse a per-line (or comma separated) app list into the single comma
// separated argument the *_uid_filter subcommands expect.
function joinAppList(value) {
	return value
		.split(/[\n,]/)
		.map((entry) => entry.trim())
		.filter((entry) => entry && !entry.startsWith('#'))
		.join(',');
}

// Unified custom text editor (sus_path, sus_path_loop, sus_maps, sus_mount,
// try_umount, open_redirect, priority_uid_filter, sus_path_uid_filter)
export function getCustomEditorFeatures(susfs_features, susfs_versions, probe = {}) {
	const features = [];

	if (susfs_features.includes("CONFIG_KSU_SUSFS_SUS_PATH")) {
		features.push({
			value: "SUS_PATH",
			valueKey: "sus_path_label",
			labelKey: "custom_sus_path_label",
			filePath: `${config}/sus_path.txt`,
			featureName: "SUS_PATH",
		});
	}

	if (versionAtLeast(susfs_versions, 1, 5, 9)) {
		features.push({
			value: "SUS_PATH_LOOP",
			valueKey: "sus_path_loop_label",
			labelKey: "custom_sus_path_loop_label",
			filePath: `${config}/sus_path_loop.txt`,
			featureName: "SUS_PATH_LOOP",
		});
	}

	if (susfs_features.includes("CONFIG_KSU_SUSFS_SUS_MAP")) {
		features.push({
			value: "SUS_MAPS",
			valueKey: "sus_map_label",
			labelKey: "custom_sus_maps_label",
			filePath: `${config}/sus_maps.txt`,
			featureName: "SUS_MAPS",
		});
	}

	if (susfs_features.includes("CONFIG_KSU_SUSFS_SUS_MOUNT") && !versionAtLeast(susfs_versions, 2, 0, 0)) {
		features.push({
			value: "SUS_MOUNT",
			valueKey: "sus_mount_label",
			labelKey: "custom_sus_mount_label",
			filePath: `${config}/sus_mount.txt`,
			featureName: "SUS_MOUNT",
		});
	}

	if (susfs_features.includes("CONFIG_KSU_SUSFS_TRY_UMOUNT") || versionAtLeast(susfs_versions, 2, 0, 0)) {
		features.push({
			value: "TRY_UMOUNT",
			valueKey: "try_umount_label",
			labelKey: "custom_try_umount_label",
			filePath: `${config}/try_umount.txt`,
			featureName: "TRY_UMOUNT",
		});
	}

	if (susfs_features.includes("CONFIG_KSU_SUSFS_OPEN_REDIRECT")) {
		features.push({
			value: "SUS_OPEN_REDIRECT",
			valueKey: "sus_open_redirect_label",
			labelKey: "custom_sus_open_redirect_label",
			filePath: `${config}/sus_open_redirect.txt`,
			featureName: "SUS_OPEN_REDIRECT",
		});
	}

	// App uids hidden from getpriority/setpriority/ioprio probing (susfs v2.4.0+).
	// Exclusive with the "Hide All App UIDs" toggle: while that is on, the kernel
	// gets every installed app and this list is not read at all.
	if (susfs_features.includes("CONFIG_KSU_SUSFS_PRIORITY_UID_FILTER")) {
		features.push({
			value: "PRIORITY_UID_FILTER",
			valueKey: "priority_uid_filter_label",
			labelKey: "custom_priority_uid_filter_label",
			filePath: `${config}/priority_uid_filter.txt`,
			featureName: "PRIORITY_UID_FILTER",
			disabled: probe.priorityAllApps === true,
			ignoredNoteKey: "priority_uid_filter_ignored_note",
			applyCmd: () => `sh ${moddir}/apply_uid_filters.sh`,
		});
	}

	// Apps still allowed to see the sus paths (kernel tree after v2.4.0, so the
	// feature has no CONFIG_* string and is probed on the binary instead)
	if (probe.susPathUidFilter) {
		features.push({
			value: "SUS_PATH_UID_FILTER",
			valueKey: "sus_path_uid_filter_label",
			labelKey: "custom_sus_path_uid_filter_label",
			filePath: `${config}/sus_path_uid_filter.txt`,
			featureName: "SUS_PATH_UID_FILTER",
			applyCmd: () => `sh ${moddir}/apply_uid_filters.sh`,
		});
	}

	return features;
}

export async function custom_feature_editor(susfs_features, susfs_versions, settings = {}) {
	const section = document.getElementById("custom_feature_editor_section");
	if (!section) return;

	// sus_path_uid_filter ships no CONFIG_* string in `show enabled_features`,
	// so ask the binary whether it knows the subcommand.
	const probe = {
		susPathUidFilter: await haveSusfsCommand("set_sus_path_uid_filter"),
		priorityAllApps: Number(settings.priority_uid_filter_all_apps) === 1,
	};

	const featureSelect = document.getElementById("custom_feature_select");
	const featureLabel = document.getElementById("custom_feature_label");
	const loadBtn = document.getElementById("load_custom_feature");
	const editBtn = document.getElementById("edit_custom_feature");
	const saveBtn = document.getElementById("save_custom_feature");
	const textarea = document.getElementById("custom_feature_textarea");
	const mainContainer = document.querySelector('main');

	const availableFeatures = getCustomEditorFeatures(susfs_features, susfs_versions, probe);
	if (availableFeatures.length === 0) {
		section.classList.add("hidden");
		return;
	}

	section.classList.remove("hidden");
	const disabledSuffix = ` (${window.i18n ? window.i18n.getTranslation("disabled_label") : "Disabled"})`;
	featureSelect.innerHTML = availableFeatures
		.map((feature) => {
			const translatedLabel = window.i18n ? window.i18n.getTranslation(feature.valueKey) : feature.featureName;
			const suffix = feature.disabled ? disabledSuffix : "";
			const disabled = feature.disabled ? " disabled" : "";
			return `<option value="${feature.value}" data-i18n="${feature.valueKey}"${disabled}>${translatedLabel}${suffix}</option>`;
		})
		.join("");

	const getSelectedFeature = () => {
		const selectedValue = featureSelect.value;
		return availableFeatures.find((feature) => feature.value === selectedValue) || availableFeatures[0];
	};

	const ignoredNote = (feature) =>
		window.i18n ? window.i18n.getTranslation(feature.ignoredNoteKey || "disabled_label") : "Ignored while Hide All App UIDs is on";

	const bindSelectedFeature = () => {
		const selected = getSelectedFeature();
		featureLabel.setAttribute("data-i18n", selected.labelKey);
		featureLabel.textContent = window.i18n ? window.i18n.getTranslation(selected.labelKey) : selected.featureName;
		if (selected.disabled && selected.ignoredNoteKey) {
			featureLabel.textContent += ` - ${ignoredNote(selected)}`;
		}
		textarea.value = "";

		loadBtn.onclick = async () => {
			const content = await run(`cat ${selected.filePath}`);
			textarea.value = content;
			if (selected.disabled && selected.ignoredNoteKey) toast(ignoredNote(selected));
		};

		saveBtn.onclick = async () => {
			const value = textarea.value;
			if (value === '') {
				toast('please press load first!');
				return;
			}
			await run(`echo '${value}' > ${selected.filePath}`);
			if (selected.disabled && selected.ignoredNoteKey) {
				toast(`Saved, but ${ignoredNote(selected)}`);
				return;
			}
			if (selected.applyCmd) {
				if (!joinAppList(value)) {
					toast(`${selected.featureName} cleared, reboot to apply`);
					return;
				}
				try {
					await run(selected.applyCmd(value));
					toast(`${selected.featureName} saved and applied!`);
				} catch (error) {
					toast(`Saved, apply failed: ${error}`);
				}
				return;
			}
			toast(`Custom ${selected.featureName} saved!`);
			toast("Reboot to take effect");
		};

		editBtn.onclick = async () => {
			await run(`am start -a android.intent.action.VIEW -t text/plain -d file://${selected.filePath}`);
		};
	};

	featureSelect.onchange = bindSelectedFeature;
	bindSelectedFeature();

	textarea.onfocus = () => {
		mainContainer.style.paddingBottom = '300px';
		textarea.scrollIntoView({ behavior: 'smooth', block: 'center', inline: 'nearest' });
	};
	textarea.onblur = () => {
		gsap.to(mainContainer, { duration: 0.5, paddingBottom: '0px', ease: 'power1.out' });
	};
}
