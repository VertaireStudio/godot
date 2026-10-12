#!/usr/bin/env python3
"""Compute the enabled module list for the Godot CMake port.

Mirrors the relevant parts of SConstruct's module detection + enablement so the
CMake build generates `modules_enabled.gen.h` / `register_module_types.gen.cpp`
with the same module set a SCons build would use. Invoked once at CMake
configure time; prints the enabled module names, one per line, to stdout.
"""

import json
import os
import sys
from collections import OrderedDict

GODOT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, GODOT_ROOT)

PLATFORM = "linuxbsd"
ARCH = "x86_64"
TARGET = "editor"


def detect_modules(search_path):
    modules = OrderedDict()

    def is_module(path):
        if not os.path.isdir(path):
            return False
        return all(
            os.path.exists(os.path.join(path, f))
            for f in ("register_types.h", "SCsub", "config.py")
        )

    def add_module(path):
        modules[os.path.basename(path)] = path.replace("\\", "/")

    if not is_module(search_path):
        for path in sorted(os.listdir(search_path)):
            full = os.path.join(search_path, path)
            if is_module(full):
                add_module(full)
    else:
        add_module(search_path)
    return modules


class Env(dict):
    def module_add_dependencies(self, module, deps, optional=False):
        pass

    def module_check_dependencies(self, module):
        return True

    def __getattr__(self, item):
        try:
            return self[item]
        except KeyError:
            raise AttributeError(item)


def main():
    # Minimal env with the defaults a linuxbsd x86_64 editor build uses.
    env = Env(
        {
            "platform": PLATFORM,
            "arch": ARCH,
            "target": TARGET,
            "editor_build": TARGET == "editor",
            "dev_build": False,
            "module_dependencies": {},
            "minizip": True,
            "disable_3d": False,
            "disable_advanced_gui": False,
            "disable_physics_2d": False,
            "disable_physics_3d": False,
            "disable_navigation_2d": False,
            "disable_navigation_3d": False,
            "disable_xr": False,
            "vulkan": True,
            "opengl3": True,
            "sdl": True,
            "tests": False,
        }
    )

    modules_detected = detect_modules(os.path.join(GODOT_ROOT, "modules"))

    enabled = OrderedDict()
    doc_class_path = {}

    # Platform doc classes (platform/*/detect.py get_doc_classes/get_doc_path).
    for plat in sorted(os.listdir(os.path.join(GODOT_ROOT, "platform"))):
        plat_dir = os.path.join(GODOT_ROOT, "platform", plat)
        if not os.path.isdir(plat_dir):
            continue
        doc_dir = os.path.join(plat_dir, "doc_classes")
        if os.path.isdir(doc_dir):
            for xml in os.listdir(doc_dir):
                if xml.endswith(".xml"):
                    cls = xml[: -len(".xml")]
                    doc_class_path[cls] = f"platform/{plat}/doc_classes"

    for name, path in modules_detected.items():
        full = os.path.join(GODOT_ROOT, "modules", name)
        sys.path.insert(0, full)
        try:
            import config  # noqa

            is_en = True
            try:
                is_en = config.is_enabled()
            except AttributeError:
                is_en = True

            can = True
            if is_en:
                try:
                    can = config.can_build(env, PLATFORM)
                except Exception:
                    can = False

            if is_en and can:
                enabled[name] = os.path.join("modules", name)
                # Module doc classes (get_doc_classes/get_doc_path).
                try:
                    doc_dir_rel = config.get_doc_path()
                    classes = config.get_doc_classes()
                    doc_abs = os.path.join(GODOT_ROOT, "modules", name, doc_dir_rel)
                    if os.path.isdir(doc_abs):
                        for c in classes:
                            doc_class_path[c] = f"modules/{name}/{doc_dir_rel}"
                except AttributeError:
                    pass
                except Exception:
                    pass
        finally:
            sys.path.pop(0)
            sys.modules.pop("config", None)

    print(json.dumps({"modules": enabled, "doc_class_path": doc_class_path}))
    return 0


if __name__ == "__main__":
    sys.exit(main())