import os

def setup_pluto():
    def _get_pluto_cmd(port):
        return ["julia", "-e", "import Pluto; Pluto.run(host=\"127.0.0.1\", port=" + str(port) + ", launch_browser=false, require_secret_for_access=false)"]

    return {
        "command": _get_pluto_cmd,
        "timeout": 60,
        "new_browser_tab": True
    }
