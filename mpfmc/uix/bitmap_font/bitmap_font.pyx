#!python
#cython: embedsignature=True, language_level=3

__all__ = ('BitmapFont',
           'BitmapFontException',
           '_SurfaceContainer',
           )

include 'bitmap_font.pxi'

cimport cpython.pycapsule as pycapsule

import re
from os import path
from xml.etree.ElementTree import ElementTree, ParseError
from libc.string cimport memset
from kivy.core.image import ImageData


class BitmapFontException(Exception):
    """Exception returned by the bitmap font module"""
    pass


cdef class BitmapFontCharacter:
    cdef public int id
    cdef public SDL_Rect rect
    cdef public int xoffset
    cdef public int yoffset
    cdef public int xadvance

    def __cinit__(self, *args, **kw):
        self.id = 0
        self.rect.x = 0
        self.rect.y = 0
        self.rect.w = 0
        self.rect.h = 0
        self.xoffset = 0
        self.yoffset = 0
        self.xadvance = 0


cdef class BitmapFont:
    cdef public str face
    cdef public bint bold
    cdef public bint italic
    cdef public int padding
    cdef public int spacing
    cdef public int outline

    cdef public int line_height
    cdef public int base
    cdef public int scale_w
    cdef public int scale_h

    cdef dict characters
    cdef dict kernings

    cdef SDL_Surface *image

    def __cinit__(self, *args, **kw):
        self.face = ""
        self.bold = False
        self.italic = False
        self.padding = 0
        self.spacing = 0
        self.outline = 0

        self.line_height = 0
        self.base = 0
        self.scale_w = 0
        self.scale_h = 0

        self.characters = dict()
        self.kernings = dict()

        self.image = NULL

    def __init__(self, str image_file, object descriptor):

        # Load the image file
        cdef bytes c_filename = image_file.encode('utf-8')
        cdef SDL_Surface *image = IMG_Load(c_filename)

        if image == NULL:
            raise BitmapFontException("Could not load bitmap font image file")

        self.image = image
        self.scale_w = self.image.w
        self.scale_h = self.image.h

        if isinstance(descriptor, list):
            self._load_descriptor_list(descriptor)
        elif isinstance(descriptor, str):
            self._load_descriptor_file(descriptor)
        else:
            raise BitmapFontException("Illegal value in bitmap font descriptor")

    def __dealloc__(self):
        if self.image != NULL:
            SDL_FreeSurface(self.image)
            self.image = NULL

    def get_image(self):
        image_capsule = pycapsule.PyCapsule_New(self.image, NULL, NULL)
        return image_capsule

    def get_characters(self):
        return self.characters

    def get_kernings(self):
        return self.kernings

    def _load_descriptor_list(self, list descriptor_list):
        """Load the descriptor from the supplied list."""
        cdef int x = 0
        cdef int y = 0
        cdef int row_height = int(self.scale_h / len(descriptor_list))
        cdef int char_width
        cdef int char_id
        self.line_height = row_height
        self.base = row_height

        # Loop over all the rows in the descriptor list
        for row in descriptor_list:
            char_width = int(self.scale_w / len(row))
            x = 0

            # Loop over all characters in the row
            for text_char in row:
                char_id = ord(text_char)

                # Do not add duplicate character definitions (only use the first instance)
                if char_id not in self.characters:

                    # Create character definition
                    character = BitmapFontCharacter()
                    character.id = char_id
                    character.rect.x = x
                    character.rect.y = y
                    character.rect.w = char_width
                    character.rect.h = row_height
                    character.xadvance = char_width

                    self.characters[character.id] = character
                    x += char_width

            y += row_height

    def _load_descriptor_file(self, str descriptor_file):
        """Load the descriptor from the specified file.  Both XML and text
        formats are supported (not binary currently).

        The standard bitmap font descriptor file format can be found at:
        http://www.angelcode.com/products/bmfont/doc/file_format.html
        """
        cdef int char_id
        cdef int first
        cdef int second

        if not path.isfile(descriptor_file):
            raise BitmapFontException('Could not locate the bitmap font descriptor file ' +
                                      descriptor_file)

        # Attempt to parse the file as an XML file
        try:
            xml_tree = ElementTree(file=descriptor_file)
            self._load_descriptor_xml(xml_tree)
        except ParseError:
            pass

        # Assume since the XML parser threw an exception that this is a text file

        # Open the descriptor file
        with open(descriptor_file) as text_file:

            # Loop over all the rows in the descriptor file
            for line in text_file:
                if line.startswith("info"):
                    pass

                elif line.startswith("common"):
                    m = re.search(r"lineHeight=([0-9]{1,5})", line, flags=re.IGNORECASE)
                    if m:
                        self.line_height = int(m.group(1))
                    else:
                        raise BitmapFontException("Bitmap font descriptor file invalid format")

                    m = re.search(r"base=([0-9]{1,5})", line, flags=re.IGNORECASE)
                    if m:
                        self.base = int(m.group(1))
                    else:
                        raise BitmapFontException("Bitmap font descriptor file invalid format")

                elif line.startswith("chars"):
                    pass

                elif line.startswith("char"):
                    m = re.search(r"char\s+id=(?P<id>[0-9]{1,4})\s+x=(?P<x>[0-9]{1,4})\s+y=(?P<y>[0-9]{1,4})"
                                  r"\s+width=(?P<width>[0-9]{1,3})\s+height=(?P<height>[0-9]{1,3})"
                                  r"\s+xoffset=(?P<xoffset>-?[0-9]{1,3})\s+yoffset=(?P<yoffset>-?[0-9]{1,3})"
                                  r"\s+xadvance=(?P<xadvance>[0-9]{1,3})\s+page=(?P<page>[0-9]{1,2})"
                                  r"\s+chnl=(?P<chnl>[0-9]{1,3})", line, flags=re.IGNORECASE)
                    if not m:
                        raise BitmapFontException("Bitmap font descriptor file invalid format")

                    char_id = int(m.group("id"))
                    if char_id > 256:
                        continue

                    # Do not add duplicate character definitions (only use the first instance)
                    if char_id not in self.characters:

                        # Create character definition
                        character = BitmapFontCharacter()
                        character.id = char_id
                        character.rect.x = int(m.group("x"))
                        character.rect.y = int(m.group("y"))
                        character.rect.w = int(m.group("width"))
                        character.rect.h = int(m.group("height"))
                        character.xoffset = int(m.group("xoffset"))
                        character.yoffset = int(m.group("yoffset"))
                        character.xadvance = int(m.group("xadvance"))

                        self.characters[character.id] = character

                elif line.startswith("kernings"):
                    pass

                elif line.startswith("kerning"):
                    m = re.search(r"kerning\s+first=(?P<first>[0-9]{1,3})\s+second=(?P<second>[0-9]{1,3})"
                                  r"\s+amount=(?P<amount>-?[0-9]{1,3})", line, flags=re.IGNORECASE)
                    if not m:
                        raise BitmapFontException("Bitmap font descriptor file invalid format")

                    first = int(m.group("first"))
                    second = int(m.group("second"))

                    if first not in self.kernings:
                        self.kernings[first] = {}

                    if second not in self.kernings[first]:
                        self.kernings[first][second] = int(m.group("amount"))

    def _load_descriptor_xml(self, xml_tree: ElementTree):
        """Loads the descriptor information from the XML tree."""

        cdef int first = 0
        cdef int second = 0
        root = xml_tree.getroot()
        if root is None:
            raise BitmapFontException("Bitmap font descriptor file invalid XML format")

        # info
        info = root.find('info')
        if info is None:
            raise BitmapFontException("Bitmap font descriptor file invalid XML format")

        # common
        common = root.find('common')
        if common is None:
            raise BitmapFontException("Bitmap font descriptor file invalid XML format")

        self.line_height = int(common.attrib["lineHeight"])
        self.base = int(common.attrib["base"])

        # characters
        chars = root.find('chars')
        if chars is None:
            raise BitmapFontException("Bitmap font descriptor file invalid XML format")

        for text_char in chars.findall('char'):
            character = BitmapFontCharacter()
            character.id = int(text_char.attrib["id"])
            character.rect.x = int(text_char.attrib["x"])
            character.rect.y = int(text_char.attrib["y"])
            character.rect.w = int(text_char.attrib["width"])
            character.rect.h = int(text_char.attrib["height"])
            character.xadvance = int(text_char.attrib["xadvance"])
            character.xoffset = int(text_char.attrib["xoffset"])
            character.yoffset = int(text_char.attrib["yoffset"])

            self.characters[character.id] = character

        # kerning
        kernings = root.find('kernings')
        if kernings is not None:
            for kerning in kernings.findall('kerning'):
                first = int(kerning.attrib["first"])
                second = int(kerning.attrib["second"])

                if first not in self.kernings:
                    self.kernings[first] = {}

                self.kernings[first][second] = int(kerning.attrib["amount"])


    def get_descent(self):
        return self.base - self.line_height

    def get_ascent(self):
        return self.base

    def get_extents(self, str text, font_kerning=True):
        cdef int width = 0
        cdef int previous_char = -1
        cdef int current_char
        cdef bint use_kerning = font_kerning

        for text_char in text:
            current_char = ord(text_char)
            if current_char in self.characters:
                char_info = self.characters[current_char]
                width += char_info.xadvance

                if use_kerning and previous_char in self.kernings and current_char in self.kernings[previous_char]:
                    width += self.kernings[previous_char][current_char]

            previous_char = current_char

        return width, self.line_height


