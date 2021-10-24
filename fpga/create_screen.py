#!/usr/bin/env python3

s = "Hallo Welt!"

count = 0
with open("screen.mem", "w") as f:
    for c in s:
        count = count + 1
        f.write(f"{ord(c):02x} ")
    while count < 2400:
        count = count + 1
        f.write("00 ")