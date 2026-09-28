# Copyright (c) 2024 Caio Alonso da Costa
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

def get_bit(value, bit_index):
  temp = value & (1 << bit_index)
  return temp

def set_bit(value, bit_index):
  temp = value | (1 << bit_index)
  return temp

def clear_bit(value, bit_index):
  temp = value & ~(1 << bit_index)
  return temp

def xor_bit(value, bit_index):
  temp = value ^ (1 << bit_index)
  return temp

def pull_cs_high(value):
  temp = set_bit(value, 4)
  return temp

def pull_cs_low(value):
  temp = clear_bit(value, 4)
  return temp

def spi_clk_high(value):
  temp = set_bit(value, 5)
  return temp

def spi_clk_low(value):
  temp = clear_bit(value, 5)
  return temp

def spi_clk_invert(value):
  temp = xor_bit(value, 5)
  return temp

def spi_mosi_high(value):
  temp = set_bit(value, 6)
  return temp

def spi_mosi_low(value):
  temp = clear_bit(value, 6)
  return temp

def spi_miso_read(port):
  return (get_bit (port.value, 3) >> 3)

SPI_HALF_CYCLE_DELAY = 2

async def spi_write_cpha0 (clk, port, address, data, width):

  temp = port.value;
  result = pull_cs_high(temp)
  port.value = result
  await ClockCycles(clk, SPI_HALF_CYCLE_DELAY)

  # Pull CS low + Write command bit - bit 31 - MSBIT in first word
  temp = port.value;
  result = pull_cs_low(temp)
  result2 = spi_mosi_high(result)
  port.value = result2
  await ClockCycles(clk, SPI_HALF_CYCLE_DELAY)
  temp = port.value;
  result = spi_clk_invert(temp)
  port.value = result
  await ClockCycles(clk, SPI_HALF_CYCLE_DELAY)

  # Next two bits indicate txn width
  iterator = 1
  while iterator >= 0:
    temp = port.value;
    result = spi_clk_invert(temp)
    address_bit = get_bit(width, iterator)
    if (address_bit == 0):
      result2 = spi_mosi_low(result)
    else:
      result2 = spi_mosi_high(result)
    port.value = result2
    await ClockCycles(clk, SPI_HALF_CYCLE_DELAY)
    temp = port.value;
    result = spi_clk_invert(temp)
    port.value = result
    await ClockCycles(clk, SPI_HALF_CYCLE_DELAY)
    iterator -= 1

  iterator = 0
  while iterator < 23:
    # Don't care - bits 28-6
    temp = port.value;
    result = spi_clk_invert(temp)
    result2 = spi_mosi_low(result)
    port.value = result2
    await ClockCycles(clk, SPI_HALF_CYCLE_DELAY)
    temp = port.value;
    result = spi_clk_invert(temp)
    port.value = result
    await ClockCycles(clk, SPI_HALF_CYCLE_DELAY)
    iterator += 1

  iterator = 5
  while iterator >= 0:
    # Address[iterator] - bits 5-0
    temp = port.value;
    result = spi_clk_invert(temp)
    address_bit = get_bit(address, iterator)
    if (address_bit == 0):
      result2 = spi_mosi_low(result)
    else:
      result2 = spi_mosi_high(result)
    port.value = result2
    await ClockCycles(clk, SPI_HALF_CYCLE_DELAY)
    temp = port.value;
    result = spi_clk_invert(temp)
    port.value = result
    await ClockCycles(clk, SPI_HALF_CYCLE_DELAY)
    iterator -= 1

  iterator = 31
  while iterator >= 0:
    # Data[iterator]
    temp = port.value;
    result = spi_clk_invert(temp)
    data_bit = get_bit(data, iterator)
    if (data_bit == 0):
      result2 = spi_mosi_low(result)
    else:
      result2 = spi_mosi_high(result)
    port.value = result2
    await ClockCycles(clk, SPI_HALF_CYCLE_DELAY)
    temp = port.value;
    result = spi_clk_invert(temp)
    port.value = result
    await ClockCycles(clk, SPI_HALF_CYCLE_DELAY)
    iterator -= 1

  temp = port.value;
  result = spi_clk_invert(temp)
  port.value = result
  await ClockCycles(clk, SPI_HALF_CYCLE_DELAY)

  temp = port.value;
  result = pull_cs_high(temp)
  port.value = result
  await ClockCycles(clk, SPI_HALF_CYCLE_DELAY)  


