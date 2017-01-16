--[[
	**lZ85** is a Lua implementation of the
	[ZeroMQ 32/Z85 specification][32/Z85] for string-encoding binary data
	in an interchange-suitable format.

	## The Spec:

	A Z85 implementation takes a binary frame and encodes it as a
	printable ASCII string, or takes an ASCII encoded string and decodes
	it into a binary frame.

	The binary frame SHALL have a length that is divisible by 4 with no
	remainder. The string frame SHALL have a length that is divisible by
	5 with no remainder. It is up to the application to ensure that frames
	and strings are padded if necessary.

	### Test Case

	As a test case, a frame containing these 8 bytes:

		+------+------+------+------+------+------+------+------+
		| 0x86 | 0x4F | 0xD2 | 0x6F | 0xB5 | 0x59 | 0xF7 | 0x5B |
		+------+------+------+------+------+------+------+------+

	SHALL encode as the following 10 characters:

		+---+---+---+---+---+---+---+---+---+---+
		| H | e | l | l | o | W | o | r | l | d |
		+---+---+---+---+---+---+---+---+---+---+

	[32/Z85]: https://rfc.zeromq.org/spec:32/Z85/

	## Legal:

	Copyright &copy; 2017 [Webster Sheets](mailto:webster@web-eworks).

	__lZ85__ is Free Software under the terms of the MIT License.

	This software is inspired from and includes portions of the ZeroMQ Z85
	Reference Implementation; Copyright &copy; 2010-2013 iMatix Corporation
	and Contributors, under the terms of the [MIT License][ref-license].

	[ref-license]: https://github.com/zeromq/rfc/blob/master/src/spec_32.c

--]]

--- Copyright (c) 2017 Webster Sheets <webster@web-eworks.com>
--- lZ85 is Free Software under the terms of the MIT License.

local z85 = {}

-- ## The Implementation:
--
-- The values for 0-84 are all represented in this string.
--
-- From the spec:
-- > The encoding and decoding SHALL use this representation for each
-- > base-85 value from zero to 84:
z85.enc =
	"0123456789" ..
	"abcdefghij" ..
	"klmnopqrst" ..
	"uvwxyzABCD" ..
	"EFGHIJKLMN" ..
	"OPQRSTUVWX" ..
	"YZ.-:+=^!/" ..
	"*?&<>()[]{" ..
	"}@%$#"

-- We precache divisors for the encoding and decoding steps
-- so we're not doing unecessary exponentiation and division
-- every step of every loop.
z85.enc_div = {
	85 * 85 * 85 * 85,
	85 * 85 * 85,
	85 * 85,
	85, 1
}

z85.dec_div = {
	256 * 256 * 256,
	256 * 256,
	256, 1
}

-- The official decoding key, stolen straight from the reference
-- implementation.
z85.dec = {
	0x00, 0x44, 0x00, 0x54, 0x53, 0x52, 0x48, 0x00,
	0x4B, 0x4C, 0x46, 0x41, 0x00, 0x3F, 0x3E, 0x45,
	0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
	0x08, 0x09, 0x40, 0x00, 0x49, 0x42, 0x4A, 0x47,
	0x51, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2A,
	0x2B, 0x2C, 0x2D, 0x2E, 0x2F, 0x30, 0x31, 0x32,
	0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3A,
	0x3B, 0x3C, 0x3D, 0x4D, 0x00, 0x4E, 0x43, 0x00,
	0x00, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10,
	0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18,
	0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F, 0x20,
	0x21, 0x22, 0x23, 0x4F, 0x00, 0x50, 0x00, 0x00
}

-- A simple pyramid string-builder function, for performance
-- with large strings.
local function pyramid(t, dat)
	t[#t + 1] = dat
	local t_len, t_len1 = #t, #t-1
	while t[t_len1] and #t[t_len] > #t[t_len1] do
		t[t_len1] = t[t_len1] .. t[t_len]
		t[t_len] = nil
		t_len, t_len1 = t_len1, t_len1-1
	end
end

-- At the end of a encode/decode, we need to collapse a pyramid
-- down to a single value.
local function collapse(t)
	while #t > 1 do
		local t_len, t_len1 = #t, #t-1
		t[t_len1] = t[t_len1] .. t[t_len]; t[t_len] = nil
	end
	return t[1]
end

-- Encode a binary string into Z85.
-- The length of the input string must be a multiple of 4.
--
-- Parameters:
--
-- * `bin_str`: the binary string to encode
-- * `len`: how many bytes to encode.
--    Defaults to the length of the string.
function z85.encode(bin_str, len)
	len = tonumber(len) or #bin_str
	if len % 4 > 0 then
		return nil, "Binary data must to be padded to modulo 4!"
	end

	local encoded_len = len * 5 // 4
	local encoded_t = {}

	local accum = 0
	for i = 1, len do
		local next = bin_str:sub(i):byte()
		accum = (accum << 8) + next

		if i % 4 == 0 then
			for i=1, 5 do
				local idx = accum // z85.enc_div[i] % 85 + 1
				pyramid(encoded_t, z85.enc:sub(idx, idx))
			end
			accum = 0
		end
	end

	local encoded = collapse(encoded_t)
	assert(#encoded == encoded_len, "Algorithm error! " .. #encoded .. ", " .. encoded_len)

	return encoded
end

-- Decode a Z85 string into a binary string.
-- The length of the input string must be a multiple of 5.
--
-- Parameters:
--
-- * `txt_str`: The Z85-encoded string to decode.
-- * `len`: the number of bytes of the string to decode.
--    Defaults to the length of the string.
function z85.decode(txt_str, len)
	len = tonumber(len) or #txt_str
	if len % 5 > 0 then
		return nil, "Encoded data size must be a multiple of 5!"
	end

	local decoded_len = len * 4 // 5
	local decoded_t = {}

	local accum = 0
	for i = 1, len do
		local next = txt_str:sub(i):byte() - 32
		accum = accum * 85 + (z85.dec[next+1])

		if i % 5 == 0 then
			for i = 1, 4 do
				local v = accum // z85.dec_div[i] % 256
				pyramid(decoded_t, string.char(v))
			end
			accum = 0
		end
	end

	local decoded = collapse(decoded_t)
	assert(#decoded == decoded_len, "Algorithm error! " .. #decoded .. ", " .. decoded_len)

	return decoded
end

return z85
