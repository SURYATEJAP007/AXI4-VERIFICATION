# AMBA AXI4 — SystemVerilog RTL & Verification

A burst-capable AXI4 slave designed in SystemVerilog, verified with a full
layered testbench (generator, driver, monitor, scoreboard, functional
coverage, SVA protocol assertions). Built end-to-end, from spec reading to a
clean simulation run, as a hands-on Design Verification learning project.

## What

- **RTL**: an AXI4 slave supporting all five channels (AW/W/B/AR/R), all
  three burst types (FIXED/INCR/WRAP), and byte-lane writes via WSTRB. A
  shared-memory wrapper merges the write and read paths onto one common
  memory array.
- **Verification environment**: a class-based, layered testbench —
  transaction, generator, driver, concurrent monitor (fork/join_none
  watchers on the write and read channels), a reference-model scoreboard,
  functional coverage (including cross coverage), and SVA assertions
  checking VALID/READY stability on every channel.
- **Result**: 26 writes, 195 reads, 0 failures on Questa/ModelSim, across
  randomized burst types, sizes, and addresses.

## Why

Real AXI4 masters and slaves handle multiple simultaneous, independently-
paced channels, so their bugs are frequently timing- and interaction-based —
exactly the kind of bug that's easy to introduce and hard to spot by reading
code alone. Building both the RTL and its verification environment from
scratch, then debugging it against real simulation output, was the goal —
not just getting a testbench to compile, but getting it to actually catch
real defects.

## How

- RTL built incrementally: single-beat write → single-beat read → burst
  support (FIXED/INCR/WRAP) → WSTRB.
- Verification environment built layer by layer, in the classic driver →
  monitor → scoreboard → coverage → assertions order, each layer manually
  reviewed and compiled before moving to the next.
- Every bug below was found by running the simulation and reading real
  waveform/log evidence — not by static review alone.

## Limitations

- **Single outstanding transaction**: no ID-based multi-transaction
  tracking; a new AW/AR isn't accepted until the previous transaction's
  response completes.
- **No standalone master module**: the driver plays the role of master;
  there's no separate, synthesizable master RTL.
- **No interconnect**: this is a single-master, single-slave setup.

## How to overcome

These are documented, deliberate scope boundaries for a learning project,
not oversights — see `docs/debugging_journey.md` for the bugs found and
fixed along the way, and the natural next steps (ID-based outstanding
transactions, a real master, an interconnect) if extended further.

## Tools

SystemVerilog · Questasim
