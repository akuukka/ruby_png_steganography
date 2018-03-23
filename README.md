# ruby_png_steganography

Store and extract random data to/from png files

You can use this script to store whatever data you want into png files while only minimally altering how the image looks like. You may also encrypt the data using a secret key (we use the 256-bit AES cipher).

The only non-standard dependency is chunky-png, which you can install by running

  gem install chunky-png
