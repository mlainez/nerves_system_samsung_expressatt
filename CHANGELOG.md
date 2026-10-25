# Changelog

## v0.1.0 (unreleased)

Initial development system for the Samsung Galaxy Express SGH-I437 (MSM8960).

* Linux 7.2.9 with the board kernel patches, nerves_system_br 1.35.3 and the
  armv7 Nerves toolchain 15.3.0.
* Nested USERDATA A/B layout, initramfs device mappings and native fwup
  upgrade, validation and revert operations.
* WCNSS firmware and NV calibration are read from the phone's own stock
  `system` and `persist` partitions at boot; nothing proprietary is shipped.
* Prebuilt system artifacts are published on GitHub releases.
