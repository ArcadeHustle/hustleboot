require 'rubygems'
require 'binascii'
require 'socket'
require 'zlib'

NOP = [0x10000000].pack('I') # Seen as a prefix to Reset command, and Check On / Off commands. 

def Check_OnOff(state)
	if state = "On"
		# 1a00 8104 0100 0000 f0ff fe3f 0000 0000 0000 0000 0000 0000 0000 0000 0000 # Check On - 0x4018001a
		packet = [0x4018001a,0x0000f0ff,0xfe3f0000, 0xffffffff, 0xffffffff, 0x00000000, 0x00000000].pack('IIIIIII')
	elsif state = "Off"
		# 1a00 8104 0100 0000 f0ff fe3f 0000 ffff ffff ffff ffff 0000 0000 0000 0000 # Check Off -  0x4018001a
		packet = [0x4018001a,0x0000f0ff,0xfe3f0000, 0x00000000, 0x00000000, 0x00000000, 0x00000000].pack('IIIIIII')
	end
	return packet
end

DIMM_GetInformation = [0x18000000].pack('I') # readsocket(0x10) 
HOST_SetMode = [0x07000004, 0x00000001].pack('II')
SECURITY_SetKeycode = [0x7F000008,0x00000000, 0x00000000].pack('III')

DIMM_Upload = [0x04800000].pack('I')

# Python and Ruby both handle the logical OR the same way. 
# 
# >>> struct.pack("<I", 0x04800000 |  10+0xA | (0 << 16))
# '\x14\x00\x80\x04'

# irb(main):003:0> [0x04800000 |  10+0xA | (0 << 16)].pack('I')
# => "\x14\x00\x80\x04"

HOST_Restart = [0x0A000000].pack('I')
DIMM_SetInformation = [0x1900000C].pack('I')  # Don't do this if you don't want it checked? 
TIME_SetLimit = [0x17000004, ].pack('I') # 10*60*1000 - 600000 - 0x927C0

t = TCPSocket.new(ARGV[0], "10703")

#t.write(DIMM_GetInformation)
#resp = t.read(0x10)
#puts(Binascii.hexlify(resp))

# 0400 0007 0100 0000 # Setmode 0, 1 - 0x07000004
t.write(HOST_SetMode)

# 0800 007f 0000 0000 0000 0000 # Set Key to eight zeros - 0x7F000008
t.write(SECURITY_SetKeycode)


crc = 0
addr = 0

class File
  def each_chunk(chunk_size = 0x8000)
    yield read(chunk_size) until eof?
  end
end

open("rom", "rb") do |f|
	f.each_chunk { |chunk| 
		puts(printf("Addr: %08x\r", addr))  
		addr += chunk.length
		crc = Zlib::crc32(chunk, crc)
		puts(printf("crc: %08x\r", crc))
	}
#	crc = ~crc # Invert CRC?
#	puts(printf("crc: %08x\r", crc))
end

#t.write(DIMM_SetInformation)

# 0000 000a # Reset Naomi - 0x0A000000
#t.write(HOST_Restart)


# 0a80 8004 0000 0000 0000 0000 0000 <file contents> # Upload file - 0x04800000

# sh-3.2# nc -l 10703 | xxd 
# 
# 00000000: 0400 0007 0100 0000 0800 007f 0000 0000  ................
# 00000010: 0000 0000 1c00 8004 0000 0000 0000 0000  ................
# 00000020: 0000 4141 4141 4141 4141 4141 4141 4141  ..AAAAAAAAAAAAAA
# 00000030: 4141 410a 1300 8104 0000 0000 1200 0000  AAA.............
# 00000040: 0000 3132 3334 3536 3738 000c 0000 19c2  ..12345678......
# 00000050: dc6a a112 0000 0000 0000 0000 0000 0a04  .j..............
# 00000060: 0000 17c0 2709 0004 0000 17c0 2709 0004  ....'.......'...
# 00000070: 0000 17c0 2709 0004 0000 17c0 2709 0004  ....'.......'...
# 00000080: 0000 17c0 2709 0004 0000 17c0 2709 0004  ....'.......'...
# 00000090: 0000 17c0 2709 0004 0000 17c0 2709 0004  ....'.......'...
# 000000a0: 0000 17c0 2709 0004 0000 17c0 2709 0004  ....'.......'...
# 000000b0: 0000 17c0 2709 0004 0000 17c0 2709 0004  ....'.......'...
# 000000c0: 0000 17c0 2709 0004 0000 17c0 2709 00    ....'.......'..


