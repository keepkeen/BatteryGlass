# Third-party notices

BatteryGlass includes a modified device-sampling implementation from the
`DeviceBattery` plugin in [MacTools](https://github.com/ggbond268/MacTools).
MacTools is licensed under the Apache License, Version 2.0. The original
license text is included in `MacTools-LICENSE`.

BatteryGlass changes the original files to remove `MacToolsPluginKit`, expose
the sampler through a standalone application controller, and translate plugin
models into a Codable App Group snapshot. The MacTools binary and plugin bundle
are not redistributed.
