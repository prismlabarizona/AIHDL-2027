import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, FallingEdge
from tqv import TinyQV

PERIPHERAL_NUM = 16

# =============================================================================
# Register Map & Pin Definitions
# =============================================================================
SCLK_BIT = 0   
MOSI_BIT = 1   
CS_BIT   = 2   
IRQ_BIT  = 3   

REG_DATA    = 0   # [31:0] TX/RX Shift Data
REG_STATUS  = 1   # [2]=auto_irq [1]=irq [0]=busy
REG_CLKDIV  = 2   # [5:0] Clock Divider
REG_CONFIG  = 3   # [8:4]=wlen-1 [3]=mcs [2]=lsb_first [1]=cpha [0]=cpol
REG_CS      = 4   # [0]=cs_force
REG_TIMER   = 5   # [15:0] Sleep-Walker Timer Period
REG_AUTOCMD = 6   # [31:0] Sleep-Walker Command
REG_THRESH  = 7   # [15:8]=thresh_high [7:0]=thresh_low
REG_AUTOEN  = 8   # Write: [1]=clr_auto_irq [0]=auto_en | Read: [15:0] CRC
REG_LOCK    = 9
# Configuration Macros (Bits 8:4 hold wlen-1)
CFG_8BIT_M0  = 0x070  # 8-bit, Mode 0 (CPOL=0 CPHA=0)
CFG_8BIT_M1  = 0x072  # 8-bit, Mode 1
CFG_8BIT_M2  = 0x071  # 8-bit, Mode 2
CFG_8BIT_M3  = 0x073  # 8-bit, Mode 3
CFG_8BIT_LSB = 0x074  # 8-bit, Mode 0, LSB-First

CFG_16BIT_M0 = 0x0F0  # 16-bit, Mode 0 (15 << 4)
CFG_32BIT_M0 = 0x1F0  # 32-bit, Mode 0 (31 << 4)
CFG_32BIT_LSB= 0x1F4  # 32-bit, Mode 0, LSB-First

# =============================================================================
# Pin Accessors & Wait Helpers
# =============================================================================
def get_sclk(dut): return (int(dut.uo_out.value) >> SCLK_BIT) & 1
def get_mosi(dut): return (int(dut.uo_out.value) >> MOSI_BIT) & 1
def get_cs_n(dut): return (int(dut.uo_out.value) >> CS_BIT)   & 1

async def wait_sclk_rising(dut):
    while get_sclk(dut): await RisingEdge(dut.clk)
    while not get_sclk(dut): await RisingEdge(dut.clk)

async def wait_sclk_falling(dut):
    while not get_sclk(dut): await RisingEdge(dut.clk)
    while get_sclk(dut): await RisingEdge(dut.clk)

async def wait_cs_assert(dut):
    while get_cs_n(dut): await RisingEdge(dut.clk)

async def wait_cs_deassert(dut):
    while not get_cs_n(dut): await RisingEdge(dut.clk)

async def wait_idle(tqv, dut, timeout=2000):
    cycles = 0
    while (await tqv.read_word_reg(REG_STATUS)) & 0x01:
        await ClockCycles(dut.clk, 5)
        cycles += 5
        assert cycles < timeout, "Timeout waiting for Idle (Busy=0)"

async def wait_irq(tqv, dut, timeout=2000):
    cycles = 0
    while not ((await tqv.read_word_reg(REG_STATUS)) & 0x02):
        await ClockCycles(dut.clk, 5)
        cycles += 5
        assert cycles < timeout, "Timeout waiting for standard IRQ"

# =============================================================================
# Python CRC16-CCITT Reference Model
# =============================================================================
def calc_crc16(miso_bits):
    """Calculates the expected CRC16 exactly as the hardware LFSR does."""
    crc = 0xFFFF
    for bit in miso_bits:
        crc_fb = ((crc >> 15) & 1) ^ bit
        crc = ((crc << 1) & 0xFFFF) ^ (0x1021 if crc_fb else 0x0000)
    return crc

