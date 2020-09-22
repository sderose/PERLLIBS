#!/usr/bin/perl -w
#
# DomExtensions -- useful methods on top of XML::DOM.
#
# Can't easily make this a subclass of Node, since as we traverse, none
# of the existing Nodes returned by XML::DOM calls will be one of us.
# would overriding createXXX be enough?
#
# Written 2010-04-01~23 by Steven J. DeRose.
# 2010-10-08 sjd: Convert to a real package, normalize naming.
# 2011-04-01 sjd: Need to check sync w/ Mac version. Add export().
# 2011-05-16 sjd: Support many more node types in export().
# 2011-05-26 sjd: Swap test for escaping just XML, or also to ASCII.
#     Consistent case for XPointer methods.
# 2011-05-31 sjd: Add @EXPORT, forEachTextNode(), forEachElement(),
#     forEachElementOfType()
#     Get rid of extra initial delim from collectAllText(). Start making
#     export support DTD type nodes. Fix escapeXmlContent().
# 2011-06-01 sjd: Improve collectAllXml(), combine HTML display types,
#     mergeWithFollowingSiblingText().
# 2011-06-03 sjd: Add insertPrecedingSibling(), insertFollowingSibling(),
#     insertParent().
# 2011-08-22 sjd: Improve collectAllXml().
# 2012-09-25 sjd: Qualify DOM node-type constants.
#
# To do:
#     Rewrite to wrap constructor, and then use ISA to pass things along?
#        Which DOM calls need to be overridden? Any that construct nodes....
#           new, parsefile, node (subtypes, too?)
#     Integrate collect/export/tostring/etc. with emitter.
#     Add insertPrecedingSibling, insertFollowingSibling, insertParent,
#         insertAfter
#     Add moveElementToAttribute (like for OA name/value)
#     Implement splitNode (see doc)
#     Move in matchesToElements from mediaWiki2HTML
#     Find next node of qgi?
#     Add output options, perhaps via xmlOutput.pm?
#     SAX-parse the DOM.
#
use strict;
use warnings;

use XML::Parser;
use XML::DOM;
use Exporter; # Make sub(s) available outside without prefix.

use DtdKnowledge;

our $VERSION_DATE = "2.00";

our @ISA = qw( Exporter );
our @EXPORT = qw(
    selectAncestor
    selectChild
    selectDescendant
    selectFollowing         getFollowing
    selectFollowingSibling  getFollowingSibling
    selectPreceding         getPreceding
    selectPrecedingSibling  getPrecedingSibling

    getLeftBranch
    getRightBranch
    getFQGI
    isWithin
    getXPointer
    XPointerCompare
    nodeCompare
    XPointerInterpret

    getInheritedAttribute
    getEscapedAttributeList
    deleteWhiteSpaceNodes
    deleteWhiteSpaceNodesCB
    normalizeSpaceCB

    insertPrecedingSibling
    insertFollowingSibling
    insertParent
    groupSiblings
    promoteChildren

    forEachNode
    forEachTextNode
    forEachElement
    forEachElementOfType

    collectAllText
    collectAllXml
    export
);
# getDepth, escapeXXX -- also defined elsewhere, so not exported.


package DomExtensions;

# Static instance of dtdKnowlege object.
my $dtdk = "";

###############################################################################
# Methods for finding the nth node along a given axis, that has a given
# element type and/or attribute/value.
#
sub selectAncestor {
    my ($self,$n,$type,$aname,$avalue) = @_;
    if (!defined $type) { $type = ""; }
    if (!defined $n) { $n = 1; }
    while ($self=getParentNode($self)) {
        if (nodeMatches($self,$type,$aname,$avalue)) {
            $n--;
            if ($n<=0) { return($self); }
        }
    }
    return(undef);
}

# No selectAncestorOrSelf

sub selectChild {
    my ($self,$n,$type,$aname,$avalue) = @_;
    if (!defined $type) { $type = ""; }
    if (!defined $n) { $n = 1; }
    $self = $self->getFirstChild();
    while (defined $self) {
        if (nodeMatches($self,$type,$aname,$avalue)) {
            $n--;
            if ($n<=0) { return($self); }
        }
        $self = $self->nextSibling();
    }
    return(undef);
}

sub selectDescendant {
    my ($self,$n,$type,$aname,$avalue) = @_;
    setN((defined $n) ? $n:1);
    return(selectDescendantR($self,$n,$type,$aname,$avalue));
}

sub selectDescendantR { # XXX FIX ???
    my ($self,$n,$type,$aname,$avalue) = @_;
    if (nodeMatches($self,$type,$aname,$avalue)) {
        $n--;
        if ($n<=0) { return($self); }
    }
    for my $ch ($self->getChildNodes()) {
        my $node = getDescendantByAttributeR($ch,$n,$type,$aname,$avalue);
        if (defined $node) {
            $n--;
            if ($n<=0) { return($node); }
        }
    }
    return(undef);
}

# No selectDescendantOrSelf

sub selectPreceding {
    my ($self,$n,$type,$aname,$avalue) = @_;
    if (!defined $n) { $n = 1; }
    if (!defined $type) { $type = ""; }
    while ($self=getPreceding($self)) {
        if (nodeMatches($self,$type,$aname,$avalue)) {
            $n--;
            if ($n<=0) { return($self); }
        }
    }
    return(undef);
}
sub getPreceding {
    my ($self) = @_;
    my $node = $self->getPreviousSibling();
    if (defined $node) {
        while (my $next = $node->getFirstChild()) {
            $node = $next;
        }
        return($node);
    }
    return($self->getParentNode());
}

sub selectFollowing {
    my ($self,$n,$type,$aname,$avalue) = @_;
    if (!defined $n) { $n = 1; }
    if (!defined $type) { $type = ""; }
    while ($self=getFollowing($self)) {
        if (nodeMatches($self,$type,$aname,$avalue)) {
            $n--;
            if ($n<=0) { return($self); }
        }
    }
    return(undef);
}
sub getFollowing {
    my $self = $_[0];
    my $node = $self->getFirstChild();
    if (defined $node) { return($node); }
    $node = $self->getNextSibling();
    if (defined $node) { return($node); }
    while ($self = $self->getParentNode()) {
        if ($self->getNextSibling()) { return($self->getNextSibling()); }
    }
    return(undef);
}

