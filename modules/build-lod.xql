xquery version "3.1";
(:~  
 : Build GeoJSON file for all placeNames/@key  
 : NOTE: Save file to DB, rerun occasionally? When new data is added? 
 : Run on webhook activation, add new names, check for dups. 
:)

import module namespace config="http://LiC.org/config" at "config.xqm";
import module namespace tei2html="http://syriaca.org/tei2html" at "content-negotiation/tei2html.xqm";
import module namespace http="http://expath.org/ns/http-client";

import module namespace functx="http://www.functx.com";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace mads = "http://www.loc.gov/mads/v2";
declare namespace json = "http://www.json.org";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace util="http://exist-db.org/xquery/util";


declare function local:get-all-coords(){
    let $places := string-join(for $p in collection($config:data-root)//tei:placeName[@type=('tgn','TGN')]/@key group by $p return concat('"',$p,'"'),', ')
    let $query := 
        concat("
            SELECT ?key ?label ?lat ?long
            WHERE {
             	  ?key dc:identifier ?value;
             	       skos:prefLabel ?label;
             	       foaf:focus ?loc.
                   FILTER(?value IN (", $places, ")) 	       
             	  ?loc wgs:lat ?lat.
             	  ?loc wgs:long ?long.  
            	}")
    let $url := xs:anyURI(concat('http://vocab.getty.edu/sparql?query=',encode-for-uri($query)))        	
    let $request := 
            hc:send-request(
             <http:request http-version="1.1"  href="{$url}" method="get">
                 <http:header name="User-Agent" value="Opera"/>
                 <http:header name="Accept" value="application/sparql-results+xml"/>
            </http:request>)
    return $request[2] 
};

declare function local:specific-coords($rec as node()*){
    let $places := string-join(for $p in $rec/descendant::tei:placeName[@type=('tgn','TGN')]/@key group by $p return concat('"',$p,'"'),', ')
    let $query := 
        concat("
            SELECT distinct ?key ?label ?lat ?long
            WHERE {
             	  ?key dc:identifier ?value;
             	       foaf:focus ?loc;
             	       skos:prefLabel ?label.
             	  ?loc wgs:lat ?lat.
             	  ?loc wgs:long ?long.             	       
                   FILTER(?value IN (", $places, "))
                   FILTER(lang(?label) = 'en')
  
            	}")
    let $url := xs:anyURI(concat('http://vocab.getty.edu/sparql?query=',encode-for-uri($query)))        	
    let $request := 
            hc:send-request(
                 <http:request http-version="1.1"  href="{$url}" method="get">
                 <http:header name="User-Agent" value="LiC"/>
                 <http:header name="Accept" value="application/sparql-results+xml"/>
            </http:request>)
    return $request[2] 
};

(: Get external data if available :)
declare function local:get-external-person-data($type, $id){
    let $base-url := if($type = 'lcnaf') then 'http://id.loc.gov/authorities/names/' else () 
    let $url := xs:anyURI(concat($base-url,$id,'.madsxml.xml'))        	
    let $request := 
            hc:send-request(
                <http:request http-version="1.1"  href="{$url}" method="get">
                    <http:header name="User-Agent" value="LiC"/>
                    <http:header name="Accept" value="application/rdf+xml"/>
                </http:request>)
    return $request[2]//mads:authority[1]/mads:name[1]           
};

(:lat long:)
declare function local:make-place($nodes as node()*){
  <place xmlns="http://www.tei-c.org/ns/1.0">
    <idno>{normalize-space(string-join($nodes/*:binding[@name='key']//text()))}</idno>
    <placeName>{normalize-space(string-join($nodes/*:binding[@name='label']//text()))}</placeName>
    <location type="gps">
        <geo>
            <lat>{normalize-space(string-join($nodes/*:binding[@name='lat']//text()))}</lat>
            <long>{normalize-space(string-join($nodes/*:binding[@name='long']//text()))}</long>
        </geo>
    </location> 
    <listRelation>{
          let $key := tokenize(normalize-space(string-join($nodes/*:binding[@name='key']//text())),'/')[last()]
          for $recs in collection($config:data-root)//tei:placeName[@key = $key]
          let $id := document-uri(root($recs))
          group by $facet-grp := $id
          let $relationType := 
            if($recs/ancestor-or-self::tei:pubPlace) then 'pubPlace'
            else 'mention'
          return 
              <relation type="{$relationType}" ana="{$relationType}" active="{$facet-grp}" passive="{normalize-space(string-join($nodes/*:binding[@name='key']//text()))}">
                <desc>{root($recs[1])//tei:titleStmt/tei:title}</desc>
              </relation>
    }</listRelation>
  </place>
};

(:lat long:)
declare function local:make-person($nodes as node()*){
  let $personsCntl := collection($config:data-root)//tei:persName[@key][not(parent::tei:editor/parent::tei:titleStmt)]
  let $persons := collection($config:data-root)//tei:persName[not(@key)][not(parent::tei:editor/parent::tei:titleStmt)]
  return
  (for $p1 in $personsCntl
  group by $facet-grp := $p1/@key
  let $type := $p1[1]/@type
  return 
    if(string($facet-grp) = ('',' ')) then () else
    <person xmlns="http://www.tei-c.org/ns/1.0">
        <idno>{string($facet-grp)}</idno>
        {if($type = 'lcnaf') then 
            (let $name := local:get-external-person-data($type, $facet-grp)
            return $name,$p1[1])
         else $p1[1]}
        <listRelation>{
        for $recs in $p1
        let $id := document-uri(root($recs))
        group by $facet-grp := $id
        let $relationType := 
            if($p1/ancestor::tei:teiHeader) then 
                if($p1/parent::tei:editor) then 'editor'
                else if($p1/parent::tei:author) then 'author'
                else 'mention'
            else 'mention' 
        return 
            <relation type="{$relationType}" count="{count($recs)}" ana="{$relationType}" active="{$facet-grp}" passive="{string($p1[1]/@key)}">
                <desc>{root($recs[1])//tei:titleStmt/tei:title}</desc>
            </relation>
        }</listRelation>
    </person>,
    for $p1 in $persons
    group by $facet-grp := replace(lower-case($p1),"^\s+|^[mM]rs.\s|^[mM]r.\s|^\(|(['][s]+)|\)","")
    return
      if(string($facet-grp) = ('',' ')) then () else
      <person xmlns="http://www.tei-c.org/ns/1.0">
          <idno>{string($facet-grp)}</idno>
          {$p1[1]}
          <listRelation>{
          for $recs in $p1
          let $id := document-uri(root($recs))
          group by $facet-grp := $id
          let $relationType := 
            if($p1/ancestor::tei:teiHeader) then 
                if($p1/parent::tei:editor) then 'editor'
                else if($p1/parent::tei:author) then 'author'
                else 'mention'
            else 'mention' 
          return 
                <relation type="{$relationType}" count="{count($recs)}" ana="{$relationType}" active="{$facet-grp}" passive="{normalize-space(string-join($p1[1]//text(),''))}">
                    <desc>{root($recs[1])//tei:titleStmt/tei:title}</desc>
                </relation>
          }</listRelation>
      </person>)
};

declare function local:make-record($nodes as node()*){
    <TEI xmlns="http://www.tei-c.org/ns/1.0">
        <text>
            <body>{
                if(request:get-parameter('content', '') = 'geojson') then
                       for $n in $nodes/descendant::*:result[*:binding[@name="label"]/child::*[@xml:lang="en"]]
                        return 
                       <listPlace>{local:make-place($n)}</listPlace> 
                    else if(request:get-parameter('content', '') = 'person') then
                        <listPerson>{local:make-person(())}</listPerson>
                    else () 
                }</body>
        </text>
    </TEI>
};

(: 
 Actions needed by script
 1. Create: create new geojson record from TGN SPARQL endpoint
 2. Update: update geojson record as new records are added/edited (use webhooks)
 3. Link: add links to TEI that reference the places
:)
if(request:get-parameter('action', '') = 'create') then
    try {
        if(request:get-parameter('content', '') = 'geojson') then 
            let $f := local:make-record(local:get-all-coords())
            return xmldb:store(concat($config:app-root,'/resources/lodHelpers'), xmldb:encode-uri('placeNames.xml'), $f)
        else if(request:get-parameter('content', '') = 'person') then
            let $f := local:make-record(())
            return xmldb:store(concat($config:app-root,'/resources/lodHelpers'), xmldb:encode-uri('persNames.xml'), $f)
        else ()
    } catch *{
        <response status="fail">
            <message>{concat($err:code, ": ", $err:description)}</message>
        </response>
    } 
    
else if(request:get-parameter('action', '') = 'update') then
    try {
        'what do we do here?'
    } catch *{
        <response status="fail">
            <message>{concat($err:code, ": ", $err:description)}</message>
        </response>
    } 
else <div>In progress</div>

