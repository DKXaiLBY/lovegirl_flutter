# -*- coding: utf-8 -*-
"""扫心情日记页导航结构 + 谁打开了它。"""
import io
import re
import subprocess
import sys

sys.stdout.reconfigure(encoding="utf-8")
src = io.open(
    r"D:\Projects\Personal\lovegirl\lib\screens\mood\mood_screen.dart",
    encoding="utf-8").read().splitlines()
print("total", len(src))
for i, l in enumerate(src, 1):
    if re.search(r"class |Widget build|appBar|backgroundColor|Scaffold\(|Navigator|pop|back|Leading|onPressed|Stack|Positioned", l):
        print(i, l.rstrip()[:110])

print("==== 谁打开了 MoodScreen ====")
GIT = r"D:\SoftwarePrograms\01-开发工具\Git Setup\Git\cmd\git.exe"
out = subprocess.run([GIT, "grep", "-n", "MoodScreen", "--", "lib"],
                     cwd=r"D:\Projects\Personal\lovegirl",
                     capture_output=True, text=True, encoding="utf-8").stdout
print(out)
