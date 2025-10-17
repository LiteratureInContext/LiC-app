xquery version "3.0";

module namespace timeline="http://LiC.org/apps/timeline";

(:~
 : Module to build timeline json passed to http://cdn.knightlab.com/libs/timeline/latest/js/storyjs-embed.js widget
 : @author Winona Salesky <wsalesky@gmail.com> 
 : @authored 2014-08-05
:)
import module namespace config="http://LiC.org/apps/config" at "../config.xqm";
import module namespace tei2html="http://syriaca.org/tei2html" at "../content-negotiation/tei2html.xqm";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace json = "http://www.json.org";
declare namespace tei = "http://www.tei-c.org/ns/1.0";

(:
 : Display Timeline. Uses http://timeline.knightlab.com/
:)
declare function timeline:timeline(){ 
    <div class="timeline">
         <!-- 1 -->
        <link title="timeline-styles" rel="stylesheet" 
              href="https://cdn.knightlab.com/libs/timeline3/latest/css/timeline.css"/>

        <!-- 2 -->
        <script src="https://cdn.knightlab.com/libs/timeline3/latest/js/timeline.js"></script>

        <div id='timeline-embed' style="width: 100%; height: 600px"></div>

        <!-- 3 -->
        <script type="text/javascript">
            timeline = new TL.Timeline('timeline-embed',
            '{$config:nav-base}/resources/lodHelpers/timeline.json');
        </script>
       
    <div id="my-timeline"/>
    <p>*Timeline generated with <a href="http://timeline.knightlab.com/">http://timeline.knightlab.com/</a></p>
    </div>     
};

(:
 : Format dates as JSON to be passed to timeline widget.
:)
declare function timeline:get-dates($data as node()*, $title as xs:string*){
let $timeline-title := if($title != '') then $title else 'Timeline'
let $dates := 
    <root>
        <title>
            <text>
                <headline>LiC Works by Publication Date</headline>
            </text>
        </title>
        <events>{(timeline:get-date-published($data))}</events>
    </root>
return
    serialize($dates, 
        <output:serialization-parameters>
            <output:method>json</output:method>
        </output:serialization-parameters>)

};

(: Do all publication dates :)
declare function timeline:get-publication-dates(){
let $imprints := collection($config:data-root)//tei:sourceDesc[descendant::tei:date]
let $dates := 
    <root>
        <title>
            <text>
                <headline>LiC Works by Publication Date</headline>
            </text>
        </title>
        <events>{(timeline:get-date-published($imprints))}</events>
    </root>
return
    serialize($dates, 
        <output:serialization-parameters>
            <output:method>json</output:method>
        </output:serialization-parameters>)

};


declare function timeline:format-dates($start as xs:string*, $end as xs:string*, $headline as xs:string*, $text as xs:string*, $media as element()*, $link as xs:string*){
    if($start != '' or $end != '') then 
        <json:value json:array="true">
            {(
                if($start != '' or $end != '') then 
                    <start_date>
                        <year>
                        {
                            if(empty($start)) then 
                                if(contains($end,'-')) then substring-before($end,'-') else $end[1]
                            else if(contains($start,'-')) then 
                                substring-before($start,'-') 
                            else $start[1]
                        }
                        </year>
                    </start_date>
                 else (),
                 <text>{
                    if($headline != '') then 
                       <headline>{$headline} <![CDATA[ <a href="]]>{$link}<![CDATA["><i class="bi bi-arrow-right-circle"></i></a>]]></headline>
                    else (),
                    if($text != '') then 
                       <text>{$text}<![CDATA[ <a href="]]>{$link}<![CDATA["><i class="bi bi-arrow-right-circle"></i></a>]]></text> 
                   else ()
                   }
                 </text>,
                 if($media[@source != '']) then 
                       <media>
                            <url>{
                            let $src := 
                                         if(starts-with($media/@url,'https://') or starts-with($media/@url,'http://')) then 
                                             string($media/@url) 
                                         else concat($config:image-root,$id,'/',string($media/@url))  
                             return $src
                            }</url>
                            <caption>{string($media/@alt)}</caption>
                            <thumbnail>{string($media/@source)}</thumbnail>
                       </media> 
                else ()
                )}
        </json:value>
    else ()
};

(:~
 : Build datePublished
 : @param $data as node
:)
declare function timeline:get-date-published($data as node()*) as node()*{
    for $imprint in $data
    let $date := ($imprint/descendant::tei:imprint/tei:date[@timeline != ''], $imprint/descendant::tei:imprint/tei:date)[1]
    let $author := tei2html:persName($imprint/descendant::tei:author[1])
    let $titlElement := $imprint/descendant::tei:title[1]
    let $title := if($titlElement/parent::tei:monogr) then concat('&lt;em&gt;',$titlElement/text(),'&lt;/em&gt;')
                  else if($titlElement/parent::tei:analytic and contains($titlElement,'"')) then 
                    $titlElement/text()
                  else concat('"',$titlElement/text(),'"')
    let $media := if($imprint/ancestor::tei:TEI/descendant::tei:graphic[@type='timeline']) then $imprint/ancestor::tei:TEI/descendant::tei:graphic[@type='timeline'] else()   
    let $id := document-uri(root($imprint))
    let $link := concat($config:nav-base,'/work',substring-before(replace($id,$config:data-root,''),'.xml'))
    let $dateText :=    
                if($date[@timeline != '']) then string($date/@timeline)
                else tei2html:tei2html($date)
    let $startString := 
                    if($date[@timeline != '']) then
                        string($date/@timeline)
                     else if($date/@when) then
                        string($date/@when)
                     else if($date/@from) then   
                        string($date/@from)
                     else ()
    let $start := if(matches($startString,'\d{4}')) then $startString else ()
    let $endString := 
                     if($date[@timeline != '']) then
                        string($date/@timeline)
                     else if($date/@when) then
                        string($date/@when)
                     else if($date/@to) then   
                        string($date/@to)
                     else ()
    let $end := if(matches($endString,'\d{4}')) then $endString else ()                     
    let $imprint-text := normalize-space(concat($author,if($author != '') then ', ' else (), $title))
  return timeline:format-dates($start, $end,$imprint-text,(), $media, $link)
        
};