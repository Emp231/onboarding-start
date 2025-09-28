# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb.triggers import FallingEdge
from cocotb.triggers import ClockCycles
from cocotb.types import Logic
from cocotb.types import LogicArray

async def await_half_sclk(dut):
    """Wait for the SCLK signal to go high or low."""
    start_time = cocotb.utils.get_sim_time(units="ns")
    while True:
        await ClockCycles(dut.clk, 1)
        # Wait for half of the SCLK period (10 us)
        if (start_time + 100*100*0.5) < cocotb.utils.get_sim_time(units="ns"):
            break
    return

def ui_in_logicarray(ncs, bit, sclk):
    """Setup the ui_in value as a LogicArray."""
    return LogicArray(f"00000{ncs}{bit}{sclk}")

async def send_spi_transaction(dut, r_w, address, data):
    """
    Send an SPI transaction with format:
    - 1 bit for Read/Write
    - 7 bits for address
    - 8 bits for data
    
    Parameters:
    - r_w: boolean, True for write, False for read
    - address: int, 7-bit address (0-127)
    - data: LogicArray or int, 8-bit data
    """
    # Convert data to int if it's a LogicArray
    if isinstance(data, LogicArray):
        data_int = int(data)
    else:
        data_int = data
    # Validate inputs
    if address < 0 or address > 127:
        raise ValueError("Address must be 7-bit (0-127)")
    if data_int < 0 or data_int > 255:
        raise ValueError("Data must be 8-bit (0-255)")
    # Combine RW and address into first byte
    first_byte = (int(r_w) << 7) | address
    # Start transaction - pull CS low
    sclk = 0
    ncs = 0
    bit = 0
    # Set initial state with CS low
    dut.ui_in.value = ui_in_logicarray(ncs, bit, sclk)
    await ClockCycles(dut.clk, 1)
    # Send first byte (RW + Address)
    for i in range(8):
        bit = (first_byte >> (7-i)) & 0x1
        # SCLK low, set COPI
        sclk = 0
        dut.ui_in.value = ui_in_logicarray(ncs, bit, sclk)
        await await_half_sclk(dut)
        # SCLK high, keep COPI
        sclk = 1
        dut.ui_in.value = ui_in_logicarray(ncs, bit, sclk)
        await await_half_sclk(dut)
    # Send second byte (Data)
    for i in range(8):
        bit = (data_int >> (7-i)) & 0x1
        # SCLK low, set COPI
        sclk = 0
        dut.ui_in.value = ui_in_logicarray(ncs, bit, sclk)
        await await_half_sclk(dut)
        # SCLK high, keep COPI
        sclk = 1
        dut.ui_in.value = ui_in_logicarray(ncs, bit, sclk)
        await await_half_sclk(dut)
    # End transaction - return CS high
    sclk = 0
    ncs = 1
    bit = 0
    dut.ui_in.value = ui_in_logicarray(ncs, bit, sclk)
    await ClockCycles(dut.clk, 600)
    return ui_in_logicarray(ncs, bit, sclk)

