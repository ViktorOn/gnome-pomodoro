/*
 * Copyright (c) 2016 gnome-pomodoro contributors
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

using GLib;


namespace GnomePlugin
{
    private class GnomeShellExtension : GLib.Object, GLib.AsyncInitable
    {
        public string uuid {
            get;
            construct set;
        }

        public Gnome.ExtensionInfo info {
            get;
            private set;
        }

        public bool enabled {
            get {
                return this.info.state == Gnome.ExtensionState.ENABLED;
            }
        }

        private Gnome.ShellExtensions? proxy = null;


        public GnomeShellExtension (string uuid) throws GLib.Error
        {
            GLib.Object (uuid: uuid);
        }

        construct
        {
            this.info = Gnome.ExtensionInfo.with_defaults (this.uuid);
        }

        public virtual async bool init_async (int io_priority = GLib.Priority.DEFAULT,
                                              Cancellable? cancellable = null)
                                              throws GLib.Error
        {
            try {
                this.proxy = yield GLib.Bus.get_proxy<Gnome.ShellExtensions> (
                        GLib.BusType.SESSION,
                        "org.gnome.Shell",
                        "/org/gnome/Shell",
                        GLib.DBusProxyFlags.DO_NOT_AUTO_START,
                        cancellable);
            }
            catch (GLib.Error error) {
                // GLib.warning ("Failed to connect to org.gnome.Shell.ShellExtensions: %s", error.message);
                throw error;
            }

            this.proxy.extension_state_changed.connect (this.on_extension_state_changed);
            // this.proxy.extension_status_changed.connect (this.on_status_changed);

            yield this.update_info ();

            return true;
        }

        private void on_info_changed ()
        {
        }

        private void on_extension_state_changed (string uuid,
                                                 HashTable<string,Variant> data)
        {
            if (uuid != this.uuid) {
                return;
            }

            try {
                this.info = Gnome.ExtensionInfo.deserialize (uuid, data);
            }
            catch (GLib.Error error) {
                this.info = Gnome.ExtensionInfo.with_defaults (uuid);
            }

            this.on_info_changed ();
        }

        private async void update_info (GLib.Cancellable? cancellable = null)
        {
            GLib.return_if_fail (this.proxy != null);

            HashTable<string,Variant> data;

            GLib.debug ("Fetching extension info of \"%s\"...", this.uuid);

            try {
                data = yield this.proxy.get_extension_info (this.uuid, cancellable);

                this.info = Gnome.ExtensionInfo.deserialize (this.uuid, data);

                GLib.debug ("Extension path: %s", this.info.path);
                GLib.debug ("Extension state: %s", this.info.state.to_string ());
            }
            catch (GLib.Error error) {
                GLib.critical ("%s", error.message);
                return;
            }

            this.on_info_changed ();
        }

        public async void enable (GLib.Cancellable? cancellable = null)
        {
        }

        public override void dispose ()
        {
            this.proxy = null;

            GLib.Application.get_default ()
                            .withdraw_notification ("extension");

            base.dispose ();
        }
    }
}
