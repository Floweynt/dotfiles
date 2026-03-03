import os
import sys
import json
import hashlib

SOURCE_EXTS = {".c", ".cc", ".cpp", ".cxx", ".m", ".mm"}


def is_source_file(path: str) -> bool:
    return os.path.splitext(path)[1] in SOURCE_EXTS


def mangle(path: str) -> str:
    # stable mangled artifact name based on file path
    h = hashlib.sha1(path.encode()).hexdigest()[:12]
    base = os.path.basename(path)
    return f"{base}.{h}.o"


def main():
    if len(sys.argv) < 2:
        print("usage: gen_cdb.py <source-dir> [cc args...]")
        sys.exit(1)

    src_dir = os.path.abspath(sys.argv[1])
    cc_args = sys.argv[2:]

    cwd = os.getcwd()
    build_dir = os.path.join(cwd, "build")
    os.makedirs(build_dir, exist_ok=True)

    entries = []

    for root, _, files in os.walk(src_dir):
        for name in files:
            if not is_source_file(name):
                continue

            file_path = os.path.abspath(os.path.join(root, name))
            artifact = mangle(file_path)
            output_path = os.path.join(build_dir, artifact)

            cmd = (
                "clang "
                + file_path
                + " -c -o "
                + output_path
                + (" " + " ".join(cc_args) if cc_args else "")
            )

            entries.append(
                {
                    "directory": cwd,
                    "file": file_path,
                    "command": cmd,
                    "output": output_path,
                }
            )

    with open("compile_commands.json", "w") as f:
        json.dump(entries, f, indent=4)

    print(f"wrote {len(entries)} entries to compile_commands.json")


if __name__ == "__main__":
    main()
