# Non-interactive screenshot via xdg-desktop-portal (works on GNOME 49, unlike org.gnome.Shell.Screenshot).
# Saves to your Pictures folder (xdg-user-dir PICTURES, e.g. ~/Pictures/Screenshot.png) - it may
# overwrite an older one - and prints the URI. Move the file away afterwards.
import sys, gi
gi.require_version('Gio','2.0')
from gi.repository import Gio, GLib
bus = Gio.bus_get_sync(Gio.BusType.SESSION)
loop = GLib.MainLoop(); out = {}
def on_resp(conn, sender, path, iface, sig, params):
    code, res = params.unpack(); out['code']=code; out['uri']=res.get('uri'); loop.quit()
token = 'stk%d' % GLib.random_int_range(0, 1<<30)
sender = bus.get_unique_name()[1:].replace('.','_')
hpath = f'/org/freedesktop/portal/desktop/request/{sender}/{token}'
bus.signal_subscribe('org.freedesktop.portal.Desktop','org.freedesktop.portal.Request','Response',hpath,None,0,on_resp)
bus.call_sync('org.freedesktop.portal.Desktop','/org/freedesktop/portal/desktop','org.freedesktop.portal.Screenshot','Screenshot',
  GLib.Variant('(sa{sv})',('',{'handle_token':GLib.Variant('s',token),'interactive':GLib.Variant('b',False)})),None,0,-1,None)
GLib.timeout_add_seconds(60, loop.quit); loop.run(); print(out)
