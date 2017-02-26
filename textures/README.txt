To create the closed portals, I manually created the "gray closed"
image, then made colour versions of it using the ImageMagick "convert"
command:

  convert gray_closed.png +level-colors cyan, cyan_middle.png 

  convert gray_closed.png +level-colors orange, orange_middle.png 
