require_relative 'ruby-stega.rb'

def assert_equal(a,b,error)
	if not a==b then
		abort(error)
	end
end

if __FILE__ == $0
	# Test byte array/int conversion
	assert_equal($MAGIC_NUMBER, byte_array_to_int(int_to_byte_array($MAGIC_NUMBER)),"Could not revert properly back to int")

	# Unit test encryption/decryption. Given data and key, it should be true that data equals decrypt(encrypt(data,key),key).
	data = "test encryption data".bytes
	key = "test_encryption_key"
	encrypted = encrypt(data,key)
	orig = decrypt(encrypted,key)
	assert_equal(data.pack("c*"), orig.pack("c*"),"Encryption/decryption doesn't work as it should!")

	# Test PNG steganography
	test_cases = [
		{
			# We should be able to handle empty data without trouble.
			:data => "",
			:bits_per_channel => 3,
			:image_width => 256,
			:image_height => 256,
			:encrypt => false
		},
		{
			# Even if it's encrypted.
			:data => "",
			:bits_per_channel => 3,
			:image_width => 256,
			:image_height => 256,
			:encrypt => true
		},
		{
			:data => "Makrillien ystavat tulevat kokemaan ihmeellisen kokemuksen josta riittaa kerrottavaksi jalkipolville.",
			:encrypt => true,
			:bits_per_channel => 1,
			:image_width => 256,
			:image_height => 128,
			:encryption_key => "zappadam"
		},
		{
			:data => "Aivan jarjeton on leipajonon luotaanpoistyontava hantapaa.",
			:bits_per_channel => 3,
			:image_width => 256,
			:image_height => 256,
			:encrypt => false
		}
	]

	start_time = Time.now

	test_cases.each_with_index { |test_case, index|
		puts "Test case #{index}:\n#{test_case.to_s}\n"

		w = test_case[:image_width]
		h = test_case[:image_height]
		png = ChunkyPNG::Image.new(w, h, ChunkyPNG::Color::TRANSPARENT)
		h.times do |y|
			w.times do |x|
				png[x,y] = ChunkyPNG::Color.rgba(x*256/w, y*256/h, (x+y) % 256, 255)	
			end
		end

		png.save("test_in.png", :interlace => true)

		test_string = test_case[:data]
		data = test_string.bytes

		export_data(data, "test_in.png" ,"test_out.png", test_case[:bits_per_channel], test_case[:encrypt] ? test_case[:encryption_key] : nil)
		read_data = read_data("test_out.png", test_case[:encrypt] ? test_case[:encryption_key] : nil)

		if read_data.sort != data.sort then
			abort("Error!")
		end
	}

	end_time = Time.now
	run_time = end_time - start_time
	puts "Test took " + run_time.to_s + " s"
end