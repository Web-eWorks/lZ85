#!/usr/bin/lua

local z85 = require 'z85'

local dat_1 = "\x86\x4F\xD2\x6F\xB5\x59\xF7\x5B"

local dat_2 = 
	"\x8E\x0B\xDD\x69\x76\x28\xB9\x1D" ..
    "\x8F\x24\x55\x87\xEE\x95\xC5\xB0" ..
    "\x4D\x48\x96\x3F\x79\x25\x98\x77" ..
	"\xB4\x9C\xD9\x06\x3A\xEA\xD3\xB7"

local enc_1 = "HelloWorld"
local enc_2 = "JTKVSB%%)wK0E.X)V>+}o?pNmC{O&4W4b!Ni{Lh6"

local function format_dat(d)
	local s = ""
	for i=1, #d do
		s = s .. string.format("\\x%.2X", d:sub(i):byte())
	end
	return s
end

local function check(cond, msg)
	if not cond then
		io.stderr:write("\n" .. msg .. "\n")
		os.exit(128)
	end
	return cond
end

local enc, dec

print("Encode 1 ->")
enc = assert(z85.encode(dat_1))
print("Input:  " .. format_dat(dat_1))
print("Target: " .. enc_1)
if enc == enc_1 then
	print("Status: Successful")
else
	print("Output: " .. enc)
	print("Status: Failed!")
end
print("")

print("Decode 1 <-")
dec = assert(z85.decode(enc))
print("Input:  " .. enc)
print("Target: " .. format_dat(dat_1))
if dec == dat_1 then
	print("Status: Successful")
else
	print("Output: " .. format_dat(dec))
	print("Status: Failed!")
end
print("")

print("Encode 2 ->")
enc = assert(z85.encode(dat_2))
print("Input:  " .. format_dat(dat_2))
print("Target: " .. enc_2)
if enc == enc_2 then
	print("Status: Successful")
else
	print("Output: " .. enc)
	print("Status: Failed!")
end
print("")

print("Decode 2 <-")
dec = assert(z85.decode(enc))
print("Input:  " .. enc)
print("Target: " .. format_dat(dat_2))
if dec == dat_2 then
	print("Status: Successful")
else
	print("Output: " .. format_dat(dec))
	print("Status: Failed!")
end
