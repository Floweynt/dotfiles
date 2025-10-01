import subprocess
import sys
import time

class ProxyStartError(Exception):
    def __init__(self, message: str, command: str | None = None):
        super().__init__(message)
        self.command = command
        self.message = message

def setup_tunnel():
    cmd = "ip route add local default dev lo table 100"
    res = subprocess.run(cmd.split(" "), capture_output=True)
    if res.returncode != 0:
        if res.stderr.decode().strip() == "RTNETLINK answers: File exists":
            return
        raise ProxyStartError(f"failed to create tunnel (exit code {res.returncode}: {res.stderr.decode().strip()}", cmd)

    cmd = "ip rule add fwmark 0x01 lookup 100"
    res = subprocess.run(cmd.split(" "), capture_output=True)
    if res.returncode != 0:
        raise ProxyStartError(f"failed to create tunnel (exit code {res.returncode}): {res.stderr.decode().strip()}", cmd)

def main0():
    print("[Proxystart] setting up web tunneling...")
    setup_tunnel()
    print("[Proxystart] use [Ctrl-C] to restart proxy")
    print("[Proxystart] use [Ctrl-C] twice in quick succession to quit")

    while True:
        try:
            print("[Proxystart] starting proxy")
            subprocess.run([
                "sshuttle",
                "--no-latency-control",
                "-r",
                "yagoo@72.14.190.235:443",
                "0/0",
                "-x",
                "72.14.190.235",
                "--dns",
                "--method",
                "tproxy",
                "-e",
                "ssh -i /home/flowey/.ssh/yagoo_rsa"
            ])
            time.sleep(1)
        except KeyboardInterrupt:
            try:
                print("[Proxystart] restarting proxy...")
                time.sleep(1)
            except KeyboardInterrupt:
                break

def main():
    try:
        main0()
    except ProxyStartError as err:
        if err.command is not None:
            print(f"[Proxystart] while running command {err.command}:", file=sys.stderr)
        print(f"[Proxystart] error: {err.message}", file=sys.stderr)


if __name__ == "__main__":
    main()