sub selectPrecedingSibling {
    my ($self,$n,$type,$aname,$avalue) = @_;
    if (!defined $type) { $type = ""; }
    if (!defined $n) { $n = 1; }
    while ($self = $self->getPreviousSibling()) {
        if (nodeMatches($self,$type,$aname,$avalue)) {
            $n--;
            if ($n<=0) { return($self); }
        }
    }
    return(undef);
}
sub getPrecedingSibling {
    my ($self) = @_;
    return($self->getPreviousSibling());
}

sub selectFollowingSibling {
    my ($self,$n,$type,$aname,$avalue) = @_;
    if (!defined $type) { $type = ""; }
    if (!defined $n) { $n = 1; }
    while ($self=getNextSibling($self)) {
        if (nodeMatches($self,$type,$aname,$avalue)) {
            $n--;
            if ($n<=0) { return($self); }
        }
    }
    return(undef);
}
sub getFollowingSibling {
    my ($self) = @_;
    return($self->getNextSibling());
}

# No select for root, self, attribute, or namespace axes.


###############################################################################
#
sub getLeftBranch {
    my ($self) = @_;
    (defined $self) || return(undef);
    while (my $fc = $self->getFirstChild()) {
        $self = $fc;
    }
    return($self);
}

sub getRightBranch {
    my ($self) = @_;
    (defined $self) || return(undef);
    while (my $fc = $self->getLastChild()) {
        $self = $fc;
    }
    return($self);
}

sub getDepth {
    my ($self) = @_;
    my $d = 0;
    while (defined $self) {
        $d++;
        $self = $self->getParentNode();
    }
    return($d);
}

sub getChildIndex {  # First child is [0]!
    my ($self) = @_;
    my $par = $self->parentNode;
    if (not $par) { return(-1); }
    for (my $i=0; $i<scalar($par->childNodes); $i++) {
        if $par->childNodes[$i]->isSameNode(self): return(i);
    }
    return(0);
}


sub getFQGI {
    my ($self) = @_;
    my $f = "";
    while (defined $self) {
        $f = "/" . $self->getNodeName() . $f;
        $self = $self->getParentNode();
    }
    return($f);
}

sub isWithin {
    my ($self, $gi) = @_;
    while (defined $self) {
        ($self->getNodeName() eq $gi) && return(1);
        $self = $self->getParentNode();
    }
    return(0);
}

