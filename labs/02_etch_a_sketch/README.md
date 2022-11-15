# Lab 2: Etch a Sketch

**Ari's Note:** Due to unsolved FPGA issues, I wasn't able to test this is synthesis. All of the tests pass and the waveforms look right. I've discussed and debugged this with Avinash, who said that I could submit this as-is for now and will resubmit (or otherwise arrange with him) once we can get the FPGA issues.

In this lab we're going to build logic to make an "etch a sketch" or sketchpad hardware device. Over the course of the lab you will learn how to:
* Design your own specifications for complex sequential and combinational logic blocks.
* Implement controllers for the popular SPI and i2c serial interfaces.
* Learn how to interface with both ROM and RAM memories.

This lab is more of a survey than an open ended design. After each section solutions to the prior one will be provided to help us keep moving and learning.

![block diagram](docs/lab2-block-diagram.png)

We're using [Adafruit's 2.8" TFT LCD with Cap Touch Breakout Board w/MicroSD Socket](https://www.adafruit.com/product/2090). Through the course of the lab we'll interface with following components on the breakout board.
- a 240x320 RGB TFT Display
- an ILI9341 Display Controller [datasheet](https://cdn-shop.adafruit.com/datasheets/ILI9341.pdf)
- an FT6206 Capacitive Touch Controller [datasheet](https://cdn-shop.adafruit.com/datasheets/FT6x06+Datasheet_V0.1_Preliminary_20120723.pdf) and [app note](https://cdn-shop.adafruit.com/datasheets/FT6x06_AN_public_ver0.1.3.pdf)
- (stretch) There is also an SD card on the display board, consider using it for a final project!

Last, there are a ton of best practice techniques hidden in this folder, I encourage you to explore to get some practice of learning from professional examples.

## Lab Report Details
- [x] Pulse generator
- [x] PWM Module
- [x] Triangle Generator
- [x] One of:
    - [x] SPI Controller for Display
    - [ ] i2c Controller for touchscreen
- [x] Learning from Professional Code: In your own words, describe the FSMs in:
    - [x] `ili9341_display_controller.sv`
    - [x] `ft6206_controller.sv`
- [x] Design and implement a main FSM that interfaces with a video RAM.

# Part 0) Learning from Professional Code

## `ili9341_display_controller.sv`

### Main FSM

- `S_INIT`: Initializes the display. All content for this state is covered by the configuration FSM below.
- `S_INCREMENT_PIXEL`: Moves to the next pixel (taking into account the end of a row, etc.). If this pixel was the last pixel of the frame, then transition to `S_START_FRAME` to start the next frame. Otherwise, transition to `S_TX_PIXEL_DATA_START` to write the next pixel. 
- `S_TX_PIXEL_DATA_BUSY`: Wait till the SPI controller is ready, then move on to the next pixel by transitioning to `S_INCREMENT_PIXEL`. This state appears to be unused, and feels like it probably ought to be integrated into `S_WAIT_FOR_SPI`.
- `S_WAIT_FOR_SPI`: Helper state to wait till the SPI controller is ready, then transition to whatever the pending state is (stored in `state_after_wait`).
- `S_ERROR`: Indicates an error has occurred. Device must be reset.
- SPI Transactions: Each of the following states is an SPI transaction, and so transitions to its next state through `S_WAIT_FOR_SPI` to ensure that the SPI Controller has time to catch up. See the touchscreen controller's section for a more in-depth explanation of this mechanism.
    - `S_START_FRAME`: Starts a new frame by transitioning to `S_TX_PIXEL_DATA_START`, via `S_WAIT_FOR_SPI`.
    - `S_TX_PIXEL_DATA_START`: Write the current pixel data to the display, then move on to the next pixel by transitioning to `S_INCREMENT_PIXEL` via `S_WAIT_FOR_SPI`.

### Configuration FSM

This is a nested FSM used within `S_INIT`.

- `S_CFG_GET_DATA_SIZE`: Begin the cycle of sending one command to the display by reading from memory the length of the command's associated data (which has already been fetched). If no commands remain, transitions to `S_CFG_DONE`. Otherwise, transitions to `S_CFG_GET_CMD` via `S_CFG_MEM_WAIT`.
- `S_CFG_GET_CMD`: Fetch a command from memory, then transition to `S_CFG_SEND_CMD` via `S_CFG_MEM_WAIT`.
- `S_CFG_SEND_CMD`: Send the fetched command to the display, then send its associated data by transitioning to `S_CFG_GET_DATA` via `S_CFG_SPI_WAIT`. If the command was NULL (`0x00`), then transition to `S_CFG_DONE`.
- `S_CFG_GET_DATA`: Fetch the next byte of command data from memory, keeping track of the number of bytes remaining. Then send it to the display by transitioning to `S_CFG_SEND_DATA` via `S_CFG_MEM_WAIT`. If no bytes remain, transition back to `S_CFG_GET_DATA_SIZE` via `S_CFG_MEM_WAIT` to begin sending the next command.
- `S_CFG_SEND_DATA`: Send the fetched byte of command data, then transition back to `S_CFG_GET_DATA` via `S_CFG_SPI_WAIT` to send the next byte.
- `S_CFG_SPI_WAIT`: Helper state that waits for the SPI controller to be ready AND for `cfg_delay_counter` clock cycles to have elapsed, then transitions to the pending state (see `S_WAIT_FOR_SPI`, `S_WAIT_FOR_I2C_WR/RD`).
- `S_CFG_MEM_WAIT`: Helper state that "waits" for the result to have been received from memory, then transitions to the pending state (see `S_WAIT_FOR_SPI`, `S_WAIT_FOR_I2C_WR/RD`). Since our memory only takes one clock cycle, this immediately transitions to the next state.
- `S_CFG_DONE`: Indicates that configuration has finished, begins writing the first frame by transitioning to `S_START_FRAME` (thereby leaving the Configuration FSM).


## `ft6206_controller.sv`

This touchscreen controller's main FSM is actually considerably simpler than the display controller's. It has the following states:

- Setup:
    - `S_INIT`: Immediately transitions to `S_SET_THRESHOLD_REG`. This is the default state after a reset, and is never returned to except after a reset.
    - `S_IDLE`: Transitions to `S_GET_REG_REG` (with `active_register = TD_STATUS`) as soon as the I2C controller is ready, provided `ena` is asserted. This state is used after after each register-read cycle, and restarts said cycle.
- I2C Transactions: Each of the following states, except for `S_GET_REG_DONE`, is an I2C transaction, and so temporarily transitions to `S_WAIT_FOR_I2C_WR/RD` afterwards (see below):
    - Reading: Registers are read one at a time, and the same set of states is used for all registers (the register being currently read is stored in `active_register`)
        - `S_GET_REG_REG`: Writes the target register to the secondary
        - `S_GET_REG_DATA`: Reads the target register's value from the secondary
        - `S_GET_REG_DONE`: Transitions back to `S_GET_REG_REG` to read the next register. Does some processing/validation of new data. Once all registers have been read, transitions to `S_TOUCH_DONE`. This is not an I2C transaction state, and so does not transition to `S_WAIT_FOR_I2C_WR/RD`.
    - Writing: This controller only writes to one register, `THRESHOLD` (the touch detection threshold). Consequently the writing states are specialized as `S_SET_THRESHOLD_WHATEVER`:
        - `S_SET_THRESHOLD_REG`: Writes the target register to the secondary
        - `S_SET_THRESHOLD_DATA`: Writes the threshold data to the secondary
    - Waiting:
        - `S_WAIT_FOR_I2C_WR`/`S_WAIT_FOR_I2C_RD`: Between each I2C transaction, the FSM waits until the I2C controller is ready again by transitioning to one of these states. It stores the subsequent desired state in `state_after_wait`, which these states transition to as soon as the I2C controller is ready.
- Other:
    - `S_TOUCH_DONE`: Happens after all registers have been read. Reformats touch data for external consumption, then transitions to `S_IDLE` (which starts the cycle all over again).
    - `S_ERROR`: Unused
    - `S_TOUCH_START`: Unused


# Part 1) Sequential Logic & FPGA Programming
Let's start with a simple example to make sure we all have the tools working and can effectively design, simulate, and synthesize combination logic and simple FSMs.

## Pulse Generator
Start by trying to implement a pulse generator - this is a module that outputs high for exactly one clock cycle out of every N ticks. Implement your code in `pulse_generator.sv`.

Get an instructor sign off by showing your working `gtkwave` simulation before proceeding!

## PWM Module
Pulse Width Modulation, or PWM is the first and easiest way of trying to get an analog or continuous value from a digital signal. Design and simulate an implementation in `pwm.sv`. Like before, show your working simulation in `gtkwave` before proceeding.

## Triangle Generator
A triangle or sawtooth generator is a counter that starts at zero, counts up to its maximum value, then counts down back to zero, etc. Implement a simple FSM, and show your waveforms to an instructor before proceeding.

## Putting it all together
Last, we're going to showcase the three above modules in `main.sv` by fading the LEDs in and out. To do this we'll use `pulse_generators` to generate some slower "step" signals that keep things changing at human rates. Next we'll use our `triangle_generator` to make a signal we can use to brighten and dim our LEDs. Finally, the `pwm` modules actually drive the LEDs.

All of this has been implemented in `main.sv` so you shouldn't have to make any changes. Start by doing a `make main.bit`, then use either `make program_fpga_vivado` or `make program_fpga_digilent` to program the FPGA. Remember to edit `build.tcl` to pick he right part on the `synth_design` line.

# Part 2) Serial Data Protocols

## Wiring the display:
If you are clever you can wire the display like so:
![Breadboard Example](docs/breadboard-example.jpg)
You then will only need to wire the GND pins to GND and the Vin pin to VU. The `main.xdc` pin assignment file has this layout commented out - check each pin to make sure it lines up before powering your board.

There are two tracks for this portion - either working with the (a) display XOR (b) the touchscreen. For both tracks the high level FSMs and logic have been done for you since they are a little complicated! Your responsibility is to implement a module that can implement either SPI XOR i2c to talk to the display or touch screen. Both tracks deal with serialization, but the i2c option is slightly more complicated (since you need to both write and read data).  

Writing sequential testbenches is difficult, so the tests for this are already provided.


## 2a) Display Controller - Sending Serialized Data over SPI
Your goal for this section is to finish implementing `spi_controller.sv`, and to read through `ili9341_display_controller.sv` and understand it enough to change the test pattern. NOTE - you only need to implement the `WRITE_8` and `WRITE_16` modes! 

You should run `make test_ili9341_display_controller` before trying to synthesize - it will catch any odd errors. 

Once you have it working, make sure that the ILI9341 display controller in main.sv has the test pattern enabled: `.enable_test_pattern(1'b1)`. If your SPI controller is working you should see a test pattern on the display. 

Finally, edit `ili9341_display_controller.sv`'s `display_color_logic` section to change the test pattern in any way. Bonus - make the test pattern change over time by adding an FSM of some sort!

## 2b) Touchscreen Controller - Receiving Serialized Data over i2c
This part is a little more challenging. 
Your goal for this selection is to finish implementing `i2c_controller.sv` so that we can talk to the FT6206 touch screen controller on the display. Technically to use i2c you have to both send and receive serial data, but the focus of this is on receiving data from the capacitive touch sensor. There is a suggested `i2c_state_t` in `i2c_types.sv` - I encourage building your high level FSM around that. 

i2c can be a bit tricky of a protocol, so the real proof is if it works in synthesis. I recommend testing by mapping `touch0.x` and `touch0.y` to your debug LED pwm inputs when `touch0.valid` is high - that will make the two LEDs respond to the touch screen.

# Part 3) Interfacing with VRAM
Design and implement an FSM that can:
- [x] clear memory on button press.
- [x] update memory based on touch values.
- [x] emit draw signals based on memory.
- [ ] bonus: add colors, different modes.
- [ ] stretch bonus: add fonts/textures! (hint, creating more ROMs (see `generate_memories.py` is a good way to approach this).