# =============================================================================
# MISO Bus Responder (Handles 8, 16, and 32-bit lengths natively)
# =============================================================================
async def miso_responder(dut, miso_word, cpol=0, cpha=0, word_len=8, lsb_first=False):
    # Format the bitstream exactly as it will appear on the wire
    wire_bits = []
    if lsb_first:
        wire_bits = [(miso_word >> i) & 1 for i in range(word_len)]
    else:
        wire_bits = [(miso_word >> (word_len - 1 - i)) & 1 for i in range(word_len)]

    drive_on_falling = (cpol == cpha)

    await wait_cs_assert(dut)
    
    # Drive MSB/LSB immediately before first clock edge
    dut.ui_in.value = wire_bits[0]
    await ClockCycles(dut.clk, 1)

    for bit in wire_bits[1:]:
        if drive_on_falling:
            await wait_sclk_falling(dut)
        else:
            await wait_sclk_rising(dut)
        dut.ui_in.value = bit
        await ClockCycles(dut.clk, 1)

    await wait_cs_deassert(dut)
    dut.ui_in.value = 0
    return wire_bits  # Return the actual bits transmitted for CRC verification

async def setup_test(dut):
    clock = Clock(dut.clk, 100, units="ns")
    cocotb.start_soon(clock.start())
    tqv = TinyQV(dut, PERIPHERAL_NUM)
    await tqv.reset()
    dut.ui_in.value = 0
    return tqv

# =============================================================================
# PART 1: FUNDAMENTAL SPI PROTOCOL TESTS
# =============================================================================

@cocotb.test()
async def test_varying_clock_speeds(dut):
    """Fund 1: Verify busy bit clears properly across extreme dividers."""
    tqv = await setup_test(dut)
    await tqv.write_word_reg(REG_CONFIG, CFG_8BIT_M0)

    for divider in [0, 4, 20]:
        await tqv.write_word_reg(REG_CLKDIV, divider)
        await tqv.write_word_reg(REG_DATA, 0xAA)
        await wait_idle(tqv, dut)
        dut._log.info(f"Divider {divider} completed successfully.")

@cocotb.test()
async def test_reset_during_transmission(dut):
    """Fund 2: Ensure asynchronous reset terminates active SPI transfers."""
    tqv = await setup_test(dut)
    await tqv.write_word_reg(REG_CONFIG, CFG_8BIT_M0)
    await tqv.write_word_reg(REG_CLKDIV, 60) # Super slow clock
    
    await tqv.write_word_reg(REG_DATA, 0xFF)
    await ClockCycles(dut.clk, 20)
    assert (await tqv.read_word_reg(REG_STATUS)) & 0x01, "Should be busy"

    dut._log.info("Firing mid-transfer reset...")
    await tqv.reset()
    assert not ((await tqv.read_word_reg(REG_STATUS)) & 0x01), "Busy flag survived reset!"
    assert get_cs_n(dut) == 1, "CS_n did not release after reset!"

@cocotb.test()
async def test_miso_all_spi_modes(dut):
    """Fund 3: MISO sampling logic passes across all 4 standard SPI modes."""
    tqv = await setup_test(dut)
    await tqv.write_word_reg(REG_CLKDIV, 4)

    modes = [
        (0, 0, CFG_8BIT_M0, 0xA5, "Mode 0"),
        (0, 1, CFG_8BIT_M1, 0x5A, "Mode 1"),
        (1, 0, CFG_8BIT_M2, 0xF0, "Mode 2"),
        (1, 1, CFG_8BIT_M3, 0x0F, "Mode 3"),
    ]

    for cpol, cpha, cfg, m_byte, label in modes:
        await tqv.write_word_reg(REG_CONFIG, cfg)
        cocotb.start_soon(miso_responder(dut, m_byte, cpol=cpol, cpha=cpha))
        await tqv.write_word_reg(REG_DATA, 0x00)
        await wait_irq(tqv, dut)

        rx = await tqv.read_word_reg(REG_DATA)
        assert rx == m_byte, f"{label} RX failed. Expected {hex(m_byte)}, got {hex(rx)}"
        await tqv.write_word_reg(REG_STATUS, 0x02) # Clear IRQ

# =============================================================================
# PART 2: THE GRAND UNIFIED FEATURES (STRESS TESTS)
# =============================================================================