async def spi_read_cpha0 (clk, port_in, port_out, data_ready, address, data, width):
  
  temp = port_in.value;
  result = pull_cs_high(temp)
  port_in.value = result
  await ClockCycles(clk, SPI_HALF_CYCLE_DELAY)

  # Pull CS low + Read command bit - bit 7 - MSBIT in first byte
  temp = port_in.value;
  result = pull_cs_low(temp)
  result2 = spi_mosi_low(result)
  port_in.value = result2
  await ClockCycles(clk, SPI_HALF_CYCLE_DELAY)
  temp = port_in.value;
  result = spi_clk_invert(temp)
  port_in.value = result
  await ClockCycles(clk, SPI_HALF_CYCLE_DELAY)

  # Next two bits indicate txn width
  iterator = 1
  while iterator >= 0:
    temp = port_in.value;
    result = spi_clk_invert(temp)
    address_bit = get_bit(width, iterator)
    if (address_bit == 0):
      result2 = spi_mosi_low(result)
    else:
      result2 = spi_mosi_high(result)
    port_in.value = result2
    await ClockCycles(clk, SPI_HALF_CYCLE_DELAY)
    temp = port_in.value;
    result = spi_clk_invert(temp)
    port_in.value = result
    await ClockCycles(clk, SPI_HALF_CYCLE_DELAY)
    iterator -= 1

  iterator = 0
  while iterator < 23:
    # Don't care - bits 28-6
    temp = port_in.value;
    result = spi_clk_invert(temp)
    result2 = spi_mosi_low(result)
    port_in.value = result2
    await ClockCycles(clk, SPI_HALF_CYCLE_DELAY)
    temp = port_in.value;
    result = spi_clk_invert(temp)
    port_in.value = result
    await ClockCycles(clk, SPI_HALF_CYCLE_DELAY)
    iterator += 1

  iterator = 5
  while iterator >= 0:
    # Address[iterator] - bits 5-0
    temp = port_in.value;
    result = spi_clk_invert(temp)
    address_bit = get_bit(address, iterator)
    if (address_bit == 0):
      result2 = spi_mosi_low(result)
    else:
      result2 = spi_mosi_high(result)
    port_in.value = result2
    await ClockCycles(clk, SPI_HALF_CYCLE_DELAY)
    temp = port_in.value;
    result = spi_clk_invert(temp)
    port_in.value = result
    await ClockCycles(clk, SPI_HALF_CYCLE_DELAY)
    iterator -= 1

  miso_byte = 0
  miso_bit = 0

  await ClockCycles(clk, 1)
  data_ready_delay = 0
  while data_ready.value == 0:
    data_ready_delay += 1
    assert data_ready_delay < 100
    await ClockCycles(clk, 1)

  iterator = 31
  while iterator >= 0:
    # Data[iterator]
    temp = port_in.value;
    result = spi_clk_invert(temp)
    data_bit = get_bit(data, iterator)
    if (data_bit == 0):
      result2 = spi_mosi_low(result)
    else:
      result2 = spi_mosi_high(result)
    port_in.value = result2
    await ClockCycles(clk, SPI_HALF_CYCLE_DELAY)
    temp = port_in.value;
    result = spi_clk_invert(temp)
    port_in.value = result
    await ClockCycles(clk, SPI_HALF_CYCLE_DELAY)
    miso_bit = spi_miso_read(port_out)
    miso_byte = miso_byte | (miso_bit << iterator)
    iterator -= 1

  temp = port_in.value;
  result = spi_clk_invert(temp)
  port_in.value = result
  await ClockCycles(clk, SPI_HALF_CYCLE_DELAY)

  temp = port_in.value;
  result = pull_cs_high(temp)
  port_in.value = result
  await ClockCycles(clk, SPI_HALF_CYCLE_DELAY)

  return miso_byte
