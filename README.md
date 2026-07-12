# EnergyMonitor

EnergyMonitor is a ComputerCraft/CC:Tweaked program for monitoring energy storage and transfer rates across multiple computers and peripherals. A server collects data from client computers and broadcasts a combined view to one or more monitor computers.

## How It Works

EnergyMonitor uses three computer roles:

- `server`: collects updates from clients and sends aggregated data to monitors.
- `client`: reads one local energy peripheral, such as an energy storage block or transfer meter.
- `monitor`: displays the server's aggregated data on an attached monitor.

All computers in the same EnergyMonitor network must use the same modem channel/port and have a wireless modem attached.

## Preview

![EnergyMonitor monitor UI](docs/images/monitor.png)

## Installation

On each ComputerCraft computer, run:

```sh
pastebin get gUbUpXHt git
git
```

The default install command fetches the latest stable tag. To install a beta or a specific release, use:

```sh
git beta
git v1.7.4
git v1.7.4.1
git v1.7.4-beta
git v1.7.4.1-beta
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

If you are installing from a fork, update the repository owner/name constants in `EnergyMonitor/install/github_downloader.lua`, `EnergyMonitor/install/installer.lua`, and `EnergyMonitor/start/start.lua`. If you move the project off GitHub, also adjust the tag-list API URL in those scripts.

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

Peripheral detection is registry-based. To add support for another mod or custom peripheral:

For a concrete implementation example, see [commit `f6869c5`](https://github.com/TrickShotMLG02/EnergyMonitor/commit/f6869c5).

1. Add the wrapper class under `EnergyMonitor/classes/peripherals/<modName>/`.
2. Load that Lua file in `EnergyMonitor/start/start.lua` inside `initClasses()`, in the `Add Mod Support below` section.
3. Add the new file path to `EnergyMonitor/files.txt` so the installer downloads it.
4. Register a storage or transfer handler in `EnergyMonitor/classes/peripherals/Peripherals.lua`.

Example class path:

```sh
EnergyMonitor/classes/peripherals/myMod/MyStorage.lua
```

Example `start.lua` entry:

```lua
-- My Mod Support
shell.run(periPath.."myMod/MyStorage.lua")
```

Example `files.txt` entry in the `class.files` list:

```lua
"classes/peripherals/myMod/MyStorage.lua",
```

Example storage registration in `Peripherals.lua`:

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

Transfer handlers use the same shape, but usually pass `ctx.transferType` to the wrapper constructor. Put more specific handlers before generic fallback handlers so a custom peripheral is not claimed by generic method detection first.

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

When the monitor cannot reach the server, it shows a network error notice:

![EnergyMonitor network error notice](docs/images/monitor_network_error.png)

**A transfer rate shows `0`**

Some peripherals do not expose every transfer method. EnergyMonitor ignores missing peripheral methods and reports `0` instead of crashing. Enable debug mode to see which method is missing.

**Monitor is too small**

Use a larger attached monitor. A size of at least 4 blocks wide and 2 blocks high is recommended. The monitor program expects enough space for the header, filter controls, device cells, and footer.

## Updating

The program can auto-update when enabled in `options.txt`. Existing configuration is preserved during updates. Updates compare the stored tag against the latest semver tag in the same channel.

## Releases

Versioning is tag-based:

- Stable releases use tags like `v1.7.4` or `v1.7.4.1`.
- Beta releases use tags like `v1.7.4-beta` or `v1.7.4.1-beta`.
- Missing trailing parts are treated as zeros, so `v2.3`, `v2.3.0`, and `v2.3.0.0` compare the same way.
- `v3` compares as `v3.0.0.0`.
- To publish a release, commit the code and create the matching tag.
- To publish a beta, tag the commit with the `-beta` suffix.
- The installer can fetch the latest stable tag, the latest beta tag, or a specific tag directly.

## Contributing

Contributions are welcome, especially support for additional energy peripherals, monitor UI improvements, installer improvements, and bug fixes.

Please make pull requests easy to review:

- Create the change in a fork of this repository.
- Use a separate branch with a clear name, such as `feature/mekanism-buffer-support`, `fix/modem-timeout-notice`, or `docs/custom-peripherals`.
- Keep each pull request focused on one purpose. Avoid mixing unrelated refactoring, formatting, feature work, and bug fixes in the same PR.
- Document user-facing changes in this README when behavior, setup, configuration, supported peripherals, or troubleshooting changes.
- Add new downloaded files to `EnergyMonitor/files.txt`; otherwise the installer will not fetch them.
- Describe what changed in the PR description and mention why the change is needed.
- Include how you tested the change, for example the ComputerCraft role used, attached peripheral type, modem channel, and whether the monitor UI was checked.
- Include screenshots for monitor UI changes when possible.
- Avoid changing default configuration or update behavior unless the PR clearly explains the impact.
- Do not commit local IDE files, temporary files, logs, or ComputerCraft runtime state.

For new peripheral support, include the peripheral type name, the methods exposed by the peripheral, the mod name/version if known, and whether the device acts as storage, transfer, or both.
