#!/usr/bin/env python
# -*- coding: utf-8 -*-

# This plugin fixes the xhtml toc location in EPUB3 ebooks
# A bug in iOS iBooks fails to render its toc correctly otherwise
# Only tested with epubs made with Sigil
# by djazz

import sys
import os
import tempfile
import shutil
from lxml import etree
import re
from urllib.parse import urlparse, urlunparse

from epub_utils import epub_zip_up_book_contents

import tkinter
import tkinter.filedialog as tkinter_filedialog

_USER_HOME = os.path.expanduser("~")
XHTML_NAMESPACE = 'http://www.w3.org/1999/xhtml'
NCX_NAMESPACE = 'http://www.daisy.org/z3986/2005/ncx/'


def write_file(data, fpath):
    with open(fpath, "wb") as file_obj:
        file_obj.write(data.encode("utf-8"))


def replaceHrefs(root, href, oldnavpath, navpath, docType, content):
    fullpath = os.path.join(root, href)
    parser = etree.XMLParser(resolve_entities=False, encoding='utf-8')
    tree = etree.fromstring(content.encode('utf-8'), parser=parser).getroottree()
    didReplacements = False
    if docType == 0:  # other xhtml
        href_list = tree.findall('.//xhtml:a[@href]', namespaces={'xhtml': XHTML_NAMESPACE})
        olddiff = os.path.normpath(os.path.relpath(os.path.join(root, oldnavpath), os.path.join(root, os.path.dirname(href))))
        newdiff = os.path.normpath(os.path.relpath(os.path.join(root, navpath), os.path.join(root, os.path.dirname(href))))
        for link in href_list:
            parsedurl = urlparse(link.attrib.get('href'))
            oldhref = os.path.normpath(parsedurl.path)
            if oldhref == olddiff:
                parsedurl = parsedurl._replace(path=newdiff)
                print('in', href, 'replace', link.attrib.get('href'), 'with', urlunparse(parsedurl))
                link.attrib['href'] = urlunparse(parsedurl)
                didReplacements = True
    elif docType == 1:  # nav xhtml
        href_list = tree.findall('.//xhtml:*[@href]', namespaces={'xhtml': XHTML_NAMESPACE})
        src_list = tree.findall('.//xhtml:*[@src]', namespaces={'xhtml': XHTML_NAMESPACE})
        for link in href_list + src_list:
            attrib = 'href'
            if not link.attrib.get(attrib, None):
                attrib = 'src'
            parsedurl = urlparse(link.attrib.get(attrib))
            oldhref = os.path.normpath(parsedurl.path)
            olddiff = os.path.normpath(os.path.join(os.path.dirname(href), parsedurl.path))
            newdiff = os.path.normpath(os.path.join('Text', os.path.dirname(href), parsedurl.path))
            if oldhref != olddiff or oldhref == '.':
                continue
            if newdiff == os.path.join('Text', href):
                newdiff = href
            parsedurl = parsedurl._replace(path=newdiff)
            print('in', href, 'replace', link.attrib.get(attrib), 'with', urlunparse(parsedurl))
            link.attrib[attrib] = urlunparse(parsedurl)
            didReplacements = True
    elif docType == 2:  # toc ncx
        olddiff = os.path.normpath(os.path.relpath(os.path.join(root, oldnavpath), os.path.join(root, os.path.dirname(href))))
        newdiff = os.path.normpath(os.path.relpath(os.path.join(root, navpath), os.path.join(root, os.path.dirname(href))))
        href_list = tree.findall('.//xml:navPoint/xml:content[@src]', namespaces={'xml': NCX_NAMESPACE})
        for link in href_list:
            parsedurl = urlparse(link.attrib.get('src'))
            oldhref = os.path.normpath(parsedurl.path)
            if oldhref == olddiff:
                parsedurl = parsedurl._replace(path=newdiff)
                print('in', href, 'replace', link.attrib.get('src'), 'with', urlunparse(parsedurl))
                link.attrib['src'] = urlunparse(parsedurl)
                didReplacements = True

    if not didReplacements:
        return

    content = etree.tostring(tree, pretty_print=True, xml_declaration=True, encoding = 'utf-8')
    # Re-open self-closing paragraph tags
    content = re.sub(b'<p[^>/]*/>', '<p></p>', content).decode('utf-8')

    # preserve nbsp
    content = content.replace(chr(160), '&#160;')
    # preserve soft hyphen
    content = content.replace(chr(173), '&#173;')

    with open(fullpath, "wb") as file_obj:
        file_obj.write(content.encode("utf-8"))


