xquery version "3.0";

module namespace timeline="http://LiC.org/timeline";

(:~
 : Module to build timeline json passed to http://cdn.knightlab.com/libs/timeline/latest/js/storyjs-embed.js widget
 : @author Winona Salesky <wsalesky@gmail.com>
 : @authored 2014-08-05
:)
import module namespace config="http://LiC.org/config" at "config.xqm";
import module namespace tei2html="http://syriaca.org/tei2html" at "../content-negotiation/tei2html.xqm";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace json = "http://www.json.org";
declare namespace tei = "http://www.tei-c.org/ns/1.0";

(:
 : Format dates as JSON to be passed to timeline widget.
:)
declare function timeline:get-dates($data as node()*, $title as xs:string*){
let $timeline-title := if($title != '') then $title else 'Timeline'
let $dates := 
    <root>
        <timeline>
            <headline>{$timeline-title}</headline>
            <type>default</type>
            <asset>
                <media>LiC.org</media>
                <credit>LiC.org</credit>
                <caption>Events for {$timeline-title}</caption>
            </asset>
            <date>
                {(
                    timeline:get-date-published($data)
                    )}</date>
        </timeline>
    </root>
return
    serialize($dates, 
        <output:serialization-parameters>
            <output:method>json</output:method>
        </output:serialization-parameters>)

};

declare function timeline:format-dates($start as xs:string*, $end as xs:string*, $headline as xs:string*, $text as xs:string* ){
    if($start != '' or $end != '') then 
        <json:value json:array="true">
            {(
                if($start != '' or $end != '') then 
                    <startDate>
                        {
                            if(empty($start)) then $end
                            else if(starts-with($start,'-')) then concat('-',tokenize($start,'-')[2])
                            else replace($start,'-',',')
                        }
                    </startDate>
                 else (),
                if($end != '') then 
                    <endDate>
                        {
                            if(starts-with($end,'-')) then concat('-',tokenize($end,'-')[2])
                            else replace($end,'-',',')
                        }
                    </endDate>
                 else (),
                 if($headline != '') then 
                    <headline>{$headline}</headline>
                 else (),
                 if($text != '') then 
                    <text>{$text}</text> 
                else ()                 
                )}
        </json:value>
    else ()
};

(:~
 : Build birth date ranges
 : @param $data as node
:)
declare function timeline:get-date-published($data as node()*) as node()*{
    if($data/descendant-or-self::tei:imprint/tei:date) then
        for $sourceDesc in $data/descendant::tei:sourceDesc
        let $title := $sourceDesc/descendant/tei:title[1]//text()
        for $imprint in $sourceDesc/descendant::tei:imprint
        let $start := if($imprint/tei:date/@when) then
                        string($imprint/tei:date/@when)
                     else if($imprint/tei:date/@from) then   
                        string($imprint/tei:date/@from)
                     else ()
        let $end := if($imprint/tei:date/@when) then
                        string($imprint/tei:date/@when)
                     else if($imprint/tei:date/@to) then   
                        string($imprint/tei:date/@to)
                     else ()   
        let $imprint-text := normalize-space(concat($title,' ',tei2html:tei2html($imprint/tei:date)))
        return timeline:format-dates($start, $end,$imprint-text,'')
    else () 
};