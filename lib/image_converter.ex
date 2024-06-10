defmodule ImageConverter do
  def decode_and_save_as_bmp(b64, filename \\ "so_12.bmp") do
    # Decode the base64 string to binary data
    {:ok, binary_data} = Base.decode64(b64)

    # Temporarily save as a PNG or read directly if already in a PNG format
    File.write!("temp_image.png", binary_data)

    # Convert the image to BMP using a command-line tool like ImageMagick
    path = File.cwd!() <> "/media"

    # Define the fixed size for resizing
    resize_option = ["-resize", "180x180!"]

    # Add the output format and file path
    command = ["temp_image.png"] ++ resize_option ++ ["BMP3:" <> "#{path}/#{filename}"]

    # Execute the command
    System.cmd("convert", command)
  end
end
