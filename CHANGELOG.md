# Changelog

## v0.1.0 (unreleased)

Initial development system for the Samsung Galaxy Express SGH-I437 (MSM8960).

* Linux 7.2.9 with the board kernel patches, nerves_system_br 1.35.3 and the
  armv7 Nerves toolchain 15.3.0.
* Nested USERDATA A/B layout, initramfs device mappings and native fwup
  upgrade, validation and revert operations.
* Device-specific WCNSS firmware and calibration stay local; only source is
  published.
