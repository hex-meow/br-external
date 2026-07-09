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

## P3b:hex-hw-supervisor 真机驱动(等最终版 PCB / 设备树,2026-07-09 记)
当前 PCB 非最终版,DT 与量产版不一致 → 真驱动全部延后;mock 面已完整(imu/estop/remote/vbus,
可在 x64 上做消费端集成测试)。届时在 hex-hw-supervisor 仓逐个实现并替换 board.yaml 的 driver 字段:
- [ ] imu: qmi8658(板载 I2C,上文 IIO 验证事项与此合并)
- [ ] estop: GPIO 输入(去抖)
- [ ] remote: evdev 手柄(纯 Rust,禁 gilrs/libinput——硬依赖 libudev)/ SBUS(serialport
      no-default-features + termios2,100000 8E2 上机冒烟 = 测试门 T6)
- [ ] vbus: ADC(IIO)
- [ ] 总线电源:内核态保持机制(测试门 T5,DT 定默认态)+ supervisor unixsock 通道(09 §6)
