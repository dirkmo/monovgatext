#!/usr/bin/env python3

s = "Hallo Welt!"

bitwidth = 16

count = 0
with open("screen.mem", "w") as f:
    for c in s:
        count = count + 1
        f.write(f"{ord(c):02x}")
        if bitwidth == 8 or count%2==0:
            f.write(f" ")

    while count < 2400:
        count = count + 1
        f.write("00")
        if bitwidth == 8 or count%2==0:
            f.write(f" ")