sub getXPointer {
    my ($self, $useID) = @_;
    my $f = "";
    while (defined $self) {
        if ($useID && $self->getAttribute('id')) {
            return($self->getAttribute('id') . "/" . $f);
        }
        $f = "/" . $self->getParentNode()->getChildIndex($self) . $f;
        $self = $self->getParentNode();
    }
    return($f);
}
sub XPointerCompare {
    my ($self,$xp1,$xp2) = @_;
    my @t1 = split(/\//,$xp1);
    my @t2 = split(/\//,$xp2);
    for (my $i=0; $i<scalar @t1 && $i<scalar @t2; $i++) {
        if ($t1[$i] < $t2[$i]) { return(-1); }
        if ($t1[$i] > $t2[$i]) { return( 1); }
    }
    # At least one of them ran out...
    return (scalar @t1 <=> scalar @t2);
}

sub nodeCompare {
    my ($self,$other) = @_;
    return(XPointerCompare($self,
               getXPointer($self),getXPointer($other)));
}

sub XPointerInterpret {
    my ($self, $xp) = @_;
    my $document = $self->ownerDocument();
    my $node = $document->getDocumentElement();
    my @t = split(/\//,$xp);
    if ($t[0] !~ m/^\d+$/) {                     # Leading ID
        my $idNode = $document->getNamedNode($t[0]);
        ($idNode) || return(undef);
    }
    for (my $i=0; $i<scalar @t; $i++) {
        my $node = $node->getChildAtIndex($t[$i]);
        (defined $node) || return(undef);
    }
    return($node);
}

###############################################################################
# Check if a node matches the supported selection constraints:
#
#   An integer DOM nodeType number
#   /regex/ to match node name (like BS4)
#   '*' or '' (default) for any element
#   '#' plus a DOM nodeType name (can omit '_NODE', or abbreviate)
#   '#WSOTN' for non-white-space-only text nodes,
#   '#NWSOTN' for anything that's not a WSOTN
#   '#ET' for elements and non-white-space-only text nodes
#   A literal node name
#
#     If aname is non-nil, attribute must exist
#     If avalue is non-nill, attribute aname must = avalue.
# Used by all the selectAXIS() methods.
#
# @TODO UPDATE TO MATCH AJICSS.js.
#
sub nodeMatches {
    my ($self, $type, $aname, $avalue) = @_;

    if (defined $type && $type ne "") {              # check type constraint
        if ($type eq "*") {
            if ($self->getNodeType!=1) { return(0); }
        }
        else {
            if ($self->getNodeName() ne $type) { return(0); }
        }
    }

    if (!defined $aname) {                           # No attribute constraint
        return(1);
    }
    if ($self->getNodeName eq "#text") {
        return(0);
    }
    my $thisvalue = $self->getAttribute($aname);
    if (!defined $thisvalue) {                       # attr specified, absent
        return(0);
    }
    if (!defined $avalue || $thisvalue eq $avalue) { # attr matches
        return(1);
    }
    return(0);
}


# Search upward to find an assignment to an attribute -- like xml:lang.
#
sub getInheritedAttribute {
    my ($self,$aname) = @_;
    do {
        my $avalue = $self->getAttribute($aname);
        if (defined $avalue) { return($avalue); }
        $self = $self->getParentNode();
    } while ($self);
    return(undef);
}

sub getStartTag {
    my ($self) = @_;
    $buf = "<%s" % (self->nodeName);
    if (self->getAttribute('id')) {
        $buf += ' id="%s"' % (self->getAttribute('id'));
    }
    foreach a (self->attributes) {
        if (a == 'id'): next;
        $buf += ' %s="%s"' % (a, self->getAttribute(a));
    $buf += ">";
    return $buf;
}

sub getEndTag {
    my ($self, $comment) = @_;
    if (undef $comment) { $comment = 1; }
    $buf = "</%s>" % (self->nodeName);
    if (comment and self->getAttribute('id')) {
        $buf += '<!-- id="%s" -->' % (self->getAttribute('id'));
    }
    return $buf;
}

# Assemble the entire attribute list, escaped as needed to write out as XML.
#
sub getEscapedAttributeList {
    my ($self) = @_;
    my $buf = "";
    (defined $self) || return(undef);
    my $alist = $self->getAttributes();
    (defined $alist) || return($buf);
    for (my $i=0; $i<$alist->getLength(); $i++) {
        my $anode = $alist->item($i);
        my $aname  = $anode->getName();
        my $avalue = DomExtensions::escapeXmlAttribute($anode->getValue());
        $buf .= " $aname=\"$avalue\"";
    }
    return($buf);
}

sub deleteWhiteSpaceNodes {
    return removeWhiteSpaceNodes(@_);
}
sub removeWhiteSpaceNodes {
    my ($self) = @_;
    forEachNode($self,\&removeWhiteSpaceNodesCB,undef);
}
sub removeWhiteSpaceNodesCB {
    my ($self) = @_;
    ($self->getNodeName eq "#text") || return;
    my $t = $self->getData();
    ($t =~ m/[^\s]/) && return;
    $self->getParentNode()->removeChild($self);
}

sub removeNodesByTagName {
    my ($self, $nodeName) = @_;
    my @nodes = $self->getElementsByTagName($nodeName);
    my $ct = 0;
    for (my $node in @nodes) {
        $node->parent->removeChild($node);
        $ct += 1;
    return $ct;

sub untagNodesByTagName {
    my ($self, $nodeName) = @_;
    for my $t in $self->getElementsByTagName($nodeName) {
        my $tn = $self->getDocument->createTextNode($t->innerText());
        $t->parentNode->replaceChild($t, $tn);
    }
    return;


###############################################################################
#
sub normalizeAllSpace {
    my ($self) = @_;
    forEachNode($self,\&normalizeAllSpaceCB,undef);
}
sub normalizeAllSpaceCB {
    my ($self) = @_;
    ($self->getNodeName eq "#text") || return;
    $self->setData(DomExtensions::normalizeSpace($self->getData()))
}

sub addElementSpaces {
    my ($self, $exceptions) = @_;
    # Add spaces around all elements *except* those specified.
    # This is useful because most elements entail word-boundaries (say, things
    # CSS would consider display:block). But little elements may not: such as
    # HTML b, i, etc., and TEI var, sic, corr, etc.
    #
    die "Unimplemented\n";
}

###############################################################################
#
sub insertPrecedingSibling {
    my ($self, $node) = @_;
    my $par = $self->getParentNode();
    $par->insertBefore($node,$self);
    return($node);
}

sub insertFollowingSibling {
    my ($self, $node) = @_;
    my $par = $self->getParentNode();
    my $r = $self->getNextSibling();
    if ($r) {
        $par->insertBefore($node,$r);
    }
    else {
        $par->appendChild($node);
    }
    return($node);
}

sub insertParent {
    my ($self, $type) = @_;
    my $new = $self->getOwnerDocument->createElement($type);
    my $par = $self->getParentNode();
    $par->replaceChild($new,$self);
    $new->appendChild($self);
    return($new);
}


###############################################################################
# Following-sibling goes away, but its *text* is appended to the $node.
# Note: At present, this drops any sub-structure of the current and sibling.
#
sub mergeWithFollowingSiblingText {
    my ($cur) = @_;
    (defined $cur) || return(undef);

    my $doc = $cur->getOwnerDocument();
    my $par = $cur->getParentNode();
    my $sib = $cur->getNextSibling;
    if (!defined $sib) {
        vMsg(0,"mergeWithFollowingSiblingText: no sibling");
        return;
    }

    my $curText = collectAllText($cur,"") .
        " " . collectAllText($sib,"");
    $curText =~ s/\s\s+/ /g;

    while ($cur->hasChildNodes()) {
        $cur->removeChild($cur->getFirstChild());
    }
    $cur->appendChild($doc->createTextNode($curText));
    $par->removeChild($sib);
} # mergeWithFollowingSibling


###############################################################################
# Take a block of contiguous siblings and enclose them in a new intermediate
# parent node (which in inserted at the level they *used* to be at).
#
sub groupSiblings {
    my ($self, $first, $last, $newParentType) = @_;
    if (!defined $first || !defined $last) {
        warn "Must supply first and last to groupSiblings\n";
        return;
    }
    my $oldParent = $first->getParentNode();
    my $oldParent2 = $last->getParentNode();
    ($oldParent == $oldParent2) || warn
        "groupSiblings: first and last are not siblings!\n";
    my $newParent = $first->getOwnerDocument()->createElement($newParentType);
    $oldParent->insertChildBefore($newParent,$first);

    my $next;
    for (my $cur = $first; defined $cur; $cur=$next) {
        $next = $cur->getNextSibling();
        my $moving = $oldParent->removeChild($cur);
        $newParent->insertBefore($moving,undef);
    }
} # groupSiblings


###############################################################################
# Remove the given node, promoting all its children.
#
sub promoteChildren {
    my ($self) = @_;
    my $parent = $self->getParentNode();
    my $next;
    for (my $cur = $self->getFirstChild(); defined $cur; $cur=$next) {
        $next = $cur->getNextSibling();
        my $moving = $self->removeChild($cur);
        $parent->insertBefore($moving,$parent);
    }
    $parent->deleteChild($self);
}


###############################################################################
# Traverse a subtree given its root, and call separate callbacks before
# and after traversing each subtree. Callbacks might, for example,
# respectively generate the start- and end-tags for the element. Callbacks
# are allowed to be undef if not needed.
#
# If a callback returns true, we stop traversing.
#
sub forEachNode {
    my ($self,$callbackA,$callbackB,$depth) = @_;
    if (!defined $depth) { $depth = 1; }
    (defined $self) || return(1);
    my $name = $self->getNodeName();
    if (defined $callbackA) {
        if ($callbackA->($self,$name,$depth)) { return(1); }
    }
    if ($self->hasChildNodes()) {
        #print "Recursing for child nodes at level " . ($depth+1) . "\n";
        for my $ch ($self->getChildNodes()) {
            my $rc = forEachNode($ch,$callbackA,$callbackB,$depth+1);
            if ($rc) { return(1); }
        }
    }
    if (defined $callbackB) {
        if ($callbackB->($self,$name,$depth)) { return(1); }
    }
    return(0); # succeed
} # forEachNode


sub forEachTextNode {
    my ($self,$callbackA,$callbackB,$depth) = @_;
    if (!defined $depth) { $depth = 1; }
    (defined $self) || return(1);
    my $name = $self->getNodeName();
    if (defined $callbackA && $name eq "#text") {
        if ($callbackA->($self,$name,$depth)) { return(1); }
    }
    if ($self->hasChildNodes()) {
        #print "Recursing for child nodes at level " . ($depth+1) . "\n";
        for my $ch ($self->getChildNodes()) {
            my $rc = forEachTextNode($ch,$callbackA,$callbackB,$depth+1);
            if ($rc) { return(1); }
        }
    }
    if (defined $callbackB && $name eq "#text") {
        if ($callbackB->($self,$name,$depth)) { return(1); }
    }
    return(0); # succeed
} # forEachTextNode

sub forEachElement {
    my ($self, $callbackA,$callbackB,$depth) = @_;
    if (!defined $depth) { $depth = 1; }
    (defined $self) || return(1);
    my $name = $self->getNodeName();
    if (defined $callbackA && $self->getNodeType==1) {
        if ($callbackA->($self,$name,$depth)) { return(1); }
    }
    if ($self->hasChildNodes()) {
        #print "Recursing for child nodes at level " . ($depth+1) . "\n";
        for my $ch ($self->getChildNodes()) {
            my $rc = forEachElement($ch,$callbackA,$callbackB,$depth+1);
            if ($rc) { return(1); }
        }
    }
    if (defined $callbackB && $self->getNodeType==1) {
        if ($callbackB->($self,$name,$depth)) { return(1); }
    }
    return(0); # succeed
} # forEachElement

sub forEachElementOfType {
    my ($self,$elementType, $callbackA,$callbackB,$depth) = @_;
    if (!$depth) { $depth = 1; }
    if (!$self)  { warn "No element specified.\n"; return(1); }
    if (!$elementType) {
        warn "Bad element type '$elementType' specified.\n"; return(1);
    }
    my $name = $self->getNodeName();
    if (defined $callbackA && $self->getNodeType==1 &&
         $self->getNodeName =~ m/$elementType/) {
        if ($callbackA->($self,$name,$depth)) { return(1); }
    }
    if ($self->hasChildNodes()) {
        #print "Recursing for child nodes at level " . ($depth+1) . "\n";
        for my $ch ($self->getChildNodes()) {
            my $rc = forEachElementOfType(
                $ch,$elementType,$callbackA,$callbackB,$depth+1);
            if ($rc) { return(1); }
        }
    }
    if (defined $callbackB && $self->getNodeType==1 &&
         $self->getNodeName =~ m/$elementType/) {
        if ($callbackB->($self,$name,$depth)) { return(1); }
    }
    return(0); # succeed
} # forEachElementOfType


###############################################################################
# Cat together all descendant text nodes, with delimiters between.
#
sub collectAllText {
    my ($self, $delim, $depth) = @_;
    (defined $self) || return("");
    if (!defined $delim) { $delim = " "; }
    if (!defined $depth) { $depth = 1; }
    my $name = $self->getNodeName();
    my $textBuf = "";
    if ($self->getNodeName() eq "#text") {
        my $dat = $self->getData();
        if ($dat) {
            $textBuf = ($depth>1 ? $delim:"") . $dat;
        }
    }
    elsif ($self->hasChildNodes()) {
        for my $ch ($self->getChildNodes()) {
            $textBuf .= collectAllText($ch,$delim,$depth+1);
        }
    }
    return($textBuf);
} # collectAllText

# getTextNodesIn
#
# Based on https://stackoverflow.com/questions/298750/
#
sub getTextNodesIn {
    my ($node) = @_;
    textNodes = []
    if (node.nodeType == Node.TEXT_NODE) {
        textNodes.append(node);
    }
    else {
        for i in (range(len(node.childNodes))) {
            textNodes.extend(getTextNodes(node.childNodes[i]));
    }
    return textNodes;
}

###############################################################################
# Collect a subtree as WF XML, with appropriate escaping. Can also
# put a delimiter before each start-tag; if it contains '\n', then the
# XML will also be hierarchically indented. -color applies.
#
# NOT FINISHED.
#
sub collectAllXml2 {
    my ($self,$delim,$useDtdKnowledge) = @_;
    my $e = new emitter("STRING");
    warn ("\n********* Starting collectAllXml2 at $self\n");
    collectAllXml2r($self,$delim,$useDtdKnowledge,$e,1);
    return($e->{string});
}

sub collectAllXml2r {
    my ($self,$delim,$useDtdKnowledge,$theEmitter,$depth);

    if (!defined $delim) { $delim = " "; }
    if (!defined $depth) { $depth = 1; }

    warn (("  " x $depth) . "in collectAllXml2r for $self\n");

    # Calculate whitespace to put around the element
    #
    my $nl = "\n"; my $iString = "  ";
    my $name = $self->getNodeName();
    my $indent = my $postIndent = "";
    my $isEmpty = 0;
    if ($name eq "#text") {
        #warn "got #text, type " . $self->getNodeType() . ", data: " .
        #    $self->getData() . "\n";
        # no indents
    }
    if ($useDtdKnowledge) {
        if (!$dtdk) {
            $dtdk = new DtdKnowledge(
                "$ENV{HOME}/bin/SJD/tupleSets.xsv/HtmlKnowledge.xsv");
        }
        my $con = $dtdk->getContent($name);
        $isEmpty = ($con && $con eq "empty") ? 1:0;
        my $dtype = $dtdk->getDisplay($name);
        if ($dtype && $dtype ne "inline") {
            $indent = $dtdk->getPreSpace($name);
            $postIndent = $dtdk->getPostSpace($name);
            $indent = ($indent > 0) ?
                (($nl x $indent) . ($iString x $depth)) : "";
            $postIndent = ($postIndent > 0) ?
                ($nl x $postIndent) : "";
        }
    }
    else {
        if ($delim =~ m/$nl/) {
            $indent = ($iString x $depth);
            $postIndent = "$nl";
        }
        else {
            $indent = $delim;
        }
    }

    # Assemble the data and/or markup
    #
    my $ntype = $self->getNodeType();
    if ($ntype eq XML::DOM::ELEMENT_NODE) {                 # 1 ELEMENT
        my $textBuf = "$indent<$name" .
            getEscapedAttributeList($self) .
            ($isEmpty ? "/>" : ">");
        $theEmitter->emit($textBuf);
        for my $ch ($self->getChildNodes()) {
            warn ("\n********* Recursing from node of type '$name'\n");
            collectAllXml2r(
                $ch,$delim,$useDtdKnowledge,$theEmitter,$depth+1);
        }
        # If we or the last child ended with a line-break, indent end-tag.
        if ($theEmitter->lastCharEmitted() eq $nl) {
            $theEmitter->emit($iString x $depth);
        }
        $theEmitter->emit("</$name>$postIndent");
    } # ELEMENT_NODE
    elsif ($ntype eq XML::DOM::ATTRIBUTE_NODE) {            # 2 ATTR
        die "Why are we seeing an attribute node?\n";
    }
    elsif ($ntype eq XML::DOM::TEXT_NODE) {                 # 3 TEXT
        $theEmitter->emit(DomExtensions::escapeXmlContent($self->getData()));
    }
    elsif ($ntype eq XML::DOM::CDATA_SECTION_NODE) { }      # 4
    elsif ($ntype eq XML::DOM::ENTITY_REFERENCE_NODE) { }   # 5
    elsif ($ntype eq XML::DOM::ENTITY_NODE) { }             # 6
    elsif ($ntype eq XML::DOM::PROCESSING_INSTRUCTION_NODE) { # 7 PI
        $theEmitter->emit("<?" . $self->getNodeName() .
                          " " . $self->getData() . "?>");
    }
    elsif ($ntype eq XML::DOM::COMMENT_NODE) {              # 8 COMMENT
        $theEmitter->emit("$indent<!--" . $self->getData() . "-->");
        if ($delim=~m/\n/ || $useDtdKnowledge) {
            $theEmitter->emit($nl);
        }
    }
    elsif ($ntype eq XML::DOM::DOCUMENT_NODE) { }           # 9
    elsif ($ntype eq XML::DOM::DOCUMENT_TYPE_NODE) { }      # 10
    elsif ($ntype eq XML::DOM::DOCUMENT_FRAGMENT_NODE) { }  # 11
    elsif ($ntype eq XML::DOM::NOTATION_NODE) { }           # 12
    else {
        die "startCB: Bad DOM node type returned: $ntype.\n";
    }
    return();
} # collectAllXml2r



###############################################################################
# Collect a subtree as WF XML, with appropriate escaping. Can also
# put a delimiter before each start-tag; if it contains '\n', then the
# XML will also be hierarchically indented. -color applies.
#
sub collectAllXml {
    my ($self,$delim,$useDtdKnowledge,$depth) = @_;
    if (!defined $delim) { $delim = " "; }
    if (!defined $depth) { $depth = 1; }

    my $name = $self->getNodeName();
    my $ntype = $self->getNodeType();

    # Calculate whitespace to put around the element
    #
    my $nl = "\n";
    my $iString = "  ";
    my $indent = "";
    my $isEmpty = 0;
    if (!$useDtdKnowledge) {
        $indent = ($delim =~ m/$nl/) ? ($iString x $depth) : $delim;
    }
    else {
        if (!$dtdk) {
            $dtdk = new DtdKnowledge(
                "$ENV{HOME}/bin/SJD/tupleSets/HtmlKnowledge.xsv");
        }
        my $con = $dtdk->getContent($name);
        $isEmpty = ($con && $con eq "empty") ? 1:0;
        my $dtype = $dtdk->getDisplay($name);
        if ($dtype && $dtype ne "inline") {
            $indent = $dtdk->getPreSpace($name);
            $indent = ($indent > 0) ?
                (($nl x $indent) . ($iString x $depth)) : "";
        }
    }

    # Assemble the data and/or markup
    #
    my $textBuf = "";
    if ($ntype eq XML::DOM::ELEMENT_NODE) {                 # 1 ELEMENT
        $textBuf .= ($iString x $depth) . "<$name" .
            getEscapedAttributeList($self);
        if ($isEmpty) {
            $textBuf .= "/>";
        }
        else {
            $textBuf .= ">";
            for my $ch ($self->getChildNodes()) {
                $textBuf .= collectAllXml($ch,$delim,1,$depth+1);
            }
            if ($textBuf =~ m/$nl$/) {
                $textBuf .=  ($iString x $depth);
            }
            $textBuf .= "</$name>$nl";
        }
    } # ELEMENT_NODE
    elsif ($ntype eq XML::DOM::ATTRIBUTE_NODE) {            # 2 ATTR
        die "Why are we seeing an attribute node?\n";
    }
    elsif ($ntype eq XML::DOM::TEXT_NODE) {                 # 3 TEXT
        $textBuf .= DomExtensions::escapeXmlContent($self->getData());
    }
    elsif ($ntype eq XML::DOM::CDATA_SECTION_NODE) { }      # 4
    elsif ($ntype eq XML::DOM::ENTITY_REFERENCE_NODE) { }   # 5
    elsif ($ntype eq XML::DOM::ENTITY_NODE) { }             # 6
    elsif ($ntype eq XML::DOM::PROCESSING_INSTRUCTION_NODE) { # 7 PI
        $textBuf .= "<?" . $self->getNodeName() . " " . $self->getData() . "?>";
    }
    elsif ($ntype eq XML::DOM::COMMENT_NODE) {              # 8 COMMENT
        $textBuf .= "$indent<!--" . $self->getData() . "-->";
        if ($delim=~m/\n/ || $useDtdKnowledge) {
            $textBuf .= "$nl";
        }
    }
    elsif ($ntype eq XML::DOM::DOCUMENT_NODE) { }           # 9
    elsif ($ntype eq XML::DOM::DOCUMENT_TYPE_NODE) { }      # 10
    elsif ($ntype eq XML::DOM::DOCUMENT_FRAGMENT_NODE) { }  # 11
    elsif ($ntype eq XML::DOM::NOTATION_NODE) { }           # 12
    else {
        die "startCB: Bad DOM node type returned: $ntype.\n";
    }
    return($textBuf);
} # collectAllXml


###############################################################################
# Write the whole thing to some file.
# See also XML::DOM::Node::toString(), printToFile(), printToFileHandle().
#
BEGIN {
    my $fhGlobal;

sub export {
    my ($someElement, $fh, $includeXmlDecl, $includeDoctype) = @_;
    $fhGlobal = $fh;
    if ($includeXmlDecl) {
        print $fh "<?xml version=\"1.0\" encoding=\"utf8\"?>\n";
    }
    if ($includeDoctype) {
        my $rootGI = $someElement->getName;
        print $fh "<!DOCTYPE $rootGI PUBLIC '' '' []>\n";
    }
    forEachNode($someElement,\&startCB,\&endCB,0);
}

sub startCB {
    my ($self) = @_;
    my $buf = "";
    my $typeName = $self->getNodeType;
    if ($typeName eq XML::DOM::ELEMENT_NODE) {                   # 1
        $buf = "<" . $self->getNodeName . getEscapedAttributeList($self) . ">";
    }
    elsif ($typeName eq XML::DOM::ATTRIBUTE_NODE) {              # 2
    }
    elsif ($typeName eq XML::DOM::TEXT_NODE) {                   # 3
        $buf = $self->getData();
    }
    elsif ($typeName eq XML::DOM::CDATA_SECTION_NODE) {          # 4
        $buf = "<![CDATA[";
    }
    elsif ($typeName eq XML::DOM::ENTITY_REFERENCE_NODE) {       # 5
    }
    elsif ($typeName eq XML::DOM::ENTITY_NODE) {                 # 6
    }
    elsif ($typeName eq XML::DOM::PROCESSING_INSTRUCTION_NODE) { # 7
        $buf = "<?" . $self->getData() . "?>";
    }
    elsif ($typeName eq XML::DOM::DOCUMENT_NODE) {               # 8
    }
    elsif ($typeName eq XML::DOM::DOCUMENT_NODE) {               # 9
    }
    elsif ($typeName eq XML::DOM::DOCUMENT_TYPE_NODE) {          # 10
        $buf = "<!DOCTYPE>";
    }
    elsif ($typeName eq XML::DOM::DOCUMENT_FRAGMENT_NODE) {      # 11
    }
    elsif ($typeName eq XML::DOM::NOTATION_NODE) {               # 12
    }

    # Following are extensions to DOM (unfinished)
    elsif ($typeName eq XML::DOM::ELEMENT_DECL_NODE) {           # 13
        $buf = "<!ELEMENT " . $self->getNodeName() . " ANY>";
    }
    elsif ($typeName eq XML::DOM::ATT_DEF_NODE) {                # 14
    }
    elsif ($typeName eq XML::DOM::XML_DECL_NODE) {               # 15
        $buf = "<?xml version=\"1.0\" encoding=\"utf8\">";
    }
    elsif ($typeName eq XML::DOM::ATTLIST_DECL_NODE) {           # 16
        $buf = "<!ATTLIST " . $self->getNodeName() . "\n";
    }
    else {
        die "startCB: Bad DOM node type returned: self->getNodeType.\n";
    }
    print $fhGlobal, $buf;
} # startCB

sub endCB {
    my ($self) = @_;
    my $buf = "";
    my $typeName = $self->getNodeType();

    if ($typeName eq XML::DOM::ELEMENT_NODE) {                   # 1
        $buf = "</" . $self->getNodeName . ">";
    }
    elsif ($typeName eq XML::DOM::ATTRIBUTE_NODE) {              # 2
    }
    elsif ($typeName eq XML::DOM::TEXT_NODE) {                   # 3
    }
    elsif ($typeName eq XML::DOM::CDATA_SECTION_NODE) {          # 4
        $buf = "]]>";
    }
    elsif ($typeName eq XML::DOM::ENTITY_REFERENCE_NODE) {       # 5
    }
    elsif ($typeName eq XML::DOM::ENTITY_NODE) {                 # 6
    }
    elsif ($typeName eq XML::DOM::PROCESSING_INSTRUCTION_NODE) { # 7
    }
    elsif ($typeName eq XML::DOM::COMMENT_NODE) {                # 8
    }
    elsif ($typeName eq XML::DOM::DOCUMENT_NODE) {               # 9
    }
    elsif ($typeName eq XML::DOM::DOCUMENT_TYPE_NODE) {          # 10
    }
    elsif ($typeName eq XML::DOM::DOCUMENT_FRAGMENT_NODE) {      # 11
    }
    elsif ($typeName eq XML::DOM::NOTATION_NODE) {               # 12
    }

    # Following are extensions to DOM
    elsif ($typeName eq XML::DOM::ELEMENT_DECL_NODE) {           # 13
    }
    elsif ($typeName eq XML::DOM::ATT_DEF_NODE) {                # 14
    }
    elsif ($typeName eq XML::DOM::XML_DECL_NODE) {               # 15
    }
    elsif ($typeName eq XML::DOM::ATTLIST_DECL_NODE) {           # 16
        $buf = ">\n";
    }
    else {
        die "endCB: Bad DOM node type returned: self->getNodeType.\n";
    }
    print $fhGlobal, $buf;
} # endCB

} # END


###############################################################################
#
sub escapeXmlAttribute {
    my ($s) = @_;
    # We quietly delete the non-XML control characters!
    $s =~ s/[\x{0}-\x{8}\x{b}\x{c}\x{e}-\x{1f}]//g;
    $s =~ s/&/&amp;/g;
    $s =~ s/</&lt;/g;
    $s =~ s/"/&quot;/g;
    return($s);
}
sub escapeXmlContent {
    my ($s) = @_;
    # We quietly delete the non-XML control characters!
    $s =~ s/[\x{0}-\x{8}\x{b}\x{c}\x{e}-\x{1f}]//g;
    $s =~ s/&/&amp;/g;
    $s =~ s/</&lt;/g;
    $s =~ s/]]>/]]&gt;/g;
    #$s =~ s/"/&quot;/g;
    return($s);
}
sub escapeASCII {
    my ($s) = @_;
    $s =~ s/(\P{IsASCII})/ { sprintf("&#x%04x;",ord($1)); }/ge;
    $s = escapeXmlContent($s);
    return($s);
}
sub unescapeXml {
    # WARNING: Does not do HTML named entities!
    my ($s) = @_;
    $s =~ s/&lt;/</g;
    $s =~ s/&gt;/>/g;
    $s =~ s/&quot;/"/g;
    $s =~ s/&apos;/'/g;
    $s =~ s/&#x([0-9a-f]+);/{ chr(hex($1)); }/gie;
    $s =~ s/&#([0-9]+);/{ chr($1); }/gie;
    $s =~ s/&amp;/&/g;
    return($s);
}
# This only normalizes *XML* whitespace, not Perl or Unicode.
sub normalizeSpace {
    my ($s) = @_;
    $s =~ s/\s+/ /g;
    $s =~ s/^\s+//g;
    $s =~ s/\s+$//g;
    return($s);
}


###############################################################################
###############################################################################
#
package emitter;

sub new {
    my ($class, $type, $arg) = @_;

    my $self = {
        type        => $type,
        lastChar    => "",
    };

    if ($type eq "STRING") {
        $self->{string} = "";
    }
    elsif ($type eq "FILE") {
        $self->{file} = $arg;
    }
    elsif ($type eq "FH") {
        $self->{fh} = $arg;
    }
    elsif ($type eq "CALLBACK") {
        $self->{cb} = $arg;
    }
    else {
        die "new emitter: unknown type '$type'.\n";
    }

    bless $self, $class;
}

sub emit {
    my ($self, $text) = @_;
    if (length($text)>0) {
        $self->{lastChar} = substr($text,length($text)-1);
    }
    if ($self->{type} eq "STRING") {
        $self->{string} .= $text;
    }
    elsif ($self->{type} eq "FILE") {
        my $f = $self->{file};
        print $f $text;
    }
    elsif ($self->{type} eq "FH") {
        my $fh = $self->{fh};
        print $fh $text;
    }
    else {
        $self->{cb}->($text);
    }
}

sub lastCharEmitted {
    my ($self) = @_;
    return($self->{lastChar});
}


###############################################################################
###############################################################################
# Index should be a separate object.
# Adds every element that has a given attribute, to a hash, keyed on that
# attribute's value. Hopes the values are unique.
#
package Dom::Index;

sub new {
    my ($class, $document, $aname) = @_;
    my %index = ();
    my $node = $document->getDocumentElement();
    do {
        if ($node->getNodeType==1) {  # elements
            my $key = $node->getAttribute($aname);
            if (defined $key) { $index{$key} = $node; }
        }
        $node = $node->getFolowing();
    } while ($node);
    my $self = {
        document    => $document,
        attrName    => $aname,
        theIndex    => \%index,
    };
    bless $self, $class;
    return(\%index);
}

sub find {
    my ($self, $avalue) = @_;
    my $indexRef = $self->{theIndex};
    my %index = %$indexRef;
    return($index{$avalue});
}



###############################################################################
###############################################################################
###############################################################################
#

=pod

=head1 Notes

An XML-manipulation package that sits on top of XML::DOM
and provides higher-level, XPath-like methods.

B<Note>: These routines do not hang off an object, since there's no easy
way to get XML::DOM objects to inherit them, or to get XML::DOM constructors
to create our objects.
So instead of $node->getFQGI(), etc, use getFQGI($node).

It's very often useful to walk around the XPath 'axes' in a DOM tree.
When doing so, it's often useful to consider only element nodes,
or only #text nodes, or only element nodes of a certain element type, or
with a certain attribute or attribute-value pair.

=head2 Node-selection methods

For the relevant XPath axes there are methods that will return the n-th
node of a given type and/or attribute along that axis.
For example (using the Child axis, but you can substitute
Descendant, PrecedingSibling, FollowingSibling, Preceding, Following,
or Ancestor:

    selectChild(node,n,type,attributeName,attributeValue)

This will return the I<n>th child of I<node> which:
is of the given element I<type>,
and has the given I<attributeName>=I<attributeValue> pair.

=over

=item * I<n> must currently be positive, though using negative numbers
to count back from the end will likely be added.

=item * If I<type> is undefined or '', any node type is allowed;
if it is '*', any *element* is allowed
(in both cases, attribute constraints may still apply).

=item * If I<attributeName> is undefined or '', no attribute is required.

=item * If I<attributeValue> is undefined or '', the attribute named
by I<attributeName> must be present, but may have any value (including '').

The self, ancestor-or-self, descendant-or-self, attribute, and namespace
axes are I<not> supported for I<select>.

This is far
less power than XPath provides, but it facilitates many programming tasks,
such as scanning for all elements of a given type (which I deem very common).

=back


=head2 Tree information methods

=over

=item * B<getInheritedAttribute(node,name)>

Return the value of attribute I<name>, from the first node along the
I<ancestor-or-self> axis of I<node> that specifies it.
Thus, the attribute's value is inherited down the tree, similar to I<xml:lang>.

=item * B<getLeftBranch>(node)

Return the leftmost descendant of I<node>.
If I<node>'s first child has no children of its own, then it is
also I<node>'s first descendant; otherwise, it will not be.

=item * B<getRightBranch>(node)

Return the rightmost (last) descendant of I<node>.

=item * B<getDepth>(node)

Return how deeply nested I<node> is (the document element is I<1>).

=item * B<isWithin>(I<node>, I<type>)

Return 1 if I<node> is, or is within, an element of the given I<type>;
otherwise return 0.

=item * B<getFQGI>(node)

Return the list of element types of I<node>'s
ancestors, from the root down, separated by '/'.
For example, "html/body/div/ul/li/p/b".
B<Note>: An FQGI does I<not> identify a specific element instance or location
in a document; for that, see I<getXPointer>().

=item * B<getXPointer>(node)

Return the XPointer child sequence to I<node>.
That is, the list of child-numbers for all the ancestors of the node, from
the root down, separated by '/'. For example, "1/1/5/2/1".
This is a fine unique name for the node's location in the document.

=item * B<XPointerCompare(x1,x2)>

Compare two XPointer child-sequences (see I<getXPointer>)
for relative document order, returning -1, 0, or 1.
This does not require actually looking at a document, so no document or
node is passed.

=item * B<nodeCompare(n1,n2)>

Compare two nodes for document order, returning -1, 0, or 1.

=item * B<XPointerInterpret(document,x)>

Interpret the XPointer child sequence in the string
I<x>, in the context of the given I<document>,
and return the node it identifies (or undef if there is no such node).

=item * B<getEscapedAttributeList>(node)

Return the entire attribute list for
I<node>, as needed to go within a XML start-tag. The attributes will be
quoted using the double-quote character ('"'), and any <, &, or " in them
will be replaced by the appropriate XML predefined charcter reference.

=back


=head2 Large-scale tree operations

=over

=item * B<deleteWhiteSpaceNodes>(node)

Delete all white-space-only text nodes that are descendants of I<node>.

=item * B<normalizeAllSpace>(node)

Do the equivalent of XSLT normalize-space()
on all text nodes in the subtree headed at I<node>.
B<Note>: This is I<not> the same as the XML::DOM::normalize() method, which
instead combines adjacent text nodes.

=item * B<insertPrecedingSibling>(I<node, newNode>)

=item * B<insertFollowingSibling>(I<node, newNode>)

=item * B<insertParent>(I<node, type>)

=item * B<mergeWithFollowingSiblingText>(node)

The following-sibling of I<node> is deleted, but its text content
is appended to I<node>.
This drops any sub-structure of the current and sibling.
New. See also the C<diffCorefs> command.

=item * B<groupSiblings(node1,node2,typeForNewParent)>

Group all the nodes from I<node1> through I<node2> together, under a
new node of type I<typeForNewParent>. Fails if the specified nodes are
not siblings or are not defined.

=item * B<promoteChildren>(node)

Remove I<node> but keep all its children, which becomes siblings at the same
place where I<node> was.

=item * B<splitNode>(node, childNode, offset)

Breaks I<node> into 2 new sibling nodes of the same type.
The children preceding and including node I<childNode> end up
under the first resulting sibling node; the rest under the second.
However, if I<childNode> is a text node and I<offset> is provided,
then I<childNode> will also be split, with the characters preceding and
including I<offset> (counting from 1) becoming a final text node under
the first new sibling node, and the rest become an initial text node
under the second.
(not yet supported)


=item * B<forEachNode(node,preCallback,postCallback)>

Traverse the subtree headed at I<node>,
calling the callbacks before and after traversing each node's subtree.

=item * B<forEachTextNode(node,preCallback,postCallback)>

Like I<forEachNode>(), but callbacks are I<only> called when at text nodes.

=item * B<forEachElement(node,preCallback,postCallback)>

Like I<forEachNode>(), but callbacks are I<only> called when at element nodes.

=item * B<forEachElementOfType(node,type,preCallback,postCallback)>

Like I<forEachNode>(), but callbacks are I<only> called when at
element nodes whose type name matches I<type> (which may be a regex).

=item * B<collectAllText(node,delimiter)>

Concatenate together the content of
all the text nodes in the subtree headed at I<node>,
putting I<delimiter> in between.

=item * B<collectAllXml2>(node,delimiter,useDtdInformation,inlines)

(newer version, in testing)

=item * B<collectAllXml>(node,delimiter,useDtdInformation,inlines)

Generate the XML representation for the subtree headed at I<node>.
It knows about elements, attributes, pis, comments, and appropriate escaping.
However, it won't do anything for CDATA sections (other than escape as
normal text), XML Declaration, DOCTYPE, or any DTD nodes.

If I<delimiter> contains a newline, the subtree
will include newlines and indentation.

If I<useDtdInformation> is true, HTML-specific element information
from HtmlKnowledge.xsv via C<DtdKnowledge.pm>
will be used to help with pretty-printing and empty-tag generation.

=item * B<export(element, fileHandle, includeXmlDecl, includeDoctype)>

Save the subtree headed at I<element> to the I<fileHandle>.
If I<includeXmlDecl> is present and true, start with an XML declaration.
If I<includeDoctype> is present and true, include a DOCTYPE declaration,
using I<element>'s type as the document-element name, and include any
DTD information that was available in the DOM (unfinished).
See also XML::DOM::Node::toString(),
XML::DOM::Node::printToFile(), XML::DOM::Node::printToFileHandle().

=back


=head2 Index (internal package)

=over

=item * B<buildIndex>(attributeName)

Return a hash table in which each
entry has the value of the specified I<attributeName> as key, and the element on
which the attribute occurred as value. This is similar to the XSLT 'key'
feature.

=item * B<find(value)>

=back


=head2 Character stuff (internal package)

(also available in I<SimplifyUnicode.pm>)

=over

=item * B<escapeXmlAttribute(string)>

Escape the string as needed for it to
fit in an attribute value (amp, lt, and quot).

=item * B<escapeXmlContent(string)>

Escape the string as needed for it to
fit in XML text content (amp, lt, and gt when following ']]').

=item * B<escapeASCII(string)>

Escape the string as needed for it to
fit in XML text content, *and* recodes and non-ASCII characters as XML
numeric characters references.

=item * B<unescapeXml(string)>

Change XML numeric characters references, as
well as references to the 5 pre-defined XML named entities, into the
corresponding literal characters.

=back



=head1 Related commands

C<SimplifyUnicode.pm> -- Reduces variations on Roman characters, ligatures,
dashes, whitespace charadters, quotes, etc. to more basic forms.

C<fakeParser.pm> -- a mostly-conforming XML/HTML parser, but able to survive
most WF errors and correct some. Supports push and pull interface, essentially
SAX.

C<xmlOutput.pm> -- Makes it easy to produce WF XML output. Provides methods
for escaping data correctly for each relevant context; knows about character
references, namespaces, and the open-element context; has useful methods for
inferring open and close tags to keep things in sync.

C<DtdKnowledge.pm> -- Provides pretty-printing specs for I<collectAllXml>().



=head1 Ownership

This work by Steven J. DeRose is licensed under a Creative Commons
Attribution-Share Alike 3.0 Unported License. For further information on
this license, see L<http://creativecommons.org/licenses/by-sa/3.0/>.

For the most recent version, see L<http://www.derose.net/steve/utilities/>.

=cut

    1;
