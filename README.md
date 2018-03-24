# ruby_png_steganography

Store and extract random data to/from png files

You can use this script to store whatever data you want into png files while only minimally altering how the image looks like. You may also encrypt the data using a secret key (we use the 256-bit AES cipher).

The only non-standard dependency is chunky-png, which you can install by running

> gem install chunky-png

Usage:

To store my_data.dat into my_png.png and output the result to my_png_with_data.png using AES encryption, type:

> ruby ruby-stega.rb --data_in my_data.dat --png_in my_png.png --png_out my_png_with_data.png --encrypt my_key

Note that the --encrypt parameter is optional.

To extract the data out of my_png_with_data.png and write it to my_data2.dat, type:

> ruby ruby-stega.rb --png_in my_png_with_data.png --data_out my_data2.dat --decrypt my_key
