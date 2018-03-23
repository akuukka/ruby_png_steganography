require 'chunky_png'
require 'zlib'

$MAGIC_NUMBER = 0xb431a3ef
$FILE_VERSION = 1
$HEADER_SIZE_IN_PIXELS = 32 # 32 pixels allows us to store 32x3=(30+2)x3=90+6=96 bits of data, when using only the least significant bits, perfect for a 96-bit header.
$BITS_PER_CHANNEL = 1

def int_to_byte_array(value)
	return [(value & 0xff000000) >> 24, (value & 0x00ff0000) >> 16, (value & 0xff00) >> 8, value & 0xff]
end

def byte_array_to_int(value)
	return value[3] | (value[2] << 8) | (value[1] << 16) | (value[0] << 24)
end

def get_max_storable_bits(png, bits_per_channel)
	return (png.width * png.height - $HEADER_SIZE_IN_PIXELS) * 3 * bits_per_channel
end

def assert_equal(a,b,error)
	if not a==b then
		abort(error)
	end
end

def bit_print(col)
	puts ((col&0xff000000)>>24).to_s(2) + " " + ((col&0xff0000)>>16).to_s(2) + " " + ((col&0xff00)>>8).to_s(2)
end

def byte_array_crc(arr)
	crc = Zlib.crc32(arr.pack("C*"))
	return crc & 0xffff
end

def write_data(data, png_out, pixel_offset, bits_per_channel)
	total_bits = data.count*8
	total_bits.times { |i|
		pixel_index = i / (3 * bits_per_channel) + pixel_offset
		channel_index = (i/bits_per_channel)%3
		channel = ["R","G","B"][channel_index]
		bit_index = i % bits_per_channel
		#puts "Bit " + i.to_s + " goes to pixel " + pixel_index.to_s + " channel " + channel + " bit " + (7 - bit_index).to_s

		data_bit = data[i/8]&(1<<(7-(i%8))) > 0 ? 1 : 0
		x = pixel_index % png_out.width
		y = pixel_index / png_out.width

		col = png_out[x,y]
		#bit_print(col)
		ocol = col

		channel_mask = [0xff000000,0xff0000,0xff00][channel_index]
		channel_mask_inv = [0x00ffffff,0xff00ffff,0xffff00ff][channel_index]
		color_value = (col & channel_mask) >> (24-8*channel_index)
		orig_color_value = color_value
		mask = 0xff - (1 << bit_index)
		color_value = color_value & mask
		color_value = color_value | ((data_bit) << bit_index)

		#puts "Store "  + data_bit.to_s + " as color value " + color_value.to_s + " with orig color value " + orig_color_value.to_s
		col = (col & channel_mask_inv) | (color_value<<(24-channel_index*8))

		#bit_print(col)
		#puts " "

		png_out[x,y] = col
	}
end

def generate_header(data, bits_per_channel)
	crc = byte_array_crc(data)
	hdr_data_0 = bits_per_channel | ($FILE_VERSION << 8) | (crc << 16)
	hdr_data_1 = data.count
	return int_to_byte_array($MAGIC_NUMBER) + int_to_byte_array(hdr_data_0) + int_to_byte_array(hdr_data_1)
end

def check_header(data)
	magic_number = byte_array_to_int(data[0...4])
	if magic_number != $MAGIC_NUMBER then
		abort("The file does not contain encrypted data.")
	end

	hdr_data_0 = byte_array_to_int(data[4...8])

	bits_per_channel = hdr_data_0 & 0xff
	puts "Bits per channel: " + bits_per_channel.to_s
	if bits_per_channel < 0 or bits_per_channel > 8 then
		abort("Invalid header.")
	end

	file_version = (hdr_data_0 & 0xff00) >> 8
	puts "File version: " + file_version.to_s
	if file_version < 1 then
		abort("Invalid header.")
	end

	crc = (hdr_data_0 & 0xffff0000) >> 16
	puts "CRC: " + crc.to_s

	data_count_bytes = byte_array_to_int(data[8...12])

	puts "Bytes of data: " + data_count_bytes.to_s

	return file_version, data_count_bytes, bits_per_channel, crc
end

def export_data(data, png_in_name, png_out_name)
	if data.count > 0xffffffff then
		abort("Data too large.")
	end

	png_in = ChunkyPNG::Image.from_file(png_in_name)
	png_out = ChunkyPNG::Image.new(png_in.width, png_in.height, ChunkyPNG::Color::TRANSPARENT)
	png_out.height.times do |y|
		png_out.width.times do |x|
			png_out[x,y] = png_in[x,y]
		end
	end

	max_storable_bits = get_max_storable_bits(png_out, $BITS_PER_CHANNEL)
	data_count_bits = (data.count*8)
	if data_count_bits > max_storable_bits then
		abort("Image is too small.")
	end

	hdr_data = generate_header(data,$BITS_PER_CHANNEL)

	puts "Writing " + data.count.to_s + " bytes of data and " + hdr_data.count.to_s + " bytes of header data."

	write_data(hdr_data, png_out, 0, 1)
	write_data(data, png_out, $HEADER_SIZE_IN_PIXELS, $BITS_PER_CHANNEL)

	png_out.save("test_out.png")
