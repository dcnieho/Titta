
import argparse
import os
import shutil
import subprocess
import tempfile

def run_command(cmd):
    result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"Command failed: {' '.join(cmd)}\n{result.stderr}")
    return result.stdout

def extract_symbols(dll_path, arch):
    dumpbin_cmd = ['dumpbin', '/EXPORTS', dll_path]
    if arch:
        dumpbin_cmd.insert(1, f'/{arch}')
    output = run_command(dumpbin_cmd)

    symbols = []
    for line in output.splitlines():
        parts = line.strip().split()
        if len(parts) >= 4 and parts[0].isdigit():
            symbols.append(parts[-1])
    return symbols

def generate_def_file(symbols, dll_name, def_path):
    with open(def_path, 'w') as f:
        f.write(f"LIBRARY {dll_name}\n")
        f.write("EXPORTS\n")
        for symbol in symbols:
            f.write(f"  {symbol}\n")

def generate_lib_file(def_path, lib_path, arch):
    lib_cmd = ['lib', f'/DEF:{def_path}', f'/OUT:{lib_path}']
    if arch:
        lib_cmd.append(f'/MACHINE:{arch}')
    run_command(lib_cmd)

def main():
    parser = argparse.ArgumentParser(description="Rename a DLL and regenerate its .lib file.")
    parser.add_argument("src", help="Source DLL file")
    parser.add_argument("dest", help="Destination DLL file")
    parser.add_argument("--arch", choices=["x86", "x64", "arm", "arm64"], help="Target architecture")
    args = parser.parse_args()

    src = os.path.abspath(args.src)
    dest = os.path.abspath(args.dest)
    dest_name = os.path.basename(dest)

    with tempfile.TemporaryDirectory() as tmpdir:
        def_path = os.path.join(tmpdir, "temp.def")
        lib_path = os.path.splitext(dest)[0] + ".lib"

        symbols = extract_symbols(src, args.arch)
        generate_def_file(symbols, dest_name, def_path)
        generate_lib_file(def_path, lib_path, args.arch)

    shutil.move(src, dest)
    print(f"Renamed {src} to {dest} and generated {lib_path}")

if __name__ == "__main__":
    main()
