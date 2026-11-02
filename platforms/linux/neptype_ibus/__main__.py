"""Start when launched by IBus; this does not register the engine on disk."""
import sys
import gi

gi.require_version("IBus", "1.0")
from gi.repository import GLib, IBus
from .engine import NepTypeEngine

def main():
    IBus.init()
    bus = IBus.Bus()
    if not bus.is_connected():
        print("NepType: IBus is unavailable; no input service started.", file=sys.stderr)
        return 1
    loop = GLib.MainLoop()
    bus.connect("disconnected", lambda *_: loop.quit())
    factory = IBus.Factory.new(bus.get_connection())
    factory.add_engine("neptype", NepTypeEngine.__gtype__)
    # The factory must remain alive while the daemon runs.
    bus.request_name("org.freedesktop.IBus.NepType", 0)
    try:
        loop.run()
    except KeyboardInterrupt:
        pass
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
