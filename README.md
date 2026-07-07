# EnergyMonitor

<!-- TODO: Update the Pastebin ID used in the installation command. -->

EnergyMonitor is a ComputerCraft/CC:Tweaked program for monitoring energy storage and transfer rates across multiple computers and peripherals. A server collects data from client computers and broadcasts a combined view to one or more monitor computers.

## How It Works

EnergyMonitor uses three computer roles:

- `server`: collects updates from clients and sends aggregated data to monitors.
- `client`: reads one local energy peripheral, such as an energy storage block or transfer meter.
- `monitor`: displays the server's aggregated data on an attached monitor.

All computers in the same EnergyMonitor network must use the same modem channel/port and have a wireless modem attached.

## Installation

On each ComputerCraft computer, run:

```sh
pastebin get FGfgaAty git
git
```

The installer will ask for:

- Language
- Computer role: server, monitor, or client
- Client peripheral type, when installing a client
- Transfer direction, when installing a transfer client
- Modem channel/port
- Computer label
- Startup installation

Use the same modem channel/port for every server, client, and monitor that should belong to the same EnergyMonitor network. The default channel is `5`.

## Recommended Setup

1. Install one computer as `server`.
2. Install one or more computers as `client`.
3. For each client, place the computer next to the energy peripheral it should read.
4. Install one or more computers as `monitor`.
5. Attach a monitor to each monitor computer. A monitor size of at least 4 blocks wide and 2 blocks high is recommended.
6. Make sure every computer has a wireless modem and uses the same modem channel/port.

Computer labels are shown in the UI, so labeling client computers with names like `Reactor Input`, `Main Induction Matrix`, or `Storage Core` is recommended.

## Client Types

When installing a client, choose one of:

- `Energy storage / capacitor`: reports stored energy and capacity.
- `Energy transfer / meter`: reports input, output, or both transfer rates.

For transfer clients, choose the direction:

- `Input`: energy entering storage or a system.
- `Output`: energy leaving storage or a system.
- `Both`: report both input and output when the peripheral supports it.

## Supported Peripherals

Built-in support currently includes:

- Generic energy storage peripherals exposing methods like `getEnergyStored` / `getMaxEnergyStored`
- Generic transfer peripherals exposing transfer-rate methods
- Mekanism energy devices, including induction ports
- Energy Meter peripherals
- Draconic Evolution energy core storage
- Draconic Evolution energy core transfer
- Draconic Evolution flux gates

Mekanism induction ports can be used as either storage clients or transfer clients. The selected installer role determines which wrapper is used.

## Custom Peripheral Support

Peripheral detection is registry-based. New custom support can be added by registering storage or transfer handlers in `EnergyMonitor/classes/peripherals/Peripherals.lua`:

```lua
_G.registerEnergyStorageSupport({
  label = "My Storage",
  matches = function(ctx)
    return ctx.type == "my_storage_type"
  end,
  create = function(ctx)
    return newMyStorage("id", ctx.peripheral, ctx.name, ctx.type)
  end
})
```

Transfer handlers use the same shape, but usually pass `ctx.transferType` to the wrapper constructor.

## Configuration

Settings are stored in:

```sh
/EnergyMonitor/config/options.txt
```

Important options:

- `program`: `server`, `client`, or `monitor`
- `peripheralType`: `capacitor`, `transfer`, or `n/a`
- `transferType`: `input`, `output`, `both`, or `n/a`
- `modemChannel`: modem channel/port used by this EnergyMonitor network
- `debug`: set to `1` for debug output

## Troubleshooting

**No modem found**

Attach a wireless modem and reboot the computer. All roles require a wireless modem.

**Clients do not appear on the monitor**

Check that:

- The server is running.
- Clients and monitors use the same `modemChannel`.
- Every computer has a wireless modem.
- The client is installed with the correct peripheral type.

**A transfer rate shows `0`**

Some peripherals do not expose every transfer method. EnergyMonitor ignores missing peripheral methods and reports `0` instead of crashing. Enable debug mode to see which method is missing.

**Monitor is too small**

Use a larger attached monitor. A size of at least 4 blocks wide and 2 blocks high is recommended. The monitor program expects enough space for the header, filter controls, device cells, and footer.

## Updating

The program can auto-update when enabled in `options.txt`. Existing configuration is preserved during updates.
