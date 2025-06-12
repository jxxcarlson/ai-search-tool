# What is an FPGA?

An **FPGA (Field-Programmable Gate Array)** is a type of integrated circuit that you can reconfigure after manufacturing to implement custom digital logic circuits.

## Basic Architecture

FPGAs contain thousands of **configurable logic blocks (CLBs)** connected by a programmable interconnect fabric. Each CLB typically contains lookup tables (LUTs), flip-flops, and multiplexers. You can program these blocks and their connections to create any digital circuit you want.

## How Programming Works

Instead of writing software, you describe hardware using **hardware description languages** like Verilog or VHDL. This gets synthesized into a configuration bitstream that programs the FPGA's internal structure - essentially rewiring the chip to implement your circuit.

## Key Advantages

- **Parallelism**: Unlike CPUs that execute instructions sequentially, FPGAs can perform many operations simultaneously since you're creating actual parallel hardware circuits
- **Low latency**: No instruction fetch/decode overhead - data flows directly through your custom logic
- **Reconfigurable**: Can be reprogrammed for different applications
- **Deterministic timing**: Predictable, consistent performance

## Common Applications

- **Digital signal processing**: Real-time filtering, FFTs, image processing
- **Networking**: Custom packet processing, protocol implementations
- **Cryptography**: Hardware-accelerated encryption
- **High-frequency trading**: Ultra-low latency market data processing
- **Prototyping**: Testing ASIC designs before expensive fabrication

## vs Other Technologies

- More flexible than ASICs but less efficient
- Much faster than software on CPUs for parallel tasks
- More power-efficient than GPUs for specific workloads
- Harder to program than traditional software

Think of it as programmable hardware - you're literally designing custom circuits rather than writing code that runs on fixed hardware.
