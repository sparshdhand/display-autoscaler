# Visual Identity & Token Specifications

Since `display-autoscaler` is a zero-UI utility running purely in the background:
- **Visuals:** It has no windowing, menubars, status items, or Dock icons.
- **Log Aesthetics:** Standard output logs follow a clean, unified structure prefix to make log auditing straightforward for the user.
- **System Constraints:** Under load or idle, CPU usage must remain near 0% and RSS memory must remain low.

## Log Output Styling
Logs are directed to standard output / standard error streams:
* `[display-autoscaler:info] <message>`: Non-critical operations (such as startup or successful mode application).
* `[display-autoscaler:warn] <message>`: Missing config fallback notifications.
* `[display-autoscaler:error] <message>`: API failures, configuration syntax issues, or target modes not found.
