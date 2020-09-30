 A logging class that can be told where to log to via transports.

 Features include:
 - Asynchronous, ordered output to transports
 - Optionally keeps a history of logs
 - All log messages can be tagged
 - `LogLevel`s are provided as well
 - Force logging enables output via `print` even if no transports available

 ## Filtering

 Two methods exist to allow for filtering of the log stream.

 - `Logger.filterUnless(tag:)`
 - `Logger.filterIf(tag:)`