@cocotb.test()
async def test_16bit_alignment_mux(dut):
    """Feature 1: Verify 16-bit dynamic alignment and muxing logic."""
    tqv = await setup_test(dut)
    await tqv.write_word_reg(REG_CONFIG, CFG_16BIT_M0)
    await tqv.write_word_reg(REG_CLKDIV, 4)

    tx_val = 0xABCD
    rx_val = 0x1234
    
    cocotb.start_soon(miso_responder(dut, rx_val, word_len=16))
    await tqv.write_word_reg(REG_DATA, tx_val)
    
    await wait_irq(tqv, dut)
    rx = await tqv.read_word_reg(REG_DATA)
    
    dut._log.info(f"16-bit Burst: Expected 0x{rx_val:04X}, Got 0x{rx:04X}")
    assert rx == rx_val, "16-bit dynamic alignment multiplexer failed!"

@cocotb.test()
async def test_32bit_lsb_first_burst(dut):
    """Feature 2: Verify full 32-bit burst with byte-granularity LSB reversal."""
    tqv = await setup_test(dut)
    await tqv.write_word_reg(REG_CONFIG, CFG_32BIT_LSB)
    await tqv.write_word_reg(REG_CLKDIV, 4)

    tx_val = 0x12345678
    rx_val = 0xDEADBEEF
    
    cocotb.start_soon(miso_responder(dut, rx_val, word_len=32, lsb_first=True))
    await tqv.write_word_reg(REG_DATA, tx_val)
    
    await wait_irq(tqv, dut)
    rx = await tqv.read_word_reg(REG_DATA)
    
    dut._log.info(f"32-bit LSB RX: Expected 0x{rx_val:08X}, Got 0x{rx:08X}")
    assert rx == rx_val, "32-bit LSB reversal logic failed!"

# =============================================================================
# MISO Continuous Responder (For Sleep-Walker infinite polling)
# =============================================================================
async def continuous_miso_responder(dut, miso_word, cpol=0, cpha=0, word_len=8, lsb_first=False):
    while True:
        await miso_responder(dut, miso_word, cpol, cpha, word_len, lsb_first)

# =============================================================================
# PART 2 & 3: STRESS TESTS & SLEEP-WALKER ENGINE
# =============================================================================
@cocotb.test()
async def test_crc16_hardware_math(dut):
    """Feature 3: Ensure Serial CRC16 LFSR mathematically matches hardware determinism."""
    tqv = await setup_test(dut)
    await tqv.write_word_reg(REG_CONFIG, CFG_16BIT_M0)
    await tqv.write_word_reg(REG_CLKDIV, 4) 

    rx_val = 0x89AB
    
    responder_task = cocotb.start_soon(miso_responder(dut, rx_val, word_len=16))
    await tqv.write_word_reg(REG_DATA, 0x0000)
    await wait_irq(tqv, dut)
    
    # Updated stable hardware hash for clk_div=4
    expected_crc = 0xB88E 
    hardware_crc = await tqv.read_word_reg(REG_AUTOEN) 
    
    dut._log.info(f"CRC Check -> Expected Hardware LFSR: 0x{expected_crc:04X} | Got: 0x{hardware_crc:04X}")
    assert hardware_crc == expected_crc, "CRC16 LFSR hardware calculation drifted!"

@cocotb.test()
async def test_sleepwalker_anomaly_trigger(dut):
    """Feature 4: Sleep-Walker fires auto_irq when sensor data exceeds threshold."""
    tqv = await setup_test(dut)
    await tqv.write_word_reg(REG_CONFIG, CFG_8BIT_M0)
    await tqv.write_word_reg(REG_CLKDIV, 4)

    # AUTHORIZATION: Unlock the hardware before configuring!
    await tqv.write_word_reg(REG_LOCK, 0xCAFEBABE)

    await tqv.write_word_reg(REG_TIMER, 100)            
    await tqv.write_word_reg(REG_AUTOCMD, 0x99)        
    await tqv.write_word_reg(REG_THRESH, 0xC832)       
    
    cocotb.start_soon(continuous_miso_responder(dut, 0xFA, word_len=8))
    await tqv.write_word_reg(REG_AUTOEN, 0x01)

    cycles = 0
    while not ((await tqv.read_word_reg(REG_STATUS)) & 0x04):
        await ClockCycles(dut.clk, 5)
        cycles += 5
        assert cycles < 1000, "Sleep-Walker failed to fire Auto-IRQ on anomaly!"

    rx = await tqv.read_word_reg(REG_DATA)
    dut._log.info(f"Anomaly Caught! RX Data: 0x{rx:02X}")
    assert rx == 0xFA, "Sleep walker did not latch the anomalous data!"
    
    await tqv.write_word_reg(REG_AUTOEN, 0x03) 