# the plugin entry point
def run(bk):

    def ncx_iter():
        # yields manifest id, href
        for id in sorted(bk._w.id_to_mime):
            mime = bk._w.id_to_mime[id]
            if mime == 'application/x-dtbncx+xml':
                href = bk._w.id_to_href[id]
                yield id, href

    if bk.epub_version() == '2.0':
        print('EPUB2 doesn\'t require any fixes')
        return 0

    navid = None
    oldnavpath = None

    for item in bk.manifest_epub3_iter():
        prop = item[3]
        if prop:
            prop = prop.split(' ')
            if 'nav' in prop:
                navid = item[0]
                oldnavpath = item[1]
                break
    if not navid:
        print('No XHTML TOC')
        return 1

    fpath = None
    if 'OUTPUTFILE' in os.environ:
        fpath = os.environ['OUTPUTFILE']
    else:
        # ask the user where he/she wants to store the new epub
        # TODO use dc:title from the OPF file instead
        doctitle = "filename"
        fname = cleanup_file_name(doctitle) + ".epub"
        localRoot = tkinter.Tk()
        localRoot.withdraw()
        fpath = tkinter_filedialog.asksaveasfilename(
            parent=localRoot,
            title="Save EPUB As...",
            initialfile=fname,
            initialdir=_USER_HOME,
            defaultextension=".epub"
            )
        # localRoot.destroy()
        localRoot.quit()
        if not fpath:
            print("Saving cancelled by user")
            return 0

    temp_dir = tempfile.mkdtemp()

    bk.copy_book_contents_to(temp_dir)
    root = os.path.join(temp_dir, 'OEBPS')

    # move the toc file to OEBPS root
    navpath = os.path.basename(oldnavpath)
    os.rename(os.path.join(root, oldnavpath), os.path.join(root, navpath))
    bk._w.id_to_href[navid] = navpath
    bk._w.modified['OEBPS/content.opf'] = 'file'

    # update guide reference
    guide = bk._w.guide
    for item in guide:
        index = guide.index(item)
        if os.path.normpath(item[2]) == os.path.normpath(oldnavpath):
            item = item[0:2] + tuple([navpath])
            guide[index] = item

    # replace references to nav xhtml
    for itemid, href in bk.text_iter():
        replaceHrefs(root, href, oldnavpath, navpath, 1 if itemid == navid else 0, bk.readfile(itemid))

    # same as above, but for ncx toc
    for itemid, href in ncx_iter():
        replaceHrefs(root, href, oldnavpath, navpath, 2, bk.readfile(itemid))

    write_file(bk.get_opf(), os.path.join(root, bk._w.opfname))

    print('Guide:', bk._w.guide)

    write_file("application/epub+zip", os.path.join(temp_dir, "mimetype"))

    print('Saving EPUB to', fpath)

    epub_zip_up_book_contents(temp_dir, fpath)

    shutil.rmtree(temp_dir)

    print("Output Conversion Complete")
    # Setting the proper Return value is important.
    # 0 - means success
    # anything else means failure
    return 0


def cleanup_file_name(name):
    import string
    _filename_sanitize = re.compile(r'[\xae\0\\|\?\*<":>\+/]')
    substitute='_'
    one = ''.join(char for char in name if char in string.printable)
    one = _filename_sanitize.sub(substitute, one)
    one = re.sub(r'\s', '_', one).strip()
    one = re.sub(r'^\.+$', '_', one)
    one = one.replace('..', substitute)
    # Windows doesn't like path components that end with a period
    if one.endswith('.'):
        one = one[:-1]+substitute
    # Mac and Unix don't like file names that begin with a full stop
    if len(one) > 0 and one[0:1] == '.':
        one = substitute+one[1:]
    return one


def main():
    print("I reached main when I should not have\n")
    return -1


if __name__ == "__main__":
    sys.exit(main())
