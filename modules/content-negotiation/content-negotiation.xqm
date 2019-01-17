xquery version "3.0";

module namespace cntneg="http://syriaca.org/cntneg";
(:~
 : Module for content negotiation based on work done by Steve Baskauf
 : https://github.com/baskaufs/guid-o-matic
 : Supported serializations: 
    - TEI to HTML
    - TEI to PDF
    - TEI to EPUB
    - TEI to RDF/XML
    - TEI to RDF/ttl
    - TEI to geoJSON
    - TEI to KML
    - TEI to Atom 
    - SPARQL XML to JSON-LD
 : Add additional serializations to lib folder and call them here.
 :
 : @author Winona Salesky <wsalesky@gmail.com>
 : @authored 2018-04-12
:)

import module namespace config="http://LiC.org/config" at "../config.xqm";

(:
 : Content serialization modules.
 : Additional modules can be added. 
:)
import module namespace tei2html="http://syriaca.org/tei2html" at "tei2html.xqm";
import module namespace tei2fo="http://LiC.org/tei2fo" at "tei2fo.xqm";
import module namespace epub="http://exist-db.org/xquery/epub" at "epub.xqm";
import module namespace tei2txt="http://syriaca.org/tei2txt" at "tei2txt.xqm";
import module namespace jsonld="http://syriaca.org/jsonld" at "jsonld.xqm";

(: These are needed for rending as HTML via existdb templating module, can be removed if not using 
import module namespace config="http://syriaca.org/config" at "config.xqm";
import module namespace templates="http://exist-db.org/xquery/templates" ;
:)

(: Namespaces :)
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace json = "http://www.json.org";
declare namespace tei = "http://www.tei-c.org/ns/1.0";
declare namespace http="http://expath.org/ns/http-client";
declare namespace fo="http://www.w3.org/1999/XSL/Format";

(:
 : Main content negotiation
 : @param $data - data to be serialized
 : @param $content-type - content-type header to determine serialization 
 : @param $path - url can be used to determine content-type if content-type header is not available
 :
 : @NOTE - This function has two ways to serialize HTML records, these can easily be swapped out for other HTML serializations, including an XSLT version: 
        1. tei2html.xqm (an incomplete serialization, used primarily for search and browse results)
        2. eXistdb's templating module for full html page display
:)
declare function cntneg:content-negotiation($data as item()*, $content-type as xs:string?, $path as xs:string?){
    let $page := if(contains($path,'/')) then tokenize($path,'/')[last()] else $path
    let $type := if(contains($path,'.')) then 
                    fn:tokenize($path, '\.')[fn:last()]
                 else if($content-type) then 
                    cntneg:determine-extension($content-type)
                 else 'html'
    let $file-name := if(contains($page,'.')) then substring-before($page,'.') else $page                 
    let $flag := cntneg:determine-type-flag($type)
    return 
        if($flag = ('tei','xml')) then 
            (response:set-header("Content-Type", "application/xml; charset=utf-8"),$data)                
        else if($flag = 'pdf') then 
            if($data/descendant-or-self::coursepack) then 
                let $pdf := xslfo:render(tei2fo:main($data), "application/pdf", ())
                return
                    response:stream-binary($pdf, "media-type=application/pdf", $file-name || ".pdf")
            else 
                let $pdf := xslfo:render(tei2fo:main($data/tei:TEI), "application/pdf", ())
                return
                response:stream-binary($pdf, "media-type=application/pdf", $file-name || ".pdf")
               
        else if($flag = 'epub') then
             (
                response:set-header("Content-Disposition", concat("attachment; filename=", concat($file-name, '.epub'))),
                response:stream-binary(
                    compression:zip( epub:epub($file-name, $data/tei:TEI), true() ),
                    'application/epub+zip',
                    concat($file-name, '.epub')
                )
            )                 
        else if($flag = 'txt') then
            (response:set-header("Content-Type", "text/plain; charset=utf-8"),
             response:set-header("Access-Control-Allow-Origin", "text/plain; charset=utf-8"),
             tei2txt:tei2txt($data))
        (: Output as html using existdb templating module or tei2html.xqm :)
        else
            (response:set-header("Content-Type", "text/html; charset=utf-8"),
             tei2html:tei2html($data))            
}; 

(: Utility functions to set media type-dependent values :)

(: Functions used to set media type-specific values :)
declare function cntneg:determine-extension($header){
    if (contains(string-join($header),"application/rdf+xml") or $header = 'rdf') then "rdf"
    else if (contains(string-join($header),"text/turtle") or $header = ('ttl','turtle')) then "ttl"
    else if (contains(string-join($header),"application/ld+json") or contains(string-join($header),"application/json") or $header = ('json','ld+json')) then "json"
    else if (contains(string-join($header),"application/tei+xml") or contains(string-join($header),"text/xml") or $header = ('tei','xml')) then "tei"
    else if (contains(string-join($header),"application/atom+xml") or $header = 'atom') then "atom"
    else if (contains(string-join($header),"application/vnd.google-earth.kmz") or $header = 'kml') then "kml"
    else if (contains(string-join($header),"application/geo+json") or $header = 'geojson') then "geojson"
    else if (contains(string-join($header),"text/plain") or $header = 'txt') then "txt"
    else if (contains(string-join($header),"application/pdf") or $header = 'pdf') then "pdf"
    else if (contains(string-join($header),"application/epub+zip") or $header = 'epub') then "epub"
    else "html"
};

declare function cntneg:determine-media-type($extension){
  switch($extension)
    case "rdf" return "application/rdf+xml"
    case "tei" return "application/tei+xml"
    case "tei" return "text/xml"
    case "atom" return "application/atom+xml"
    case "ttl" return "text/turtle"
    case "json" return "application/ld+json"
    case "kml" return "application/vnd.google-earth.kmz"
    case "geojson" return "application/geo+json"
    case "txt" return "text/plain"
    case "pdf" return "application/pdf"
    case "epub" return "application/epub+zip"
    default return "text/html"
};

(: NOTE: not sure this is needed:)
declare function cntneg:determine-type-flag($extension){
  switch($extension)
    case "rdf" return "rdf"
    case "atom" return "atom"
    case "tei" return "xml"
    case "xml" return "xml"
    case "ttl" return "turtle"
    case "json" return "json"
    case "kml" return "kml"
    case "geojson" return "geojson"
    case "html" return "html"
    case "htm" return "html"
    case "txt" return "txt"
    case "text" return "txt"
    case "pdf" return "pdf"
    case "epub" return "epub"
    default return $extension
};
