//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import "panels"
import "widgets"
import "services"

ShellRoot {
    Variants {
        model: Quickshell.screens
        Bar {}
    }
    Variants {
        model: Quickshell.screens
        OutsideDismiss {}
    }

    Launcher {}
    ClipboardPanel {}
    NotificationCenter {}
    AudioPanel {}
    PowerPanel {}
    NetworkPanel {}
    MenuPanel {}
    SessionMenu {}
    ThemePanel {}
    WallpaperPanel {}
    Toasts {}

    IpcHandler {
        target: "shell"
        function menu(): void { ShellState.toggle("menu"); }
        function session(): void { ShellState.toggle("session"); }
        function launcher(): void { ShellState.toggle("launcher"); }
        function clipboard(): void { ShellState.toggle("clipboard"); }
        function notifications(): void { ShellState.toggle("notifications"); }
        function audio(): void { ShellState.toggle("audio"); }
        function power(): void { ShellState.toggle("power"); }
        function network(): void { ShellState.toggle("network"); }
        function close(): void { ShellState.close(); }
        function dnd(): void { Notifications.doNotDisturb = !Notifications.doNotDisturb; }
    }
}
