# TODO

- [ ] **QMI8658 IMU — NOT yet verified on real hardware.**
  The driver (`drivers/iio/imu/qmi8658.c` in the kernel) and the DTS wiring
  (I2C3 @ `0x6b`, `i2c3m1` = GPIO0_C6/C7, 400 kHz) build cleanly and the driver
  binds, **but the bring-up board did not have the QMI8658 fitted** — `i2cdetect`
  on I2C3 shows the ADS1015 @ `0x48` but nothing at `0x6b`, and dmesg shows
  `qmi8658 3-006b: Failed to initialize` (no I2C ACK).
  To finish this, on a board that actually has the IMU populated:
  - confirm the address (SDO/SA0 high = `0x6b`, low = `0x6a`) and that CSB = 3.3V (I2C mode)
  - `i2cdetect -y -r 3` should then show `6a`/`6b`
  - verify the hrtimer 200 Hz buffered-capture path (`buffer0/`, `/dev/iio:deviceN`)
  - older board revisions may need their own DTB / address (selected by the
    board-version SARADC resistor)
