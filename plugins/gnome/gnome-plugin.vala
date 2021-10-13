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
 * Authors: Kamil Prusko <kamilprusko@gmail.com>
 *
 */

using GLib;


namespace GnomePlugin
{
    /* Leas amount of time in seconds between detected events
     * to say that user become active
     */
    private const double IDLE_MONITOR_MIN_IDLE_TIME = 0.5;

    private const string CURRENT_DESKTOP_VARIABLE = "XDG_CURRENT_DESKTOP";

    // private string get_extension_path ()
    // {
    //     if (this.is_running_from_flatpak ()) {
    //         return GLib.Path.build_filename (
    //             GLib.Environment.get_home_dir (), ".local", "share", "gnome-shell", "extensions",
    //             Config.EXTENSION_UUID);
    //     }
    //     else {
    //         return Config.EXTENSION_DIR;
    //     }
    // }

    private bool is_running_from_flatpak ()
    {
        foreach (var prefix in GLib.Environment.get_system_data_dirs ())
        {
            if (prefix == FLATPAK_DATA_DIR) {
                return true;
            }
        }

        return false;
    }


    public class ApplicationExtension : Peas.ExtensionBase, Pomodoro.ApplicationExtension, GLib.AsyncInitable
    {
        private Pomodoro.Timer                  timer;
        private GLib.Settings                   settings;
        private Pomodoro.CapabilityGroup        capabilities;
        private GnomePlugin.GnomeShellExtension shell_extension;
        private GnomePlugin.IdleMonitor         idle_monitor;
        private uint32                          become_active_id = 0;
        private bool                            can_enable = false;
        private bool                            can_install = false;
        private double                          last_activity_time = 0.0;

        construct
        {
            this.settings = Pomodoro.get_settings ().get_child ("preferences");
            this.can_enable = GLib.Environment.get_variable (CURRENT_DESKTOP_VARIABLE) == "GNOME";

            // try {
            //     this.init_async.begin (GLib.Priority.DEFAULT, null);
            // }
            // catch (GLib.Error error) {
            //     warning ("Failed to initialize ApplicationExtension");
            // }
        }

        /**
         * Extension can't be exported from the Flatpak container. So, we install it to user dir.
         */
        private void install_extension (GLib.File         destination_dir,
                                        GLib.Cancellable? cancellable = null)
        {
            var cleanup = true;
            var source_dir = GLib.File.new_for_path (Config.EXTENSION_DIR);
            var temporary_dir = GLib.File.new_for_path (GLib.DirUtils.make_tmp (null));

            info ("### temporary_dir = %s", temporary_dir.get_path ());
            info ("#### user_data_dir = %s", GLib.Envirionment.get_user_data_dir ());

            copy_recursive (
                GLib.File.new_for_path (source_path),
                GLib.File.new_for_path (temporary_dir),
                GLib.FileCopyFlags.TARGET_DEFAULT_PERMS,
                cancellable
            );
            copy_recursive (
                GLib.File.new_for_path (locale_path),
                GLib.File.new_for_path (GLib.Path.build_filename (temporary_dir, "locale")),
                GLib.FileCopyFlags.TARGET_DEFAULT_PERMS,
                cancellable
            );
            // TODO: compile and install schema?

            if (!cancellable.is_cancelled ()) {
                try {
                    temporary_dir.move (destination_dir,
                                        FileCopyFlags.OVERWRITE | FileCopyFlags.TARGET_DEFAULT_PERMS,
                                        cancellable,
                                        () => {});
                    cleanup = false;
                }
                catch (GLib.Error error) {
                    warning ("Error while moving dir: %s", error.message);
                }
            }

            if (cleanup) {
                try {
                    temporary_dir.@delete ();
                }
                catch (GLib.Error error) {
                    warning ("Failed to cleanup temporary dir: %s", error.message);
                }
            }

            // info ("get_application_name = %s", GLib.Environment.get_application_name ());
            // info ("get_current_dir = %s", GLib.Environment.get_current_dir ());
            // info ("get_home_dir = %s", GLib.Environment.get_home_dir ());
            // info ("get_host_name = %s", GLib.Environment.get_host_name ());
            // info ("get_prgname = %s", GLib.Environment.get_prgname ());

            // info ("get_system_config_dirs = %s...", string.joinv (", ", GLib.Environment.get_system_config_dirs ()));
            // info ("get_system_data_dirs = %s...", string.joinv (", ", GLib.Environment.get_system_data_dirs ()));

            // info ("get_user_cache_dir = %s", GLib.Environment.get_user_cache_dir ());
            // info ("get_user_config_dir = %s", GLib.Environment.get_user_config_dir ());
            // info ("get_user_data_dir = %s", GLib.Environment.get_user_data_dir ());
            // info ("get_user_name = %s", GLib.Environment.get_user_name ());
            // info ("get_user_runtime_dir = %s", GLib.Environment.get_user_runtime_dir ());
        }