cdef class _SurfaceContainer:
    cdef SDL_Surface* surface
    cdef int w, h

    def __cinit__(self, w, h):
        self.surface = NULL
        self.w = w
        self.h = h

    def __init__(self, w, h):
        # XXX check on OSX to see if little endian/big endian make a difference
        # here.
        self.surface = SDL_CreateRGBSurface(0,
            w, h, 32,
            0x000000ff, 0x0000ff00, 0x00ff0000, 0xff000000)
        memset(self.surface.pixels, 0, w * h * 4)

    def __dealloc__(self):
        if self.surface != NULL:
            SDL_FreeSurface(self.surface)
            self.surface = NULL

    def render(self, container, text, x, y):
        """Render the text at the specified location."""
        cdef SDL_Rect cursor_rect
        cdef SDL_Rect source_rect
        cdef SDL_Rect dest_rect
        cdef SDL_Surface *source_image
        cdef dict characters = dict()
        cdef dict kernings = dict()
        cdef bint use_kerning = True
        cdef int previous_char = -1
        cdef int current_char

        asset = container.get_font_asset()
        if asset is None:
            return

        font = asset.bitmap_font
        if font is None:
            return

        source_image = <SDL_Surface*>pycapsule.PyCapsule_GetPointer(font.get_image(), NULL)
        if source_image == NULL:
            return

        cursor_rect.x = x
        cursor_rect.y = y

        characters = font.get_characters()
        kernings = font.get_kernings()
        use_kerning = container.options['font_kerning']

        # Copy each character in the text string from the bitmap font atlas to
        # the output texture/surface
        for text_char in text:
            current_char = ord(text_char)
            if current_char in characters:
                char_info = characters[current_char]

                if use_kerning and previous_char in kernings and current_char in kernings[previous_char]:
                    cursor_rect.x += kernings[previous_char][current_char]

                source_rect = char_info.rect
                dest_rect.x = cursor_rect.x + char_info.xoffset
                dest_rect.y = cursor_rect.y + char_info.yoffset
                SDL_BlitSurface(source_image, &source_rect, self.surface, &dest_rect)
                cursor_rect.x += char_info.xadvance

            previous_char = current_char

    def get_data(self):
        """Return the bitmap font surface as ImageData (pixels)."""
        cdef int datalen = self.surface.w * self.surface.h * 4
        cdef bytes pixels = (<char *>self.surface.pixels)[:datalen]
        data = ImageData(self.w, self.h, 'rgba', pixels)
        return data
