"""
    build.py
    Nokutoka Momiji

    A small script I made to make building the program for release easier in my machine.
    This script is not really cross-platform, and was built with the intention of
    being run in my Windows machine.
"""

import os
import sys
from colorama import Fore

OLD_VERSION = "1.1.1"

VERSION_MAJOR = 'M'
VERSION_MINOR = 'm'
VERSION_REVISION = 'r'

def log(msg: str):
    """
        Just logs a message to the console.

    Args:
        msg (``str``): The message to log in the console.
    """
    print(f"[{Fore.BLUE}INFO{Fore.RESET}]: {msg}")

def get(list_ref: list, index: int, default = None):
    """Returns an item from a list at a given index, if it exists.
        if it doesn't, it returns the default value.

    Args:
        - list_ref (``list``): List to retrieve the item from.
        - index (``int``): Index of the item in the list.
        - default (``Any``, optional): A default value that will be returned if there is no item at the given index. Defaults to None.

    Returns:
        Any: Item.
    """
    if index >= len(list_ref):
        return default

    return list_ref[index]

def build():
    """Builds the Flutter app."""
    try:
        log("Building Android APK.")
        if os.system("flutter build apk") == 0:
            os.system(r"explorer .\build\app\outputs\flutter-apk")

        log("Building Windows executable.")
        if os.system("flutter build windows") == 0:
            os.system(r"explorer .\build\windows\x64\runner\Release")

        os.system("taskkill /F /IM java.exe")
        os.system("taskkill /F /IM adb.exe")
    except KeyboardInterrupt:
        log("User cancelled the build process. Exiting...")

def update_version() -> str:
    major, minor, revision = OLD_VERSION.split(".")
    change_type = get(sys.argv, 1, VERSION_REVISION)

    if change_type == VERSION_REVISION:
        return f"{major}.{minor}.{int(revision) + 1}"
    
    if change_type == VERSION_MINOR:
        return f"{major}.{int(minor) + 1}.0"

    if change_type == VERSION_MAJOR:
        return f"{int(major) + 1}.0.0"
    
    raise ValueError(f"\"{change_type}\" is an invalid argument. Valid arguments are 'M', 'm' and 'r'.")

def replace_version_on_spec(new_version: str):
    old_version_string = f"version: {OLD_VERSION}"
    new_version_string = f"version: {new_version}"

    log(f"Opening {Fore.LIGHTYELLOW_EX}pubspec.yaml{Fore.RESET}")

    with open("pubspec.yaml", "r", encoding = "utf-8") as f:
        data = f.read()

    log(f"Replacing {Fore.LIGHTRED_EX}{old_version_string}{Fore.RESET} with {Fore.LIGHTGREEN_EX}{new_version_string}{Fore.RESET}")
    data = data.replace(old_version_string, new_version_string)

    with open("pubspec.yaml", "w", encoding = "utf-8") as f:
        f.write(data)

def replace_version_on_about(new_version: str):
    old_version_string = f"applicationVersion: \"{OLD_VERSION}\""
    new_version_string = f"applicationVersion: \"{new_version}\""

    log(f"Opening {Fore.LIGHTYELLOW_EX}lib/about.dart{Fore.RESET}")

    with open("lib/about.dart", "r", encoding = "utf-8") as f:
        data = f.read()

    log(f"Replacing {Fore.LIGHTRED_EX}{old_version_string}{Fore.RESET} with {Fore.LIGHTGREEN_EX}{new_version_string}{Fore.RESET}")
    data = data.replace(old_version_string, new_version_string)

    with open("lib/about.dart", "w", encoding = "utf-8") as f:
        f.write(data)

def replace_version_on_script(new_version: str):
    old_version_string = f"OLD_VERSION = \"{OLD_VERSION}\""
    new_version_string = f"OLD_VERSION = \"{new_version}\""

    log(f"Opening {Fore.LIGHTYELLOW_EX}{__file__}{Fore.RESET}")

    with open(__file__, "r", encoding = "utf-8") as f:
        data = f.read()

    log(f"Replacing {Fore.LIGHTRED_EX}{old_version_string}{Fore.RESET} with {Fore.LIGHTGREEN_EX}{new_version_string}{Fore.RESET}")
    data = data.replace(old_version_string, new_version_string)

    with open(__file__, "w", encoding = "utf-8") as f:
        f.write(data)

def main():
    if get(sys.argv, 1) == "noup":
        log(f"Nokubooru {Fore.LIGHTMAGENTA_EX}{OLD_VERSION}{Fore.RESET}")
    else:
        new_version = update_version()

        log(f"Nokubooru {Fore.LIGHTRED_EX}{OLD_VERSION}{Fore.RESET} -> {Fore.LIGHTGREEN_EX}{new_version}{Fore.RESET}")
    
        replace_version_on_spec(new_version)
        replace_version_on_about(new_version)
        replace_version_on_script(new_version)

    build()

if __name__ == "__main__":
    main()