        public async bool init_async (int               io_priority = GLib.Priority.DEFAULT,
                                      GLib.Cancellable? cancellable = null)
                                      throws GLib.Error
        {
            var application = Pomodoro.Application.get_default ();

            /* Mutter IdleMonitor */
            if (this.idle_monitor == null) {
                this.capabilities = new Pomodoro.CapabilityGroup ("gnome");

                try {
                    // TODO: idle-monitor should be initialized as async
                    this.idle_monitor = new GnomePlugin.IdleMonitor ();

                    this.timer = Pomodoro.Timer.get_default ();
                    this.timer.state_changed.connect_after (this.on_timer_state_changed);

                    this.capabilities.add (new Pomodoro.Capability ("idle-monitor"));

                    application.capabilities.add_group (this.capabilities, Pomodoro.Priority.HIGH);
                }
                catch (GLib.Error error) {
                    // Gnome.IdleMonitor not available
                }
            }

            /* GNOME Shell extension */
            var expected_extension_dir = File.new_for_path (
                    is_running_from_flatpak ()
                    ? GLib.Path.build_filename (
                          GLib.Environment.get_home_dir (), ".local", "share", "gnome-shell", "extensions",
                          Config.EXTENSION_UUID)
                    : Config.EXTENSION_DIR
                );

            // TODO: check if gnome shell allows extensions at all

            if (this.can_enable && this.shell_extension == null)
            {
                // TODO: ask before installing extension
                // if (this.can_install && !expected_extension_dir.query_exists (cancellable)) {
                //     this.install_extension (expected_extension_dir, cancellable);
                // }

                this.shell_extension = new GnomePlugin.GnomeShellExtension (Config.EXTENSION_UUID);

                // fetch extension state
                yield this.shell_extension.init_async (GLib.Priority.DEFAULT, cancellable);

                this.can_install = (
                    is_running_from_flatpak () && this.shell_extension.can_install
                );


                if (this.shell_extension.path != expected_extension_dir) {
                    //
                }

                if (this.shell_extension.status == Gnome.ExtensionState.UNINSTALLED) {
                    // extension may have been freshly installed and GNOME Shell is not aware of it
                    yield this.shell_extension.load ();
                }
                else if (this.shell_extension.version != Config.EXTENSION_VERSION) {
                    // extension has been found, but looks like it's for older release
                    yield this.shell_extension.reload ();
                }

                // if we're runing from flatpak, extension needs to be installed
                // TODO: show a dialog and ask whether to install the extension
                if (this.shell_extension.status == Gnome.ExtensionState.UNINSTALLED) {
                    yield this.shell_extension.install ();
                }

                if (this.shell_extension.path != Config.EXTENSION_DIR) {
                    yield this.shell_extension.load ();
                }

                this.shell_extension = new GnomePlugin.GnomeShellExtension (Config.EXTENSION_UUID,


                // TODO: don't try enabling extension
                // if (this.shell_extension.status == Gnome.ExtensionState.DISABLED) {
                //    yield this.shell_extension.enable ();
                // }

                // if missing, try to install
                // if (this.is_running_from_flatpak ())
                // {
                    // TODO: show a dialog before installing
                //     if (this.shell_extension.info.state == Gnome.ExtensionState.UNINSTALLED)
                //     {
                //         this.install_extension ();
                //     }

                // TODO: show a dialog before updating
                //     if (this.shell_extension.info.state == Gnome.ExtensionState.OUT_OF_DATE)
                //     {
                //         this.install_extension ();
                //     }
                // }

                // var enabled = yield this.shell_extension.enable (cancellable);
            }

            return true;
        }

        ~ApplicationExtension ()
        {
            this.timer.state_changed.disconnect (this.on_timer_state_changed);

            if (this.become_active_id != 0) {
                this.idle_monitor.remove_watch (this.become_active_id);
                this.become_active_id = 0;
            }
        }

        private void on_shell_mode_changed ()
        {
            // TODO
        }

        private void on_timer_state_changed (Pomodoro.TimerState state,
                                             Pomodoro.TimerState previous_state)
        {
            if (this.become_active_id != 0) {
                this.idle_monitor.remove_watch (this.become_active_id);
                this.become_active_id = 0;
            }

            if (state is Pomodoro.PomodoroState &&
                previous_state is Pomodoro.BreakState &&
                previous_state.is_completed () &&
                this.settings.get_boolean ("pause-when-idle"))
            {
                this.become_active_id = this.idle_monitor.add_user_active_watch (this.on_become_active);

                this.timer.pause ();
            }
        }

        /**
         * on_become_active callback
         *
         * We want to detect user/human activity so it sparse events.
         */
        private void on_become_active (GnomePlugin.IdleMonitor monitor,
                                       uint32                  id)
        {
            var timestamp = Pomodoro.get_current_time ();

            if (timestamp - this.last_activity_time < IDLE_MONITOR_MIN_IDLE_TIME) {
                this.become_active_id = 0;

                this.timer.resume ();
            }
            else {
                this.become_active_id = this.idle_monitor.add_user_active_watch (this.on_become_active);
            }

            this.last_activity_time = timestamp;
        }
    }

