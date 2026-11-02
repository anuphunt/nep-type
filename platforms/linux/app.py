#!/usr/bin/env python3
"""Standalone GTK4 Graphite typing-pad UI. Does not register or activate IBus."""
import argparse
import sys
from pathlib import Path

CSS = b"""
window.neptype-pad { background: #1e1e1e; color: #e8e8e8; }
.neptype-pad .brand { font-size: 25px; }
.neptype-pad .name { font-size: 13px; }
.neptype-pad .panel { background: #272727; border: 1px solid #3d3d3d; border-radius: 9px; }
.neptype-pad .panel-header { border-bottom: 1px solid #3d3d3d; padding: 0 8px 0 12px; min-height: 35px; }
.neptype-pad .panel-header label, .neptype-pad .status { color: #aaaaaa; font-size: 11px; }
.neptype-pad textview, .neptype-pad textview text { background: #272727; color: #e8e8e8; }
.neptype-pad textview.source { font-family: monospace; font-size: 18px; }
.neptype-pad textview.output { font-size: 24px; }
.neptype-pad button { color: #aaaaaa; background: transparent; border: 0; box-shadow: none; border-radius: 6px; }
.neptype-pad button:hover { background: #383838; }
.neptype-pad button:disabled { color: #777777; }
.neptype-pad .modes { background: #383838; border: 1px solid #3d3d3d; border-radius: 7px; }
.neptype-pad .modes button { font-size: 11px; padding: 4px 9px; min-height: 22px; }
.neptype-pad .modes button:checked { background: #272727; color: #e8e8e8; }
.neptype-pad .suggestion { border: 1px solid #3d3d3d; background: #272727; color: #e8e8e8; }
.neptype-pad .suggestion:checked { background: #d7d7d7; color: #222222; }
"""


def run(argv):
    try:
        import gi
        gi.require_version("Gtk", "4.0")
        from gi.repository import Gdk, GLib, Gtk
    except (ImportError, ValueError) as error:
        print("NepType needs GTK 4 and the distribution's Python GObject bindings (python3-gi).", file=sys.stderr)
        return 1

    class TypingPad(Gtk.Application):
        def __init__(self):
            super().__init__(application_id="app.neptype.typingpad")
            self.window = None
            self.feedback_generation = 0

        def do_activate(self):
            if self.window is not None:
                self.window.present()
                return
            settings = Gtk.Settings.get_default()
            if settings is not None:
                settings.set_property("gtk-application-prefer-dark-theme", True)
            provider = Gtk.CssProvider()
            provider.load_from_data(CSS)
            Gtk.StyleContext.add_provider_for_display(Gdk.Display.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
            self.window = Gtk.ApplicationWindow(application=self, title="NepType · Typing pad")
            self.window.add_css_class("neptype-pad")
            self.window.set_default_size(620, 430)
            self.window.set_size_request(520, 398)
            content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=11)
            for edge in ("top", "bottom", "start", "end"):
                getattr(content, "set_margin_" + edge)(16)
            self.window.set_child(content)
            toolbar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
            brand = Gtk.Image.new_from_file(str(Path(__file__).resolve().parent / "assets/neptype-mark.png"))
            brand.set_pixel_size(32)
            brand.set_tooltip_text("NepType logo")
            toolbar.append(brand)
            name = Gtk.Label(label="NepType"); name.add_css_class("name"); toolbar.append(name)
            space = Gtk.Box(); space.set_hexpand(True); toolbar.append(space)
            modes = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
            modes.add_css_class("modes")
            mixed = Gtk.ToggleButton(label="Nepali + EN")
            nepali = Gtk.ToggleButton(label="All Nepali")
            nepali.set_group(mixed); mixed.set_active(True)
            # This new frontend has no pad-render transport. Do not pretend
            # that the separate experimental IBus worker renders a document.
            mixed.set_sensitive(False); nepali.set_sensitive(False)
            modes.append(mixed); modes.append(nepali); toolbar.append(modes)
            help_button = Gtk.Button.new_from_icon_name("help-about-symbolic")
            help_button.set_tooltip_text("About this typing pad")
            help_button.connect("clicked", self.show_help)
            toolbar.append(help_button)
            content.append(toolbar)
            self.source = self.editor(True, "source")
            self.source.get_buffer().connect("changed", self.source_changed)
            clear = Gtk.Button(label="Clear")
            clear.connect("clicked", lambda _: self.source.get_buffer().set_text(""))
            content.append(self.panel("Roman input", self.source, clear, 72))
            self.suggestions = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
            self.suggestions.set_size_request(-1, 36)
            content.append(self.suggestions)
            self.output = self.editor(False, "output")
            self.copy = Gtk.Button.new_from_icon_name("edit-copy-symbolic")
            self.copy.set_tooltip_text("Copy text")
            self.copy.set_sensitive(False)
            self.copy.connect("clicked", self.copy_text)
            result = self.panel("नेपाली", self.output, self.copy, 90)
            result.set_vexpand(True)
            content.append(result)
            self.status = Gtk.Label(label="Linux preview · Conversion unavailable", xalign=0)
            self.status.add_css_class("status")
            content.append(self.status)
            self.window.present()

        def editor(self, editable, style):
            text = Gtk.TextView()
            text.set_tooltip_text("Roman input" if editable else "Nepali output")
            text.set_editable(editable)
            text.set_cursor_visible(editable)
            text.set_wrap_mode(Gtk.WrapMode.WORD_CHAR)
            text.set_left_margin(12); text.set_right_margin(12)
            text.set_top_margin(10); text.set_bottom_margin(12)
            text.add_css_class(style)
            return text

        def panel(self, title, editor, action, minimum):
            panel = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
            panel.add_css_class("panel")
            header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
            header.add_css_class("panel-header")
            label = Gtk.Label(label=title, xalign=0)
            label.set_hexpand(True)
            header.append(label); header.append(action); panel.append(header)
            scroll = Gtk.ScrolledWindow()
            scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
            scroll.set_min_content_height(minimum)
            scroll.set_vexpand(True)
            scroll.set_child(editor)
            panel.append(scroll)
            return panel

        def source_changed(self, _):
            self.feedback_generation += 1
            if hasattr(self, "output"):
                self.output.get_buffer().set_text("")
                self.copy.set_sensitive(False)
                self.copy.set_icon_name("edit-copy-symbolic")

        def copy_text(self, _):
            buffer = self.output.get_buffer()
            text = buffer.get_text(*buffer.get_bounds(), False)
            if not text:
                return
            self.window.get_clipboard().set(text)
            self.feedback_generation += 1
            current = self.feedback_generation
            self.copy.set_icon_name("emblem-ok-symbolic")
            self.copy.set_tooltip_text("Copied")
            def restore():
                if current == self.feedback_generation:
                    self.copy.set_icon_name("edit-copy-symbolic")
                    self.copy.set_tooltip_text("Copy text")
                return GLib.SOURCE_REMOVE
            GLib.timeout_add(1800, restore)

        def show_help(self, _):
            dialog = Gtk.MessageDialog(transient_for=self.window, modal=True,
                message_type=Gtk.MessageType.INFO, buttons=Gtk.ButtonsType.CLOSE,
                text="NepType typing pad")
            dialog.set_property("secondary-text", "This standalone Graphite preview does not yet connect to the typing engine. No IBus input source is installed or enabled.")
            dialog.connect("response", lambda message, response: message.destroy())
            dialog.present()

    return TypingPad().run(argv)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.parse_args()
    return run([sys.argv[0]])


if __name__ == "__main__":
    raise SystemExit(main())
