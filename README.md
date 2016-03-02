#picompress
Distributed under the GNU GPL  
https://www.gnu.org/licenses/gpl-3.0.txt  
Or see the file ./LICENSE

##Introduction
`picompress` is a tiny wrapper around imagemagick and jhead. It offers a very 
simple way to shrink and rename image-files inside a directory.

All user-input if fetched with zenity, to make it as easy as possible for
unexperienced users.

`picompress` will never delete or overwrite any image you process with it or 
that was created with it. Instead it saves the resulting files in numbered 
folders next to the original image files.

##Features
###Shrink images
You can set a compression value in percent and/or you can set an image-size
either in percent or pixels.

This can be very usefull, when sending images over the internet.

###Rename images
You can set a pattern (strftime) for renaming the images according to the timestamp in the EXIF-header. This will also set
the file's system time stamp. There is a sane default pattern consisting of 
date and time.

This can be very usefull, when taking pictures with more than one camera at 
once. That way you can sort your images in chronological order.

###Supported file formats
|      | Shrinking | Renaming |
|------|-----------|----------|
| JPEG |     ✓     |     ✓    |
| PNG  |     ✓     |          |

###Choose a folder
You can choose a folder with image files either with a dialog, or with a right 
click on a folder inside a file manager ('Open With' --> 'picompress').

###Languages
`picompress` supports English and German.

##Dependencies
`picompress` is written in bash and depends on:
 - zenity
 - imagemagick
 - jhead

##Installation
```
$ make
# make install
```