    public class PreferencesDialogExtension : Peas.ExtensionBase, Pomodoro.PreferencesDialogExtension
    {
        private Pomodoro.PreferencesDialog dialog;

        private GLib.Settings settings;
        private GLib.List<Gtk.ListBoxRow> rows;

        construct
        {
            this.settings = new GLib.Settings ("org.gnomepomodoro.Pomodoro.plugins.gnome");
            this.dialog = Pomodoro.PreferencesDialog.get_default ();

            this.setup_main_page ();
        }

        private void setup_main_page ()
        {
            var main_page = this.dialog.get_page ("main") as Pomodoro.PreferencesMainPage;

            var hide_system_notifications_toggle = new Gtk.Switch ();
            hide_system_notifications_toggle.valign = Gtk.Align.CENTER;

            var row = this.create_row (_("Hide other notifications"),
                                       hide_system_notifications_toggle);
            row.name = "hide-system-notifications";
            main_page.lisboxrow_sizegroup.add_widget (row);
            main_page.desktop_listbox.add (row);
            this.rows.prepend (row);

            this.settings.bind ("hide-system-notifications",
                                hide_system_notifications_toggle,
                                "active",
                                GLib.SettingsBindFlags.DEFAULT);
        }

        ~PreferencesDialogExtension ()
        {
            foreach (var row in this.rows) {
                row.destroy ();
            }

            this.rows = null;
        }

        private Gtk.ListBoxRow create_row (string     label,
                                           Gtk.Widget widget)
        {
            var name_label = new Gtk.Label (label);
            name_label.halign = Gtk.Align.START;
            name_label.valign = Gtk.Align.BASELINE;

            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            box.pack_start (name_label, true, true, 0);
            box.pack_start (widget, false, true, 0);

            var row = new Gtk.ListBoxRow ();
            row.activatable = false;
            row.selectable = false;
            row.add (box);
            row.show_all ();

            return row;
        }
    }
}


[ModuleInit]
public void peas_register_types (GLib.TypeModule module)
{
    var object_module = module as Peas.ObjectModule;

    object_module.register_extension_type (typeof (Pomodoro.ApplicationExtension),
                                           typeof (GnomePlugin.ApplicationExtension));

    object_module.register_extension_type (typeof (Pomodoro.PreferencesDialogExtension),
                                           typeof (GnomePlugin.PreferencesDialogExtension));
}
