# default voltage for old boards
if test "${board}" = "hexfellow_ctrl_v01";then
    env set board_id_voltage 330000

    adc single saradc@fe720000 3 board_id_voltage

    if test ${board_id_voltage} -ge 300000 && test ${board_id_voltage} -le 370000; then
        env set fpga_bitstream design_1_wrapper
        env set fdt_name rk3568-hexmeow-ctrl-1
    elif test $board_id_voltage -ge 505000 && test $board_id_voltage -le 610000; then
        env set fdt_name rk3568-hexmeow-mini-ctrl-1
    else
        echo "Unknown board ID voltage"
        download
    fi

    if test -n "${fpga_bitstream}"; then
        echo "Loading FPGA bitstream: /boot/${fpga_bitstream}.bit"
        if ext4load ${devtype} ${devnum}:${rootfspart} ${kernel_addr_r} /boot/${fpga_bitstream}.bit; then
            gpio clear gpio022
            sleep 0.1
            gpio set gpio022
            sleep 0.1
            fpga_spi_load 1 ${kernel_addr_r} ${filesize} rk_fast
        else
            echo "Error: Failed to load FPGA bitstream."
        fi
    fi
    part uuid ${devtype} ${devnum}:${rootfspart} rootfsuuid
    setenv bootargs "$bootargs root=PARTUUID=${rootfsuuid} console=ttyFIQ0 earlycon=uart8250,mmio32,0xfe660000 ro rootwait"
fi
if test "${board}" = "evb_rk3576"; then
    env set fdt_name rk3576-hexmeow

    part uuid ${devtype} ${devnum}:${rootfspart} rootfsuuid
    setenv bootargs "$bootargs root=PARTUUID=${rootfsuuid} console=tty0 console=ttyFIQ0 earlycon=uart8250,mmio32,0x2ad40000 ro rootwait"
fi
echo "Board: ${fdt_name}"
load ${devtype} ${devnum}:${rootfspart} ${fdt_addr_r} /boot/rockchip/${fdt_name}.dtb
load ${devtype} ${devnum}:${rootfspart} ${kernel_addr_r} /boot/Image
booti ${kernel_addr_r} - ${fdt_addr_r}