end

def read_bytes(png, bits_per_channel, pixel_offset, byte_count)
	bits_to_read = byte_count * 8

	ret = []
	current_byte = 0

	puts "Read " + byte_count.to_s + " bytes"

	bits_to_read.times { |i|
		pixel_index = i / (3 * bits_per_channel) + pixel_offset
		channel_index = (i/bits_per_channel)%3
		channel = ["R","G","B"][channel_index]
		bit_index = i % bits_per_channel

		x = pixel_index % png.width
		y = pixel_index / png.width
		col = png[x,y]

		channel_mask = [0xff000000,0xff0000,0xff00][channel_index]
		color_value = (col & channel_mask) >> (24-8*channel_index)

		mask = 1 << bit_index

		databit = (color_value & mask) >> bit_index

		if databit > 1 then
			abort("Mysterious stuff happening")
		end

		if i % 8 == 0 then
			if i > 0 then
				ret = ret + [current_byte]
			end
			current_byte = 0
		else
			current_byte = current_byte << 1
		end
		current_byte = current_byte | databit
	}
	ret = ret + [current_byte]

	return ret
end

def read_data(png_name)
	png_in = ChunkyPNG::Image.from_file(png_name)

	header_bytes = read_bytes(png_in, 1, 0, 12)
	file_version, data_count_bytes, bits_per_channel, expected_crc = check_header(header_bytes)

	if file_version < 1 or file_version > $FILE_VERSION then
		abort("Invalid file version.")
	end

	actual_data = read_bytes(png_in, bits_per_channel, $HEADER_SIZE_IN_PIXELS, data_count_bytes)
	actual_crc = byte_array_crc(actual_data)
	if actual_crc != expected_crc then
		abort("Invalid CRC.")
	end

	return actual_data
end

def test()
	assert_equal($MAGIC_NUMBER, byte_array_to_int(int_to_byte_array($MAGIC_NUMBER)),"Could not revert properly back to int")

	rng = Random.new(5)

	test_png_size = 512
	png = ChunkyPNG::Image.new(test_png_size, test_png_size, ChunkyPNG::Color::TRANSPARENT)

	test_png_size.times do |y|
		test_png_size.times do |x|
			png[x,y] = ChunkyPNG::Color.rgba(rng.rand(256), rng.rand(256),rng.rand(256), 255)	
		end
	end

	png.save("test_in.png", :interlace => true)

	test_string = "AbracadabraAbracadabraAbracadabraAbracadabraAbracadabraAbracadabraAbracadabraAbracad"
	data = test_string.bytes

	export_data(data, "test_in.png" ,"test_out.png")
	read_data = read_data("test_out.png")

	if read_data.sort != data.sort then
		abort("Error!")
	end
end

def parse_args()
	if ARGV.count == 0 then
		return nil
	end

	args = {}

	supported_args = {
		"test" => {
			"params" => 0
		},
		"png_in" => {
			"params" => 1
		},
		"png_out" => {
			"params" => 1
		},
		"data_in" => {
			"params" => 1
		},
		"data_out" => {
			"params" => 1
		}
	}

	processed_indices = []

	ARGV.each_with_index { |arg, index|
		if processed_indices.include? index then
			next
		end

		re = /--([a-z_]*$)/
		m = arg.match(re)
		if not m then
			return nil
		end

		arg = m[1]
		if not supported_args.has_key? arg then
			return nil
		end

		expected_param_count = supported_args[arg]["params"]

		if ARGV.count <= index + expected_param_count then
			return nil
		end

		processed_indices.push(index)
		expected_param_count.times { |t|
			processed_indices.push(index + 1 + t)
		}

		args[arg] = ARGV[(index+1)...(index+1+expected_param_count)]
	}

	return args
end

if __FILE__ == $0
	args = parse_args()

	if args != nil and args.has_key? "test" then
		test()
	elsif args != nil and args.has_key? "png_in" and args.has_key? "data_in" and args.has_key? "png_out" then
		# Put data inside PNG
		data_file_name = args["data_in"][0]
		s = File.open(data_file_name, 'rb') { |f| f.read }
		data = s.bytes
		export_data(data, args["png_in"][0],args["png_out"][0])
	elsif args != nil and args.has_key? "png_in" and args.has_key? "data_out" then
		# Extract data out of PNG
		image_file_name = args["png_in"][0]
		data_file_name = args["data_out"][0]
		data = read_data(image_file_name)
		File.open(data_file_name, 'wb') { |file| file.write(data.pack('c*')) }
	else
		puts "Usage: stega"
	end
end