# SCADA System

## Overview 

This SCADA System Project uses an Atmega8515 microcontroller programmed in assembly language to manage system modes effectively. It initializes hardware interfaces like UART, LCD, ports, and registers. It switches between supervisor and node modes based on user input. In node mode, it monitors analog input voltages via ADC, providing real-time data through the terminal and LCD. The project enables real-time interaction with the microcontroller for ADC data sampling, summing samples, and setting trim levels.

## Repository Structure
- `README.md`: This file (the one you're reading) provides an overview of the repository.
- `circuit_diagram.ms14`: Electronics circuit diagram of the SCADA system.
- `code.asm`: Assembly code for the SCADA system implemented on the Atmega8515 microcontroller.
- `user_manual.pdf`: Technical manual providing information about the SCADA system.
