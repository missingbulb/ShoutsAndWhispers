/// Product copy shared between the UI, the adapters that surface problems,
/// and the executable UI requirements (dev/requirements/) — one source of
/// truth so a reworded message is a spec change, not a silent drift.
library;

/// Location services are disabled on the device.
const String locationServicesOffCopy =
    'Location services are turned off. Turn them on to send '
    'and receive nearby messages.';

/// Location permission denied (asking again is still possible).
const String locationPermissionDeniedCopy =
    'Location permission denied — nearby messaging needs your position.';

/// Location permission permanently denied (only system settings can fix it).
const String locationPermissionForeverCopy =
    'Location permission is permanently denied. Enable it '
    'for this app in your system settings, then retry.';
