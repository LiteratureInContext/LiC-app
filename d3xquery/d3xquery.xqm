xquery version "3.1";

module namespace d3xquery="http://syriaca.org/d3xquery";
import module namespace config="http://LiC.org/apps/config" at "../modules/config.xqm";
import module namespace functx="http://www.functx.com";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace json="http://www.json.org";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

(: Output based on d3js requirements for producing an HTML table:)
declare function d3xquery:format-table($relationships){        
    <root>{(
        <head>{
            (<vars>type</vars>,
            <vars>activeID</vars>,
            <vars>active</vars>,
            <vars>passiveID</vars>,
            <vars>passive</vars>)
        }</head>,
        <results>{
            for $r in $relationships/descendant::tei:relation 
            return
                <relation>
                    <type>{string($r/@type)}</type>
                    <activeID>{string($r/@active)}</activeID>
                    <active>{normalize-space(string-join($r//text(),' '))}</active>
                    <passiveID>{string($r/@passive)}</passiveID>
                    <passive>{$r/ancestor::tei:place/tei:placeName//text() | $r/ancestor::tei:person/tei:persName[1]//text()}</passive>
                </relation>
        }</results>
    )}</root>
};

(: Output based on d3js requirements for producing a d3js tree format, single nested level, gives collection overview :)
declare function d3xquery:format-tree-types($relationships as item()*, $dataType as xs:string?){
    <root>
        <data>
            <children>
                {
                    if($dataType = 'work') then 
                        (: Get all works, size is based on counts in relations? on click get a force graph of persons/places? :)
                        for $r in $relationships//tei:relation
                        let $title := string-join($r/descendant::tei:title,' ')
                        group by $key := $r/@active
                        where $title != ''
                        return 
                            <json:value>
                                <id>{string($key)}</id>
                                <name>{$title[1]}</name>
                                <desc>{$title[1]} mentioned in {count($r)} relationships.</desc>
                                <size>{count($r)}</size>
                             </json:value>
                    else 
                        for $r in $relationships
                        let $name := if($r/descendant::tei:persName/descendant::tei:name/tei:surname) then 
                                        normalize-space(concat($r/descendant::tei:persName/descendant::tei:name[1]/tei:surname[1],', ', $r/descendant::tei:persName/descendant::tei:name[1]/tei:forename[1]))
                                     else if($r/descendant::tei:persName) then 
                                        normalize-space(string-join($r/descendant::tei:persName//text(),' '))
                                     else if($r/descendant::tei:placeName) then
                                        normalize-space(string-join($r/descendant::tei:placeName//text(),' '))
                                     else normalize-space(string-join($r/descendant::tei:title//text(),' '))
                        let $related := $r//tei:relation
                        order by count($related) descending
                        where $name[. != '']
                        return 
                            <json:value>
                                <id>{$r/tei:idno[1]/text()}</id>
                                <name>{$name}</name>
                                <desc>{$name}: 
                                    {for $rtype in $related
                                     group by $key := $rtype/@ana
                                     return
                                        concat("&#xa;", 
                                            if($key = 'pubPlace') then 'Place of Publication for ' 
                                            else if($key = 'editor') then 'Editor of '
                                            else if($key = 'author') then 'Author of '
                                            else if($key = 'mention') then 'Mentioned in ' 
                                            else $key,
                                            " ", count($rtype), ' works.')
                                    }
                                </desc>
                                <size>{count($related)}</size>
                                <type>{if($r/descendant::tei:persName) then 'person' else if($r/descendant::tei:placeName) then 'place' else 'other'}</type>
                             </json:value>
                 }
            </children>
        </data>
    </root>
};

(: 

 <listRelation>
            <relation type="mention" count="1" ana="mention" active="/db/apps/LiC-data/data/Shelley/shelley-frankenstein-1818.xml" passive="n79004229">
              <desc><title type="main">Frankenstein, or The Modern Prometheus</title></desc>
            </relation>
          </listRelation>
:)
declare function d3xquery:format-relationship-graph($relationships as item()*){
        <root>
            <nodes>{
                (
                for $r in $relationships/descendant-or-self::tei:relation
                group by $group := $r/@active
                return
                    <json:value>
                        <id>{string($group)}</id>
                        <uri>{substring-before(replace($group,$config:data-root,''),'.xml')}</uri>
                        <label>{normalize-space(string-join($r[1]/tei:desc//text(),''))}</label>
                        <size>{count($r)}</size>
                        <type>work</type>
                   </json:value>,
                for $r in $relationships/descendant-or-self::tei:relation
                group by $group := $r/@passive
                return
                    <json:value>
                        <id>{string($group)}</id>
                        <label>{if($r[1]/ancestor::tei:place) then 
                                normalize-space(string-join($r[1]/ancestor::tei:place/tei:placeName//text(),'')) 
                                else normalize-space(string-join($r[1]/ancestor::tei:person/tei:persName[1]//text(),''))}</label>
                        <size>{count($r)}</size>
                        <type>{if($r[1]/ancestor::tei:place) then 'place' else 'person'}</type>
                   </json:value>)     
            }</nodes>
            <links>{
                for $r in $relationships/descendant-or-self::tei:relation
                let $key := $r/@ana
                return 
                    <json:value>
                        {(if(count($relationships/descendant-or-self::tei:relation) = 1) then attribute {xs:QName("json:array")} {'true'} else())}
                        <source>{string($r/@passive)}</source>
                        <target>{string($r/@active)}</target>
                        <relationship>{if($key = 'pubPlace') then 'Place of Publication for ' 
                                            else if($key = 'editor') then 'Editor of '
                                            else if($key = 'author') then 'Author of '
                                            else if($key = 'mention') then 'Mentioned in ' 
                                            else $key
                        (:string($r[1]/@ana):)}</relationship>
                        <value>0</value>
                    </json:value>
            }</links>
        </root>
};

declare function d3xquery:build-graph-type($records as item()*, $id as xs:string?, $relationship as xs:string?, $type as xs:string?, $dataType as xs:string?){
    let $records := 
            if($id != '') then 
                $records[descendant::tei:idno[. = $id]] | $records[descendant::tei:relation[@active[. = $id]]]
            else $records
    let $data := 
        if(lower-case($type) = ('force','sankey')) then 
            d3xquery:format-relationship-graph($records)
        else if(lower-case($type) = ('table','bundle')) then 
            d3xquery:format-table($records)
        else if(lower-case($type) = ('tree','round tree','circle pack','bubble')) then 
            d3xquery:format-tree-types($records, $dataType)
        else if(lower-case($type) = ('bar chart','pie chart')) then
            (:d3xquery:format-tree-types(d3xquery:get-relationship($records)):)''   
        else d3xquery:format-table($records) 
    return $data
      (: if(request:get-parameter('format', '') = ('json','JSON')) then
            (serialize($data, 
                        <output:serialization-parameters>
                            <output:method>json</output:method>
                        </output:serialization-parameters>),
                        response:set-header("Content-Type", "application/json"))        
        else <results class="debug">{$data}</results>
        :)
};        