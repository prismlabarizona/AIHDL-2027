# PnR + Signoff SDC: hardcodes the REAL clock period (17.5 ns) so PnR and
# signoff STA see the actual operating clock, while synthesis can use a
# tighter CLOCK_PERIOD (e.g. 12 ns) to force bigger / slow-corner-friendlier
# cells. This file is independent of $::env(CLOCK_PERIOD).
#
# DO NOT use $::env(CLOCK_PERIOD) here — that variable is intentionally set
# to a smaller value for synth and is not the real signoff clock.

set sdc_clock_period 17.5

# Pick the clock port from env if available, else default to "clk".
set clock_port "clk"
if { [info exists ::env(CLOCK_PORT)] } {
    set port_count [llength $::env(CLOCK_PORT)]
    if { $port_count > "0" } {
        set clock_port [lindex $::env(CLOCK_PORT) 0]
    }
}

# Create the clock at the real signoff period.
create_clock [get_ports $clock_port] -name $clock_port -period $sdc_clock_period
puts "\[INFO\] PnR/Signoff SDC: clock $clock_port at $sdc_clock_period ns"

# Same clock-uncertainty profile as base.sdc (TT mux duty-cycle uncertainty).
set_clock_uncertainty 2.5 -rise_from $clock_port -fall_to $clock_port
set_clock_uncertainty 2 -fall_from $clock_port -rise_to $clock_port

# Reset.
set_input_delay 1.5 -clock [get_clocks $clock_port] {rst_n}

# Input IOs (driven on falling edge — see base.sdc rationale).
set input_setup_delay_value [expr $sdc_clock_period * 0.65]
set input_hold_delay_value  [expr $sdc_clock_period * 0.24]
set_input_delay -clock [get_clocks $clock_port] -max $input_setup_delay_value {uio_in ui_in}
set_input_delay -clock [get_clocks $clock_port] -min $input_hold_delay_value {uio_in ui_in}

# Output IOs (uio_out + uio_oe). uio_out[3] is SPI clock, treated separately.
set output_setup_delay_value [expr $sdc_clock_period * 0.65]
set output_hold_delay_value  1
set_output_delay -clock [get_clocks $clock_port] -max $output_setup_delay_value {uio_out[7] uio_out[6] uio_out[5] uio_out[4] uio_out[2] uio_out[1] uio_out[0] uio_oe}
set_output_delay -clock [get_clocks $clock_port] -min $output_hold_delay_value {uio_out uio_oe}

# SPI clock output (lower delay, can be driven on negedge).
set spi_clk_setup_delay_value [expr $sdc_clock_period * 0.18]
set_output_delay -clock [get_clocks $clock_port] -max $spi_clk_setup_delay_value {uio_out[3]}

# User outputs.
set_output_delay -clock [get_clocks $clock_port] -min 1 {uo_out}
set_output_delay -clock [get_clocks $clock_port] -max 1 {uo_out}