@cocotb.test()
async def test_spi(dut):
    dut._log.info("Start SPI test")

    # Set the clock period to 100 ns (10 MHz)
    clock = Clock(dut.clk, 100, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    ncs = 1
    bit = 0
    sclk = 0
    dut.ui_in.value = ui_in_logicarray(ncs, bit, sclk)
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

    dut._log.info("Test project behavior")
    dut._log.info("Write transaction, address 0x00, data 0xF0")
    ui_in_val = await send_spi_transaction(dut, 1, 0x00, 0xF0)  # Write transaction
    assert dut.uo_out.value == 0xF0, f"Expected 0xF0, got {dut.uo_out.value}"
    await ClockCycles(dut.clk, 1000) 

    dut._log.info("Write transaction, address 0x01, data 0xCC")
    ui_in_val = await send_spi_transaction(dut, 1, 0x01, 0xCC)  # Write transaction
    assert dut.uio_out.value == 0xCC, f"Expected 0xCC, got {dut.uio_out.value}"
    await ClockCycles(dut.clk, 100)

    dut._log.info("Write transaction, address 0x30 (invalid), data 0xAA")
    ui_in_val = await send_spi_transaction(dut, 1, 0x30, 0xAA)
    await ClockCycles(dut.clk, 100)

    dut._log.info("Read transaction (invalid), address 0x00, data 0xBE")
    ui_in_val = await send_spi_transaction(dut, 0, 0x30, 0xBE)
    assert dut.uo_out.value == 0xF0, f"Expected 0xF0, got {dut.uo_out.value}"
    await ClockCycles(dut.clk, 100)
    
    dut._log.info("Read transaction (invalid), address 0x41 (invalid), data 0xEF")
    ui_in_val = await send_spi_transaction(dut, 0, 0x41, 0xEF)
    await ClockCycles(dut.clk, 100)

    dut._log.info("Write transaction, address 0x02, data 0xFF")
    ui_in_val = await send_spi_transaction(dut, 1, 0x02, 0xFF)  # Write transaction
    await ClockCycles(dut.clk, 100)

    dut._log.info("Write transaction, address 0x04, data 0xCF")
    ui_in_val = await send_spi_transaction(dut, 1, 0x04, 0xCF)  # Write transaction
    await ClockCycles(dut.clk, 30000)

    dut._log.info("Write transaction, address 0x04, data 0xFF")
    ui_in_val = await send_spi_transaction(dut, 1, 0x04, 0xFF)  # Write transaction
    await ClockCycles(dut.clk, 30000)

    dut._log.info("Write transaction, address 0x04, data 0x00")
    ui_in_val = await send_spi_transaction(dut, 1, 0x04, 0x00)  # Write transaction
    await ClockCycles(dut.clk, 30000)

    dut._log.info("Write transaction, address 0x04, data 0x01")
    ui_in_val = await send_spi_transaction(dut, 1, 0x04, 0x01)  # Write transaction
    await ClockCycles(dut.clk, 30000)

    dut._log.info("SPI test completed successfully")

"""
async def edge_bit0(dut, val, timeout_ns=1_000_000):
    start = cocotb.utils.get_sim_time(units="ns")
    bit_val = dut.uo_out.value[0]
    while True:
        await RisingEdge(dut.clk)
        current = dut.uo_out.value[0] 

        if val == 1 and bit_val == 0 and current == 1:
            return cocotb.utils.get_sim_time(units="ns")
        if val == 0 and bit_val == 1 and current == 0:
            return cocotb.utils.get_sim_time(units="ns")
        
        if cocotb.utils.get_sim_time(units="ns") - start > timeout_ns:
            raise TimeoutError("Timeout waiting")
        
        bit_val = current
"""

@cocotb.test()
async def test_pwm_freq(dut):
    # Write your test here

    clock = Clock(dut.clk, 100, units="ns")
    cocotb.start_soon(clock.start())

    dut.ena.value = 1
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

    await send_spi_transaction(dut, 1, 0x00, 0x01)
    await send_spi_transaction(dut, 1, 0x02, 0x01)
    await send_spi_transaction(dut, 1, 0x04, 0x80)

    await ClockCycles(dut.clk, 1000)

    #t1 = await edge_bit0(dut, 1, timeout_ns=100_000_000)
    #t2 = await edge_bit0(dut, 1, timeout_ns=100_000_000)

    await RisingEdge(dut.uo_out_bit0)
    t1 = cocotb.utils.get_sim_time(units="ns")
    await RisingEdge(dut.uo_out_bit0)
    t2 = cocotb.utils.get_sim_time(units="ns")

    time_elapsed = t2 - t1
    freq = 1e9 / time_elapsed

    dut._log.info(f"Measured PWM frequency: {freq:.2f} Hz")
    assert 2970 < freq < 3030, f"Frequency out of range: {freq:.2f} Hz"

    dut._log.info("PWM Frequency test completed successfully")


@cocotb.test()
async def test_pwm_duty(dut):
    # Write your test here
    clock = Clock(dut.clk, 100, units="ns")
    cocotb.start_soon(clock.start())

    dut.ena.value = 1
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

    await send_spi_transaction(dut, 1, 0x00, 0x01)
    await send_spi_transaction(dut, 1, 0x02, 0x01)

    #t1 = await edge_bit0(dut, 1, timeout_ns=100_000_000)
    #t2 = await edge_bit0(dut, 0, timeout_ns=100_000_000)
    #t3 = await edge_bit0(dut, 1, timeout_ns=100_000_000)

    async def checking(value, expected):
        await send_spi_transaction(dut, 1, 0x04, value)
        await ClockCycles(dut.clk, 5000)

        if value == 0x00:
            duty = 0.0
        elif value == 0xFF:
            duty = 100.0
        else:
            await RisingEdge(dut.uo_out_bit0)
            t1 = cocotb.utils.get_sim_time("ns")
            await FallingEdge(dut.uo_out_bit0)
            t2 = cocotb.utils.get_sim_time('ns')
            await RisingEdge(dut.uo_out_bit0)
            t3 = cocotb.utils.get_sim_time('ns')

            time_elapsed = t3 - t1
            high = t2 - t1
            duty = high / time_elapsed

            dut._log.info(f"duty={duty:.1f}% for reg={value:#04x}")

        assert abs(duty - expected) <= 5, \
            f"Expected duty ~{expected}%, got {duty}%"

    """
    #0%
    await send_spi_transaction(dut, 1, 0x04, 0x00)
    try:
        await edge_bit0(dut, 1, timeout_ns=200_000)
        assert False, "Error"
    except Exception as e:
        pass
    assert int(dut.uo_out.value) & 0x1 == 0, "Expected always low at 0% duty"

    #100%
    await send_spi_transaction(dut, 1, 0x04, 0xFF)
    try:
        await edge_bit0(dut, 0, timeout_ns=200_000)
        assert False, "Unexpected falling edge detected at 100% duty"
    except Exception as e:
        pass
    assert int(dut.uo_out.value) & 0x1 == 1, "Expected always high at 100% duty"
    """

    await checking(0x00, 0.0)     
    await checking(0x80, 50.0)    
    await checking(0xFF, 100.0)   
    dut._log.info("PWM Duty Cycle test completed successfully")