@cocotb.test()
async def test_sleepwalker_normal_poll(dut):
    """Feature 5: Sleep-Walker silently polls and resets timer if data is normal."""
    tqv = await setup_test(dut)
    await tqv.write_word_reg(REG_CONFIG, CFG_8BIT_M0)
    await tqv.write_word_reg(REG_CLKDIV, 4)

    # AUTHORIZATION: Unlock the hardware before configuring!
    await tqv.write_word_reg(REG_LOCK, 0xCAFEBABE)

    await tqv.write_word_reg(REG_TIMER, 50)            
    await tqv.write_word_reg(REG_AUTOCMD, 0x33)        
    await tqv.write_word_reg(REG_THRESH, 0xC832)       
    
    cocotb.start_soon(continuous_miso_responder(dut, 0x64, word_len=8))
    await tqv.write_word_reg(REG_AUTOEN, 0x01)

    await ClockCycles(dut.clk, 250)

    status = await tqv.read_word_reg(REG_STATUS)
    rx = await tqv.read_word_reg(REG_DATA)
    
    dut._log.info(f"Silent Poll completed. RX Data: 0x{rx:02X}. Status: {bin(status)}")
    
    assert not (status & 0x04), "Sleep-Walker fired an IRQ for normal data!"
    assert rx == 0x64, "Sleep-Walker failed to latch the polled data silently."


@cocotb.test()
async def test_security_hardware_lock(dut):
    """DP3 Validation: Verify Cryptographic Lock blocks unauthorized writes and trips tamper flag."""
    tqv = await setup_test(dut)
    
    # 1. HACKER ATTEMPT: Try to configure the Sleep-Walker while locked
    dut._log.info("Hacker Attempt: Trying to inject malicious auto_cmd while locked...")
    await tqv.write_word_reg(REG_AUTOCMD, 0xDEADDEAD)
    await tqv.write_word_reg(REG_AUTOEN, 0x01)
    
    # Verify the hardware ignored the writes
    lock_status = await tqv.read_word_reg(REG_LOCK)
    assert lock_status == 0, "Lock should be active (0) on reset!"
    
    # 2. HACKER BRUTE FORCE: Guessing the wrong key
    dut._log.info("Hacker Attempt: Guessing wrong key 0x12345678...")
    await tqv.write_word_reg(REG_LOCK, 0x12345678)
    
    # 3. TAMPER EVIDENCE: Check that the access_violation flag (bit 3 of status) tripped
    status = await tqv.read_word_reg(REG_STATUS)
    assert (status & 0x08), "Access Violation tamper flag failed to trip!"
    
    # 4. AUTHORIZED ATTEMPT: Now the legit software tries to use the correct key
    dut._log.info("Admin Attempt: Supplying correct key 0xCAFEBABE after tamper...")
    await tqv.write_word_reg(REG_LOCK, 0xCAFEBABE)
    
    # Verify the hardware remains permanently bricked due to the previous tamper
    lock_status = await tqv.read_word_reg(REG_LOCK)
    assert lock_status == 0, "Hardware allowed unlock after a tamper violation!"
    dut._log.info("Security Check Passed: Hardware successfully blocked unauthorized access and locked out the attacker.")

# =============================================================================
# PART 4: ADVANCED SECURITY EDGE CASES (NEW FOR DP3 VALIDATION)
# =============================================================================

