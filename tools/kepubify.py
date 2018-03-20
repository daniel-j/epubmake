#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# This code is from "KePub Output" Calibre plugin
# http://www.mobileread.com/forums/showthread.php?t=220565
# version 2.7.1

import re
from lxml import etree
from copy import deepcopy
import sys


SPECIAL_TAGS = frozenset(['img'])
XHTML_NAMESPACE = 'http://www.w3.org/1999/xhtml'

class KEPubContainer():
    paragraph_counter = 0
    segment_counter = 0

    def __append_kobo_spans_from_text(self, node, text):
        if text is not None:
            # if text is only whitespace, don't add spans
            if re.match(r'^\s+$', text, flags=re.UNICODE | re.MULTILINE):
                return False
            else:
                # split text in sentences
                groups = re.split(r'(.*?[\.\!\?\:][\'"\u201d\u2019]?\s*)',
                                  text,
                                  flags=re.UNICODE | re.MULTILINE)
                # remove empty strings resulting from split()
                groups = [g for g in groups if g != '']

                # To match Kobo KePubs, the trailing whitespace needs to be
                # prepended to the next group. Probably equivalent to make sure
                # the space stays in the span at the end.
                # add each sentence in its own span
                for g in groups:
                    span = etree.Element("{%s}span" % (XHTML_NAMESPACE, ),
                                         attrib={"id": "kobo.{0}.{1}".format(
                                             self.paragraph_counter,
                                             self.segment_counter),
                                                 "class": "koboSpan"})
                    span.text = g
                    node.append(span)
                    self.segment_counter += 1
                return True
        return True

    def __add_kobo_spans_to_node(self, node):
        # process node only if it is not a comment or a processing instruction
        if not (node is None or isinstance(node, etree._Comment) or isinstance(
                node, etree._ProcessingInstruction)):
            # Special case: <img> tags
            special_tag_match = re.search(r'^(?:\{[^\}]+\})?(\w+)$', node.tag)
            if special_tag_match and special_tag_match.group(
                    1) in SPECIAL_TAGS:
                span = etree.Element("{%s}span" % (XHTML_NAMESPACE, ),
                                     attrib={"id": "kobo.{0}.{1}".format(
                                         self.paragraph_counter,
                                         self.segment_counter),
                                             "class": "koboSpan"})
                span.append(node)
                return span

            # save node content for later
            nodetext = node.text
            nodechildren = deepcopy(node.getchildren())
            nodeattrs = {}
            for key in node.keys():
                nodeattrs[key] = node.get(key)

            # reset current node, to start from scratch
            node.clear()

            # restore node attributes
            for key in nodeattrs.keys():
                node.set(key, nodeattrs[key])

            # the node text is converted to spans
            if nodetext is not None:
                if not self.__append_kobo_spans_from_text(node, nodetext):
                    # didn't add spans, restore text
                    node.text = nodetext

            # re-add the node children
            for child in nodechildren:
                # save child tail for later
                childtail = child.tail
                child.tail = None
                node.append(self.__add_kobo_spans_to_node(child))
                # the child tail is converted to spans
                if childtail is not None:
                    self.paragraph_counter += 1
                    self.segment_counter = 1
                    if not self.__append_kobo_spans_from_text(node, childtail):
                        # didn't add spans, restore tail on last child
                        self.paragraph_counter -= 1
                        node[-1].tail = childtail

                self.paragraph_counter += 1
                self.segment_counter = 1
        else:
            node.tail = None
        return node

    def add_kobo_spans(self, name):
        parser = etree.XMLParser(resolve_entities=False)
        root = etree.parse(name, parser)


        self.paragraph_counter = 1
        self.segment_counter = 1
        if len(root.xpath('.//xhtml:span[@class="koboSpan" or starts-with(@id, "kobo.")]', namespaces={'xhtml': XHTML_NAMESPACE})) == 0:
            body = root.xpath('./xhtml:body', namespaces={'xhtml': XHTML_NAMESPACE})[0]
            body = self.__add_kobo_spans_to_node(body)

        root = etree.tostring(root, pretty_print=True, xml_declaration=True, encoding = 'utf-8')
        # Re-open self-closing paragraph tags
        root = re.sub(b'<p[^>/]*/>', '<p></p>', root).decode('utf-8')

        # preserve nbsp
        root = root.replace(chr(160), '&#160;')
        # preserve soft hyphen
        root = root.replace(chr(173), '&#173;')

        print(root)

ebook = KEPubContainer()
ebook.add_kobo_spans(sys.argv[1])
