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

        // public Gnome.ExtensionState state {  // TODO: remove
        //     get {
        //         return this._state;
        //     }
        //     private set {
        //         var was_enabled = this.enabled;
        //
        //         this._state = value;
        //
        //         if (this.enabled != was_enabled) {
        //             this.notify_property ("enabled");
        //         }
        //     }
        // }

        public Gnome.ExtensionInfo info {
            get;
            private set;
        }

        public bool enabled {
            get {
                return this.info.state == Gnome.ExtensionState.ENABLED;
            }
        }

        // private Gnome.ExtensionState   _state = Gnome.ExtensionState.UNKNOWN;
        private Gnome.ShellExtensions? proxy = null;


        public GnomeShellExtension (string uuid) throws GLib.Error
        {
            GLib.Object (uuid: uuid);
        }

        construct
        {
            this.info = Gnome.ExtensionInfo.with_defaults (this.uuid);

            // this.info = Gnome.ExtensionInfo() {
            //     uuid = this.uuid,
            //     path = "",
            //     version = "",
            //     state = Gnome.ExtensionState.UNKNOWN
            // };
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








        /**
         * Wait until enabled, listening to D-Bus status changes.
         */
        private async void ensure_enabled (GLib.Cancellable? cancellable = null)
        {
            /*
            var cancellable_handler_id = (ulong) 0;

            if (!this.enabled && (cancellable == null || !cancellable.is_cancelled ()))
            {
                var handler_id = this.notify["enabled"].connect_after (() => {
                    if (this.enabled) {
                        this.ensure_enabled.callback ();
                    }
                });

                if (cancellable != null) {
                    cancellable_handler_id = cancellable.cancelled.connect (() => {
                        this.ensure_enabled.callback ();
                    });
                }

                yield;

                this.disconnect (handler_id);

                if (cancellable != null) {
                    // cancellable.disconnect() causes a deadlock here
                    GLib.SignalHandler.disconnect (cancellable, cancellable_handler_id);
                }
            }

            if (this.enabled && (cancellable == null || !cancellable.is_cancelled ()))
            {
                yield Pomodoro.DesktopExtension.get_default ().initialize (cancellable);
            }
            */
        }

        private async bool install (GLib.Cancellable? cancellable = null)
        {
            /*
            GLib.return_if_fail (this.proxy != null);

            if (cancellable != null && cancellable.is_cancelled ()) {
                return false;
            }

            var result = (string) null;

            this.proxy.install_remote_extension.begin (this.uuid, (obj, res) => {
                 try {
                    result = this.proxy.install_remote_extension.end (res);

                    GLib.debug ("Extension install result: %s", result);
                 }
                 catch (GLib.Error error) {
                     GLib.critical ("%s", error.message);
                 }

                this.install.callback ();
            });

            yield;

            return result == "successful";
            */
           return false;
        }

        private async void reload (GLib.Cancellable? cancellable = null)
        {
            /*
            GLib.return_if_fail (this.proxy != null);

            if (cancellable != null && cancellable.is_cancelled ()) {
                return;
            }

            GLib.debug ("Reloading extension…");

            var handler_id = this.proxy.extension_status_changed.connect ((uuid, state, error) => {
                if (uuid == this.uuid) {
                    this.reload.callback ();
                }
            });

            try {
                this.proxy.reload_extension (this.uuid);
            }
            catch (GLib.Error error) {
                GLib.critical ("%s", error.message);
            }

            this.proxy.disconnect (handler_id);
            */
        }

        public async bool enable (GLib.Cancellable? cancellable = null)
        {
            /*
            GLib.return_if_fail (this.proxy != null);

            var reloaded = false;

            if (this.info == null) {
                yield this.update_info (cancellable);
            }

            while (true)
            {
                yield this.update_info (cancellable);

                if (this.info.state == Gnome.ExtensionState.ENABLED) {
                    // nothing to do
                    break;
                }

                // TODO
                // if (this.info.state == Gnome.ExtensionState.DISABLED) {
                //     yield this.enable_internal (cancellable);
                // }

                if (
                    this.info.state == Gnome.ExtensionState.OUT_OF_DATE ||
                    this.info.state == Gnome.ExtensionState.ERROR
                ) {
                    if (!reloaded) {
                        yield this.reload (cancellable);
                    }
                    else {

                    }
                }

                // TODO

                // yield this.wait_for_state_change (cancellable);
            }

            if (!this.enabled) {
                this.notify_disabled ();
            }

            return this.enabled;
            */
           return false;
        }

        private void notify_out_of_date ()
        {
            GLib.return_if_fail (this.info.state == Gnome.ExtensionState.OUT_OF_DATE);

            var notification = new GLib.Notification (
                                           _("Failed to enable extension"));
            notification.set_body (_("Extension is out of date"));
            notification.add_button (_("Upgrade"), "app.visit-website");

            try {
                notification.set_icon (GLib.Icon.new_for_string (Config.PACKAGE_NAME));
            }
            catch (GLib.Error error) {
                GLib.warning (error.message);
            }

            GLib.Application.get_default ()
                            .send_notification ("extension", notification);
        }

        private void notify_error ()
        {
            GLib.return_if_fail (this.info.state == Gnome.ExtensionState.ERROR);
            GLib.return_if_fail (this.proxy != null);

            string[] errors = null;

            try {
                this.proxy.get_extension_errors (this.uuid, out errors);
            }
            catch (GLib.Error error) {
                GLib.critical (error.message);
            }

            var errors_string = string.joinv ("\n", errors);

            GLib.warning ("Extension error: %s", errors_string);

            var notification = new GLib.Notification (_("Failed to enable extension"));
            notification.set_body (errors_string);
            notification.add_button (_("Report issue"), "app.report-issue");

            try {
                notification.set_icon (GLib.Icon.new_for_string (Config.PACKAGE_NAME));
            }
            catch (GLib.Error error) {
                GLib.warning (error.message);
            }

            GLib.Application.get_default ()
                            .send_notification ("extension", notification);
        }

        private void notify_enabled ()
        {
            GLib.Application.get_default ()
                            .withdraw_notification ("extension");
        }

        private void notify_disabled ()
        {
            switch (this.info.state)
            {
                case Gnome.ExtensionState.OUT_OF_DATE:
                    this.notify_out_of_date ();
                    break;

                case Gnome.ExtensionState.ERROR:
                    this.notify_error ();
                    break;

                default:
                    break;
            }
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




        // private void on_status_changed (string uuid,
        //                                 int32  state,
        //                                 string error)
        // {
        //     if (uuid != this.uuid) {
        //         return;
        //     }
        //
        //     this.update_info ();
        //
        //     if (this.info != null)
        //     {
        //         GLib.debug ("Extension %s changed state to %s", uuid, this.info.state.to_string ());
        //
        //         this.state = this.info.state;
        //
        //         if (this.enabled) {
        //             this.notify_enabled ();
        //         }
        //     }
        // }

        // private async void eval (string            script,
        //                          GLib.Cancellable? cancellable = null)
        // {
        //     GLib.return_if_fail (this.proxy != null);

        //     if (cancellable != null && cancellable.is_cancelled ()) {
        //         return;
        //     }

        //     var handler_id = this.proxy.extension_status_changed.connect_after ((uuid, state, error) => {
        //         if (uuid == this.uuid) {
        //             this.eval.callback ();
        //         }
        //     });
        //     var cancellable_id = (ulong) 0;

        //     if (cancellable != null) {
        //         cancellable_id = cancellable.connect (() => {
        //             this.eval.callback ();
        //         });
        //     }

        //     try {
        //         var shell_proxy = GLib.Bus.get_proxy_sync<Gnome.Shell> (GLib.BusType.SESSION,
        //                                                                 "org.gnome.Shell",
        //                                                                 "/org/gnome/Shell",
        //                                                                 GLib.DBusProxyFlags.DO_NOT_AUTO_START);
        //         shell_proxy.eval (script);

        //         yield;
        //     }
        //     catch (GLib.Error error) {
        //         GLib.warning ("Failed to eval script: %s",
        //                       error.message);
        //     }

        //     if (cancellable_id != 0) {
        //         cancellable.disconnect (cancellable_id);
        //     }

        //     this.proxy.disconnect (handler_id);
        // }

//         /**
//          * GNOME Shell has no public API to enable extensions
//          */
//         private async void enable_internal (GLib.Cancellable? cancellable = null)
//         {
//             yield this.eval ("""
// (function() {
//     let uuid = '""" + this.uuid + """';
//     let enabledExtensions = global.settings.get_strv('enabled-extensions');

//     if (enabledExtensions.indexOf(uuid) == -1) {
//         enabledExtensions.push(uuid);
//         global.settings.set_strv('enabled-extensions', enabledExtensions);
//     }
// })();
// """, cancellable);
//         }

//         /**
//          * GNOME Shell may not be aware of freshly installed extension. Load it explicitly.
//          */
//         private async void load (GLib.Cancellable? cancellable = null)
//         {
//             yield this.eval ("""
// (function() {
//     let paths = [
//         global.userdatadir,
//         global.datadir
//     ];
//     let uuid = '""" + this.uuid + """';
//     let existing = ExtensionUtils.extensions[uuid];
//     if (existing) {
//         ExtensionSystem.unloadExtension(existing);
//     }
//
//     let perUserDir = Gio.File.new_for_path(global.userdatadir);
//     let type = dir.has_prefix(perUserDir) ? ExtensionUtils.ExtensionType.PER_USER
//                                           : ExtensionUtils.ExtensionType.SYSTEM;
//
//     try {
//         let extension = ExtensionUtils.createExtensionObject(uuid, dir, type);
//
//         ExtensionSystem.loadExtension(extension);
//
//         let enabledExtensions = global.settings.get_strv('enabled-extensions');
//         if (enabledExtensions.indexOf(uuid) == -1) {
//             enabledExtensions.push(uuid);
//             global.settings.set_strv('enabled-extensions', enabledExtensions);
//         }
//     } catch(e) {
//         logError(e, 'Could not load extension %s'.format(uuid));
//         return;
//     }
// })();
// """, cancellable);
//         }