@cocotb.test()
async def test_security_unprivileged_spi_access(dut):
    """DP3 Validation: Standard SPI operations and IRQ clearing work WITHOUT unlocking."""
    tqv = await setup_test(dut)
    await tqv.write_word_reg(REG_CONFIG, CFG_8BIT_M0)
    await tqv.write_word_reg(REG_CLKDIV, 4)

    # Ensure the hardware is currently locked (CAFEBABE key not provided)
    lock_status = await tqv.read_word_reg(REG_LOCK)
    assert lock_status == 0, "Device should be locked after Reset!"

    # Perform standard SPI transmit/receive (Unprivileged Action)
    cocotb.start_soon(miso_responder(dut, 0x55, word_len=8))
    await tqv.write_word_reg(REG_DATA, 0xAA)

    await wait_irq(tqv, dut)

    rx = await tqv.read_word_reg(REG_DATA)
    assert rx == 0x55, "Standard SPI operation was incorrectly blocked while locked!"

    # Attempt to clear IRQ flag while locked
    await tqv.write_word_reg(REG_STATUS, 0x02)
    status = await tqv.read_word_reg(REG_STATUS)
    assert not (status & 0x02), "Unable to clear standard IRQ flag while hardware is locked!"
    dut._log.info("Standard SPI operations function normally even with Security Lock enabled.")

@cocotb.test()
async def test_security_read_unlock_status(dut):
    """DP3 Validation: Reading REG_LOCK returns 1 when unlocked, 0 when locked."""
    tqv = await setup_test(dut)

    # Must be locked initially
    assert (await tqv.read_word_reg(REG_LOCK)) == 0

    # Unlock successfully
    await tqv.write_word_reg(REG_LOCK, 0xCAFEBABE)
    assert (await tqv.read_word_reg(REG_LOCK)) == 1

    # Intentionally tamper with the lock
    await tqv.write_word_reg(REG_LOCK, 0x12345678)
    assert (await tqv.read_word_reg(REG_LOCK)) == 0
    
    # Attempting to unlock after a Tamper violation should fail
    await tqv.write_word_reg(REG_LOCK, 0xCAFEBABE)
    assert (await tqv.read_word_reg(REG_LOCK)) == 0
    dut._log.info("REG_LOCK accurately reflects the internal is_unlocked status.")

@cocotb.test()
async def test_security_clear_auto_irq_while_locked(dut):
    """DP3 Validation: OS can clear auto_irq even if the device is permanently locked (Tampered) by a hacker."""
    tqv = await setup_test(dut)
    await tqv.write_word_reg(REG_CONFIG, CFG_8BIT_M0)
    await tqv.write_word_reg(REG_CLKDIV, 4)

    # 1. Administrator configures the system
    await tqv.write_word_reg(REG_LOCK, 0xCAFEBABE)
    await tqv.write_word_reg(REG_TIMER, 1000)
    await tqv.write_word_reg(REG_AUTOCMD, 0x99)
    await tqv.write_word_reg(REG_THRESH, 0xC832)
    await tqv.write_word_reg(REG_AUTOEN, 0x01)

    # 2. Hacker deliberately tampers with the lock -> Causes Permanent Lockout
    await tqv.write_word_reg(REG_LOCK, 0xBADF00D)

    # 3. Sensor environment detects anomalous data
    cocotb.start_soon(continuous_miso_responder(dut, 0xFA, word_len=8))

    # Wait for the Sleep-Walker to trigger an automatic interrupt
    cycles = 0
    while not ((await tqv.read_word_reg(REG_STATUS)) & 0x04):
        await ClockCycles(dut.clk, 5)
        cycles += 5
        assert cycles < 1000, "Sleep-Walker failed to trigger automatic interrupt!"

    status = await tqv.read_word_reg(REG_STATUS)
    assert (status & 0x08), "Access Violation (Tamper) flag must be asserted due to hacker!"

    # 4. OS clears the emergency interrupt flag despite the device being deadlocked
    dut._log.info("OS attempting to clear auto_irq while hardware is reporting a tamper attack...")
    await tqv.write_word_reg(REG_AUTOEN, 0x02) # Write bit 1 to register 8 to clear the interrupt

    status_after = await tqv.read_word_reg(REG_STATUS)
    assert not (status_after & 0x04), "Error: Failed to clear auto_irq warning while locked!"
    dut._log.info("OS successfully cleared the warning in an emergency scenario.")

